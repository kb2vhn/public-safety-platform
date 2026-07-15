// Package bootstrap owns the fail-closed production process startup and
// shutdown sequence.
package bootstrap

import (
	"context"
	"io"
	"log/slog"
	"os"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/authentication"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/foundation"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/observability"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/processhost"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/transport"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/workers"
)

const (
	ExitOK              = 0
	ExitUnavailable     = 69
	ExitSoftware        = 70
	ExitOperatingSystem = 71
)

const ExitConfiguration = 78

// Run executes the complete Step 7 lifecycle. The Foundation API preserves the
// Step 6 authenticated listener, while the two delivery identities receive only
// their exact bounded worker loop and deployment-owned outbound relay.
func Run(ctx context.Context, output io.Writer, identity database.ServiceIdentity) int {
	logger := observability.NewJSONLogger(output, identity.ProcessName)

	cfg, err := config.Load(identity.ProcessName, os.LookupEnv)
	if err != nil {
		logger.Error("configuration rejected", "diagnostic", observability.SafeError(err))
		return ExitConfiguration
	}

	var verifier *authentication.Verifier
	if cfg.Business.Enabled {
		key, keyErr := config.ReadTransportHMACKey(cfg.Business.HMACKeyFile)
		if keyErr != nil {
			logger.Error("transport credential rejected", "diagnostic", observability.SafeError(keyErr))
			return ExitConfiguration
		}
		verifier, err = authentication.NewVerifier(key, nil)
		zeroBytes(key)
		if err != nil {
			logger.Error("transport credential rejected", "diagnostic", authentication.Diagnostic(err))
			return ExitConfiguration
		}
	}

	var deliveryToken []byte
	if cfg.Delivery.Enabled {
		deliveryToken, err = config.ReadDeliveryToken(cfg.Delivery.TokenFile)
		if err != nil {
			logger.Error("delivery credential rejected", "diagnostic", observability.SafeError(err))
			return ExitConfiguration
		}
		defer zeroBytes(deliveryToken)
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

	adminServeResult := make(chan error, 1)
	go func() {
		adminServeResult <- adminServer.Serve()
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
	case serveErr := <-adminServeResult:
		notifyStopping(logger, host)
		pool.Close()
		if serveErr != nil {
			logger.Error("administrative listener stopped during startup", "diagnostic", "listener_serve_failed")
		}
		return ExitSoftware
	default:
	}

	var businessServer *transport.BusinessServer
	var businessServeResult chan error
	if cfg.Business.Enabled {
		adapter, adapterErr := foundation.NewAuthorizationPolicyAdapter(pool)
		if adapterErr != nil {
			notifyStopping(logger, host)
			shutdownAdministrativeServer(logger, adminServer, cfg)
			pool.Close()
			logger.Error("Foundation adapter construction failed", "diagnostic", foundation.Diagnostic(adapterErr))
			return ExitSoftware
		}
		handler, handlerErr := transport.NewBusinessHandler(
			verifier,
			adapter,
			cfg.Business.MaxConcurrentRequests,
		)
		if handlerErr != nil {
			notifyStopping(logger, host)
			shutdownAdministrativeServer(logger, adminServer, cfg)
			pool.Close()
			logger.Error("business transport construction failed", "diagnostic", "business_transport_configuration_failed")
			return ExitConfiguration
		}
		businessServer, err = transport.ListenBusiness(cfg.Business.ListenAddress, handler)
		if err != nil {
			notifyStopping(logger, host)
			shutdownAdministrativeServer(logger, adminServer, cfg)
			pool.Close()
			logger.Error("business listener failed", "diagnostic", "business_listener_bind_failed")
			return ExitOperatingSystem
		}
		businessServeResult = make(chan error, 1)
		go func() {
			businessServeResult <- businessServer.Serve()
		}()
		logger.Info("business listener started", "address", businessServer.Addr())

		select {
		case serveErr := <-businessServeResult:
			notifyStopping(logger, host)
			shutdownAdministrativeServer(logger, adminServer, cfg)
			pool.Close()
			if serveErr != nil {
				logger.Error("business listener stopped during startup", "diagnostic", "business_listener_serve_failed")
			}
			return ExitSoftware
		default:
		}
	}

	var deliveryRunner workers.Runner
	if cfg.Delivery.Enabled {
		deliveryRunner, err = workers.New(pool, cfg.Delivery, deliveryToken, logger)
		zeroBytes(deliveryToken)
		deliveryToken = nil
		if err != nil {
			notifyStopping(logger, host)
			shutdownBusinessServer(logger, businessServer, cfg)
			shutdownAdministrativeServer(logger, adminServer, cfg)
			pool.Close()
			logger.Error("delivery worker construction failed", "diagnostic", workers.Diagnostic(err))
			return ExitConfiguration
		}
	}

	state.SetReady(true)
	if err := host.Ready(); err != nil {
		state.SetReady(false)
		logger.Error("process-host readiness notification failed", "diagnostic", processhost.Diagnostic(err))
		notifyStopping(logger, host)
		if deliveryRunner != nil {
			deliveryRunner.Close()
		}
		shutdownBusinessServer(logger, businessServer, cfg)
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
		"business_transport_enabled", cfg.Business.Enabled,
		"delivery_worker_enabled", cfg.Delivery.Enabled,
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

	var cancelDelivery context.CancelFunc
	var deliveryResult chan error
	if deliveryRunner != nil {
		deliveryContext, cancel := context.WithCancel(context.Background())
		cancelDelivery = cancel
		deliveryResult = make(chan error, 1)
		go func() {
			deliveryResult <- deliveryRunner.Run(deliveryContext)
		}()
	}

	exitCode := ExitOK
	select {
	case <-ctx.Done():
		logger.Info("shutdown requested")
	case serveErr := <-adminServeResult:
		if serveErr != nil {
			logger.Error("administrative listener stopped unexpectedly", "diagnostic", "listener_serve_failed")
			exitCode = ExitSoftware
		}
	case serveErr := <-businessServeResult:
		businessServeResult = nil
		if serveErr != nil {
			logger.Error("business listener stopped unexpectedly", "diagnostic", "business_listener_serve_failed")
			exitCode = ExitSoftware
		}
	case deliveryErr := <-deliveryResult:
		deliveryResult = nil
		if deliveryErr != nil {
			logger.Error("delivery worker stopped unexpectedly", "diagnostic", workers.Diagnostic(deliveryErr))
		} else {
			logger.Error("delivery worker stopped unexpectedly", "diagnostic", "delivery_worker_stopped")
		}
		exitCode = ExitSoftware
	case watchdogErr := <-watchdogResult:
		watchdogResult = nil
		if watchdogErr != nil {
			logger.Error("process-host watchdog notification failed", "diagnostic", processhost.Diagnostic(watchdogErr))
			exitCode = ExitSoftware
		}
	}

	state.SetReady(false)
	stopWatchdog(cancelWatchdog, watchdogResult)
	notifyStopping(logger, host)
	deliveryDrained := stopDeliveryWorker(logger, cancelDelivery, deliveryResult, cfg.ShutdownTimeout)
	if !deliveryDrained {
		exitCode = ExitSoftware
	} else if deliveryRunner != nil {
		deliveryRunner.Close()
	}
	shutdownBusinessServer(logger, businessServer, cfg)
	shutdownAdministrativeServer(logger, adminServer, cfg)
	pool.Close()
	logger.Info("service stopped", "exit_code", exitCode)
	return exitCode
}

func zeroBytes(value []byte) {
	for index := range value {
		value[index] = 0
	}
}

func stopDeliveryWorker(logger *slog.Logger, cancel context.CancelFunc, result <-chan error, timeout time.Duration) bool {
	if cancel == nil {
		return true
	}
	cancel()
	if result == nil {
		return true
	}
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	select {
	case err := <-result:
		if err != nil {
			logger.Error("delivery worker drain failed", "diagnostic", workers.Diagnostic(err))
			return false
		}
		return true
	case <-timer.C:
		logger.Error("delivery worker drain timed out", "diagnostic", "delivery_worker_drain_timeout")
		return false
	}
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
		logger.Error("process-host stopping notification failed", "diagnostic", processhost.Diagnostic(err))
	}
}

func shutdownBusinessServer(logger *slog.Logger, server *transport.BusinessServer, cfg config.Config) {
	if server == nil {
		return
	}
	shutdownContext, cancelShutdown := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancelShutdown()
	if err := server.Shutdown(shutdownContext); err != nil {
		logger.Error("business listener shutdown incomplete", "diagnostic", "business_listener_shutdown_failed")
	}
}

func shutdownAdministrativeServer(logger *slog.Logger, server *transport.Server, cfg config.Config) {
	shutdownContext, cancelShutdown := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancelShutdown()
	if err := server.Shutdown(shutdownContext); err != nil {
		logger.Error("administrative listener shutdown incomplete", "diagnostic", "listener_shutdown_failed")
	}
}
