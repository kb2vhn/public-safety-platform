//go:build integration

package foundation

import (
	"context"
	"os"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestIntegrationAuthorizationPolicyBinding(t *testing.T) {
	dsnFile := os.Getenv("ISSP_TEST_DATABASE_DSN_FILE")
	if dsnFile == "" {
		t.Skip("integration database environment is not configured")
	}

	cfg := config.Config{
		ProcessName:     database.FoundationAPI.ProcessName,
		StartupTimeout:  10 * time.Second,
		ShutdownTimeout: 5 * time.Second,
		Database: config.Database{
			DSNFile:               dsnFile,
			AllowInsecureLocal:    true,
			ConnectTimeout:        5 * time.Second,
			MaxConnections:        4,
			MinConnections:        0,
			MaxConnectionLifetime: 5 * time.Minute,
			MaxConnectionIdleTime: time.Minute,
			HealthCheckPeriod:     10 * time.Second,
		},
	}

	startupContext, cancelStartup := context.WithTimeout(
		context.Background(),
		cfg.StartupTimeout,
	)
	defer cancelStartup()

	pool, report, err := database.Open(
		startupContext,
		cfg,
		database.FoundationAPI,
	)
	if err != nil {
		t.Fatalf(
			"database.Open() error = %v diagnostic=%s",
			err,
			database.Diagnostic(err),
		)
	}
	defer pool.Close()

	if report.CurrentUser != database.FoundationAPI.PostgreSQLRole {
		t.Fatalf(
			"CurrentUser = %q, want %q",
			report.CurrentUser,
			database.FoundationAPI.PostgreSQLRole,
		)
	}

	adapter, err := NewAuthorizationPolicyAdapter(pool)
	if err != nil {
		t.Fatalf("NewAuthorizationPolicyAdapter() error = %v", err)
	}

	cases := []struct {
		name        string
		environment string
		want        PolicyBindingReasonCode
	}{
		{
			name:        "unique policy selected",
			environment: "ISSP_TEST_SELECTED_DECISION_ID",
			want:        AuthorizationPolicySelected,
		},
		{
			name:        "missing policy terminal deny",
			environment: "ISSP_TEST_MISSING_POLICY_DECISION_ID",
			want:        AuthorizationPolicyNotFound,
		},
		{
			name:        "ambiguous policy terminal deny",
			environment: "ISSP_TEST_AMBIGUOUS_POLICY_DECISION_ID",
			want:        AuthorizationPolicyAmbiguous,
		},
		{
			name:        "expected policy mismatch terminal deny",
			environment: "ISSP_TEST_MISMATCH_DECISION_ID",
			want:        AuthorizationPolicyContextMismatch,
		},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			id := requiredIntegrationDecisionID(t, testCase.environment)
			result, bindErr := adapter.BindAuthorizationPolicy(
				context.Background(),
				id,
			)
			if bindErr != nil {
				t.Fatalf(
					"BindAuthorizationPolicy() error = %v diagnostic=%s",
					bindErr,
					Diagnostic(bindErr),
				)
			}
			if result.DecisionID != id {
				t.Fatalf("DecisionID = %q, want %q", result.DecisionID, id)
			}
			if result.ReasonCode != testCase.want {
				t.Fatalf(
					"ReasonCode = %q, want %q",
					result.ReasonCode,
					testCase.want,
				)
			}
		})
	}

	t.Run("nonexistent decision is redacted", func(t *testing.T) {
		id := requiredIntegrationDecisionID(
			t,
			"ISSP_TEST_NONEXISTENT_DECISION_ID",
		)
		result, bindErr := adapter.BindAuthorizationPolicy(
			context.Background(),
			id,
		)
		if bindErr == nil {
			t.Fatal("BindAuthorizationPolicy() accepted nonexistent decision")
		}
		if result.DecisionID != id || result.ReasonCode != "" {
			t.Fatalf("result = %#v", result)
		}
		if got := Diagnostic(bindErr); got != "postgres_sqlstate_P0002" {
			t.Fatalf("Diagnostic() = %q, want postgres_sqlstate_P0002", got)
		}
		if containsAny(
			bindErr.Error(),
			id.String(),
			"Authorization Decision Record does not exist",
		) {
			t.Fatalf("error disclosed protected details: %q", bindErr)
		}
	})

	t.Run("concurrent binding is serialized", func(t *testing.T) {
		id := requiredIntegrationDecisionID(
			t,
			"ISSP_TEST_CONCURRENT_DECISION_ID",
		)

		start := make(chan struct{})
		results := make(chan PolicyBindingResult, 2)
		errors := make(chan error, 2)
		var waitGroup sync.WaitGroup

		for range 2 {
			waitGroup.Add(1)
			go func() {
				defer waitGroup.Done()
				<-start
				result, bindErr := adapter.BindAuthorizationPolicy(
					context.Background(),
					id,
				)
				if bindErr != nil {
					errors <- bindErr
					return
				}
				results <- result
			}()
		}

		close(start)
		waitGroup.Wait()
		close(results)
		close(errors)

		for bindErr := range errors {
			t.Fatalf(
				"concurrent BindAuthorizationPolicy() error = %v diagnostic=%s",
				bindErr,
				Diagnostic(bindErr),
			)
		}

		var reasonCodes []string
		for result := range results {
			if result.DecisionID != id {
				t.Fatalf("DecisionID = %q, want %q", result.DecisionID, id)
			}
			reasonCodes = append(reasonCodes, string(result.ReasonCode))
		}
		sort.Strings(reasonCodes)

		want := []string{
			string(AuthorizationPolicyAlreadyBound),
			string(AuthorizationPolicySelected),
		}
		if len(reasonCodes) != len(want) ||
			reasonCodes[0] != want[0] ||
			reasonCodes[1] != want[1] {
			t.Fatalf("reason codes = %#v, want %#v", reasonCodes, want)
		}
	})
}

func requiredIntegrationDecisionID(t *testing.T, environment string) DecisionID {
	t.Helper()
	value := os.Getenv(environment)
	if value == "" {
		t.Fatalf("required integration environment is missing: %s", environment)
	}
	id, err := ParseDecisionID(value)
	if err != nil {
		t.Fatalf("ParseDecisionID(%s) error = %v", environment, err)
	}
	return id
}

func containsAny(value string, candidates ...string) bool {
	for _, candidate := range candidates {
		if candidate != "" && len(value) >= len(candidate) {
			for offset := 0; offset+len(candidate) <= len(value); offset++ {
				if value[offset:offset+len(candidate)] == candidate {
					return true
				}
			}
		}
	}
	return false
}
