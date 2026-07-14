// Package bootstrap owns the fail-closed production process startup and
// shutdown sequence.
package bootstrap

import (
	"context"
	"io"
	"log/slog"
	"os"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/observability"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/transport"
)

const (
	ExitOK              = 0
	ExitUnavailable     = 69
	ExitSoftware        = 70
	ExitOperatingSystem = 71
)

const ExitConfiguration = 78

// Run executes the complete Step 3 lifecycle. It opens only the local
// administrative listener and the bounded PostgreSQL pool.
func Run(ctx context.Context, output io.Writer, identity database.ServiceIdentity) int {
	logger := observability.NewJSONLogger(output, identity.ProcessName)

	cfg, err := config.Load(identity.ProcessName, os.LookupEnv)
	if err != nil {
		logger.Error("configuration rejected", "diagnostic", observability.SafeError(err))
		return ExitConfiguration
	}

	state := transport.NewState(identity.ProcessName)
	adminServer, err := transport.Listen(cfg.AdminListenAddress, state)
	if err != nil {
		logger.Error("administrative listener failed", "diagnostic", "listener_bind_failed")
		return ExitOperatingSystem
	}

	serveResult := make(chan error, 1)
	go func() {
		serveResult <- adminServer.Serve()
	}()
	logger.Info("administrative listener started", "address", adminServer.Addr())

	startupContext, cancelStartup := context.WithTimeout(ctx, cfg.StartupTimeout)
	pool, compatibility, err := database.Open(startupContext, cfg, identity)
	cancelStartup()
	if err != nil {
		shutdownAdministrativeServer(logger, adminServer, cfg)
		if ctx.Err() != nil {
			logger.Info("shutdown requested during startup")
			return ExitOK
		}
		logger.Error("database startup rejected", "diagnostic", database.Diagnostic(err))
		return ExitUnavailable
	}

	select {
	case serveErr := <-serveResult:
		pool.Close()
		if serveErr != nil {
			logger.Error("administrative listener stopped during startup", "diagnostic", "listener_serve_failed")
		}
		return ExitSoftware
	default:
	}

	state.SetReady(true)
	logger.Info(
		"service ready",
		"database", compatibility.CurrentDatabase,
		"postgresql_role", compatibility.CurrentUser,
		"postgresql_version_num", compatibility.ServerVersionNumber,
	)

	exitCode := ExitOK
	select {
	case <-ctx.Done():
		logger.Info("shutdown requested")
	case serveErr := <-serveResult:
		if serveErr != nil {
			logger.Error("administrative listener stopped unexpectedly", "diagnostic", "listener_serve_failed")
			exitCode = ExitSoftware
		}
	}

	state.SetReady(false)
	shutdownAdministrativeServer(logger, adminServer, cfg)
	pool.Close()
	logger.Info("service stopped", "exit_code", exitCode)
	return exitCode
}

func shutdownAdministrativeServer(logger *slog.Logger, server *transport.Server, cfg config.Config) {
	shutdownContext, cancelShutdown := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancelShutdown()
	if err := server.Shutdown(shutdownContext); err != nil {
		logger.Error("administrative listener shutdown incomplete", "diagnostic", "listener_shutdown_failed")
	}
}
