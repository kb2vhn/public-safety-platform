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
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/processhost"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/transport"
)

const (
	ExitOK              = 0
	ExitUnavailable     = 69
	ExitSoftware        = 70
	ExitOperatingSystem = 71
)

const ExitConfiguration = 78

// Run executes the complete Step 4 lifecycle. It preserves the Step 3 database
// and administrative boundaries while adding optional systemd-compatible
// readiness, stopping, and watchdog notification.
func Run(ctx context.Context, output io.Writer, identity database.ServiceIdentity) int {
	logger := observability.NewJSONLogger(output, identity.ProcessName)

	cfg, err := config.Load(identity.ProcessName, os.LookupEnv)
	if err != nil {
		logger.Error("configuration rejected", "diagnostic", observability.SafeError(err))
		return ExitConfiguration
	}

	host, err := processhost.Load(os.LookupEnv, os.Getpid())
	if err != nil {
		logger.Error(
			"process-host environment rejected",
			"diagnostic",
			processhost.Diagnostic(err),
		)
		if processhost.IsConfiguration(err) {
			return ExitConfiguration
		}
		return ExitOperatingSystem
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
		notifyStopping(logger, host)
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
		notifyStopping(logger, host)
		pool.Close()
		if serveErr != nil {
			logger.Error(
				"administrative listener stopped during startup",
				"diagnostic",
				"listener_serve_failed",
			)
		}
		return ExitSoftware
	default:
	}

	state.SetReady(true)
	if err := host.Ready(); err != nil {
		state.SetReady(false)
		logger.Error(
			"process-host readiness notification failed",
			"diagnostic",
			processhost.Diagnostic(err),
		)
		notifyStopping(logger, host)
		shutdownAdministrativeServer(logger, adminServer, cfg)
		pool.Close()
		return ExitOperatingSystem
	}

	logger.Info(
		"service ready",
		"database", compatibility.CurrentDatabase,
		"postgresql_role", compatibility.CurrentUser,
		"postgresql_version_num", compatibility.ServerVersionNumber,
		"process_host_notification", host.Enabled(),
		"watchdog_enabled", host.WatchdogEnabled(),
	)

	var cancelWatchdog context.CancelFunc
	var watchdogResult chan error
	if host.WatchdogEnabled() {
		watchdogContext, cancel := context.WithCancel(context.Background())
		cancelWatchdog = cancel
		watchdogResult = make(chan error, 1)
		go func() {
			watchdogResult <- host.RunWatchdog(watchdogContext)
		}()
	}

	exitCode := ExitOK
	select {
	case <-ctx.Done():
		logger.Info("shutdown requested")
	case serveErr := <-serveResult:
		if serveErr != nil {
			logger.Error(
				"administrative listener stopped unexpectedly",
				"diagnostic",
				"listener_serve_failed",
			)
			exitCode = ExitSoftware
		}
	case watchdogErr := <-watchdogResult:
		watchdogResult = nil
		if watchdogErr != nil {
			logger.Error(
				"process-host watchdog notification failed",
				"diagnostic",
				processhost.Diagnostic(watchdogErr),
			)
			exitCode = ExitSoftware
		}
	}

	state.SetReady(false)
	stopWatchdog(cancelWatchdog, watchdogResult)
	notifyStopping(logger, host)
	shutdownAdministrativeServer(logger, adminServer, cfg)
	pool.Close()
	logger.Info("service stopped", "exit_code", exitCode)
	return exitCode
}

func stopWatchdog(cancel context.CancelFunc, result <-chan error) {
	if cancel == nil {
		return
	}
	cancel()
	if result != nil {
		<-result
	}
}

func notifyStopping(logger *slog.Logger, host *processhost.Notifier) {
	if err := host.Stopping(); err != nil {
		logger.Error(
			"process-host stopping notification failed",
			"diagnostic",
			processhost.Diagnostic(err),
		)
	}
}

func shutdownAdministrativeServer(
	logger *slog.Logger,
	server *transport.Server,
	cfg config.Config,
) {
	shutdownContext, cancelShutdown := context.WithTimeout(
		context.Background(),
		cfg.ShutdownTimeout,
	)
	defer cancelShutdown()
	if err := server.Shutdown(shutdownContext); err != nil {
		logger.Error(
			"administrative listener shutdown incomplete",
			"diagnostic",
			"listener_shutdown_failed",
		)
	}
}
