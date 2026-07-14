//go:build integration

package database

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
)

func TestIntegrationOpenCompatibilityAndCancellation(t *testing.T) {
	dsnFile := os.Getenv("ISSP_TEST_DATABASE_DSN_FILE")
	role := os.Getenv("ISSP_TEST_DATABASE_ROLE")
	if dsnFile == "" || role == "" {
		t.Skip("integration database environment is not configured")
	}

	identity, ok := ByPostgreSQLRole(role)
	if !ok {
		t.Fatalf("unknown test role %q", role)
	}

	cfg := config.Config{
		ProcessName:     identity.ProcessName,
		StartupTimeout:  10 * time.Second,
		ShutdownTimeout: 5 * time.Second,
		Database: config.Database{
			DSNFile:               dsnFile,
			AllowInsecureLocal:    true,
			ConnectTimeout:        5 * time.Second,
			MaxConnections:        2,
			MinConnections:        0,
			MaxConnectionLifetime: 5 * time.Minute,
			MaxConnectionIdleTime: time.Minute,
			HealthCheckPeriod:     10 * time.Second,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), cfg.StartupTimeout)
	defer cancel()
	pool, report, err := Open(ctx, cfg, identity)
	if err != nil {
		t.Fatalf("Open() error = %v diagnostic=%s", err, Diagnostic(err))
	}
	defer pool.Close()

	if report.CurrentUser != role {
		t.Fatalf("CurrentUser = %q, want %q", report.CurrentUser, role)
	}
	if pool.Stat().MaxConns() != cfg.Database.MaxConnections {
		t.Fatalf("MaxConns = %d, want %d", pool.Stat().MaxConns(), cfg.Database.MaxConnections)
	}

	queryContext, queryCancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer queryCancel()
	_, queryErr := pool.Exec(queryContext, "SELECT pg_sleep(5)")
	if queryErr == nil || !errors.Is(queryContext.Err(), context.DeadlineExceeded) {
		t.Fatalf("canceled query error = %v context error = %v", queryErr, queryContext.Err())
	}
}

func TestIntegrationWrongIdentityFailsClosed(t *testing.T) {
	dsnFile := os.Getenv("ISSP_TEST_DATABASE_DSN_FILE")
	role := os.Getenv("ISSP_TEST_DATABASE_ROLE")
	if dsnFile == "" || role == "" {
		t.Skip("integration database environment is not configured")
	}

	actual, ok := ByPostgreSQLRole(role)
	if !ok {
		t.Fatalf("unknown test role %q", role)
	}
	wrong := FoundationAPI
	if wrong == actual {
		wrong = IntegrationDeliveryWorker
	}

	cfg := config.Config{
		ProcessName: wrong.ProcessName,
		Database: config.Database{
			DSNFile:               dsnFile,
			AllowInsecureLocal:    true,
			ConnectTimeout:        time.Second,
			MaxConnections:        1,
			MinConnections:        0,
			MaxConnectionLifetime: time.Minute,
			MaxConnectionIdleTime: time.Minute,
			HealthCheckPeriod:     10 * time.Second,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	pool, _, err := Open(ctx, cfg, wrong)
	if pool != nil {
		pool.Close()
	}
	if err == nil {
		t.Fatal("Open() accepted a URL bound to another service role")
	}
}
