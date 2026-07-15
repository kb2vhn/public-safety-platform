//go:build integration

package foundation

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestPhase6Step8AuthorizationPolicyLockWaitHonorsCallerDeadline(t *testing.T) {
	dsnFile := os.Getenv("ISSP_TEST_DATABASE_DSN_FILE")
	decisionText := os.Getenv("ISSP_TEST_LOCKED_DECISION_ID")
	if dsnFile == "" || decisionText == "" {
		t.Skip("Step 8 locked-decision integration environment is not configured")
	}
	decisionID, err := ParseDecisionID(decisionText)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}

	cfg := config.Config{
		ProcessName:     database.FoundationAPI.ProcessName,
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
	startupContext, cancelStartup := context.WithTimeout(context.Background(), cfg.StartupTimeout)
	defer cancelStartup()
	pool, _, err := database.Open(startupContext, cfg, database.FoundationAPI)
	if err != nil {
		t.Fatalf("database.Open() error = %v diagnostic=%s", err, database.Diagnostic(err))
	}
	defer pool.Close()
	adapter, err := NewAuthorizationPolicyAdapter(pool)
	if err != nil {
		t.Fatalf("NewAuthorizationPolicyAdapter() error = %v", err)
	}

	operationContext, cancelOperation := context.WithTimeout(context.Background(), 250*time.Millisecond)
	defer cancelOperation()
	started := time.Now()
	result, err := adapter.BindAuthorizationPolicy(operationContext, decisionID)
	elapsed := time.Since(started)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("error = %v diagnostic=%s, want deadline exceeded", err, Diagnostic(err))
	}
	if elapsed > 2*time.Second {
		t.Fatalf("locked operation exceeded caller deadline: %s", elapsed)
	}
	if result.DecisionID != decisionID || result.ReasonCode != "" {
		t.Fatalf("result = %#v", result)
	}
	if strings.Contains(err.Error(), decisionText) || strings.Contains(strings.ToLower(err.Error()), "lock") {
		t.Fatalf("error disclosed locked record details: %q", err)
	}
	if Diagnostic(err) != "foundation_deadline_exceeded" {
		t.Fatalf("Diagnostic() = %q", Diagnostic(err))
	}
}
