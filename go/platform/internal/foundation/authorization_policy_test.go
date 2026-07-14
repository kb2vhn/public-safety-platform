package foundation

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

const testDecisionID = "123e4567-e89b-12d3-a456-426614174000"

type fakeAuthorizationPolicyBinder struct {
	mu         sync.Mutex
	decisionID string
	result     string
	err        error
	block      bool
}

func (fake *fakeAuthorizationPolicyBinder) BindAuthorizationPolicy(
	ctx context.Context,
	decisionID string,
) (string, error) {
	fake.mu.Lock()
	fake.decisionID = decisionID
	block := fake.block
	result := fake.result
	err := fake.err
	fake.mu.Unlock()

	if block {
		<-ctx.Done()
		return "", ctx.Err()
	}
	return result, err
}

func TestParseDecisionIDNormalizesCanonicalUUID(t *testing.T) {
	id, err := ParseDecisionID("  123E4567-E89B-12D3-A456-426614174000  ")
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}
	if got := id.String(); got != testDecisionID {
		t.Fatalf("DecisionID.String() = %q, want %q", got, testDecisionID)
	}
}

func TestParseDecisionIDRejectsInvalidValues(t *testing.T) {
	for _, value := range []string{
		"",
		"not-a-uuid",
		"123e4567e89b12d3a456426614174000",
		"00000000-0000-0000-0000-000000000000",
		"123e4567-e89b-12d3-a456-42661417400z",
	} {
		t.Run(value, func(t *testing.T) {
			_, err := ParseDecisionID(value)
			if err == nil {
				t.Fatal("ParseDecisionID() accepted invalid value")
			}
			if Diagnostic(err) != "foundation_validation" {
				t.Fatalf("Diagnostic() = %q", Diagnostic(err))
			}
			if strings.Contains(err.Error(), value) && value != "" {
				t.Fatalf("error disclosed supplied value: %q", err)
			}
		})
	}
}

func TestAuthorizationPolicyAdapterUsesNarrowBoundaryAndPreservesReference(t *testing.T) {
	id, err := ParseDecisionID(testDecisionID)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}

	fake := &fakeAuthorizationPolicyBinder{result: string(AuthorizationPolicySelected)}
	adapter, err := newAuthorizationPolicyAdapter(
		fake,
		database.FoundationAPI,
		time.Second,
	)
	if err != nil {
		t.Fatalf("newAuthorizationPolicyAdapter() error = %v", err)
	}

	result, err := adapter.BindAuthorizationPolicy(context.Background(), id)
	if err != nil {
		t.Fatalf("BindAuthorizationPolicy() error = %v", err)
	}
	if result.DecisionID != id {
		t.Fatalf("result DecisionID = %q, want %q", result.DecisionID, id)
	}
	if result.ReasonCode != AuthorizationPolicySelected {
		t.Fatalf("result ReasonCode = %q", result.ReasonCode)
	}

	fake.mu.Lock()
	defer fake.mu.Unlock()
	if fake.decisionID != testDecisionID {
		t.Fatalf("decisionID = %q, want %q", fake.decisionID, testDecisionID)
	}
}

func TestAuthorizationPolicyAdapterAcceptsExactReasonCodeInventory(t *testing.T) {
	id, err := ParseDecisionID(testDecisionID)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}

	reasonCodes := []PolicyBindingReasonCode{
		AuthorizationPolicySelected,
		AuthorizationPolicyNotFound,
		AuthorizationPolicyAmbiguous,
		AuthorizationPolicyContextMismatch,
		AuthorizationDecisionFinalized,
		AuthorizationPolicyAlreadyBound,
	}

	for _, reasonCode := range reasonCodes {
		t.Run(string(reasonCode), func(t *testing.T) {
			fake := &fakeAuthorizationPolicyBinder{result: string(reasonCode)}
			adapter, adapterErr := newAuthorizationPolicyAdapter(
				fake,
				database.FoundationAPI,
				time.Second,
			)
			if adapterErr != nil {
				t.Fatalf("newAuthorizationPolicyAdapter() error = %v", adapterErr)
			}

			result, bindErr := adapter.BindAuthorizationPolicy(
				context.Background(),
				id,
			)
			if bindErr != nil {
				t.Fatalf("BindAuthorizationPolicy() error = %v", bindErr)
			}
			if result.ReasonCode != reasonCode {
				t.Fatalf("ReasonCode = %q, want %q", result.ReasonCode, reasonCode)
			}
		})
	}
}

func TestAuthorizationPolicyAdapterRejectsUnexpectedReasonCode(t *testing.T) {
	id, err := ParseDecisionID(testDecisionID)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}
	fake := &fakeAuthorizationPolicyBinder{result: "CALLER_SUPPLIED_ALLOW"}
	adapter, err := newAuthorizationPolicyAdapter(
		fake,
		database.FoundationAPI,
		time.Second,
	)
	if err != nil {
		t.Fatalf("newAuthorizationPolicyAdapter() error = %v", err)
	}

	result, err := adapter.BindAuthorizationPolicy(context.Background(), id)
	if err == nil {
		t.Fatal("BindAuthorizationPolicy() accepted unexpected reason code")
	}
	if result.DecisionID != id || result.ReasonCode != "" {
		t.Fatalf("result = %#v", result)
	}
	if Diagnostic(err) != "foundation_database_contract" {
		t.Fatalf("Diagnostic() = %q", Diagnostic(err))
	}
	if strings.Contains(err.Error(), "CALLER_SUPPLIED_ALLOW") {
		t.Fatalf("error disclosed database value: %q", err)
	}
}

func TestAuthorizationPolicyAdapterRejectsWrongIdentity(t *testing.T) {
	_, err := newAuthorizationPolicyAdapter(
		&fakeAuthorizationPolicyBinder{},
		database.IntegrationDeliveryWorker,
		time.Second,
	)
	if err == nil {
		t.Fatal("newAuthorizationPolicyAdapter() accepted wrong identity")
	}
	if Diagnostic(err) != "foundation_identity" {
		t.Fatalf("Diagnostic() = %q", Diagnostic(err))
	}
}

func TestAuthorizationPolicyAdapterHonorsCancellationAndTimeout(t *testing.T) {
	id, err := ParseDecisionID(testDecisionID)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}

	t.Run("parent cancellation", func(t *testing.T) {
		fake := &fakeAuthorizationPolicyBinder{block: true}
		adapter, adapterErr := newAuthorizationPolicyAdapter(
			fake,
			database.FoundationAPI,
			time.Second,
		)
		if adapterErr != nil {
			t.Fatalf("newAuthorizationPolicyAdapter() error = %v", adapterErr)
		}

		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		_, bindErr := adapter.BindAuthorizationPolicy(ctx, id)
		if !errors.Is(bindErr, context.Canceled) {
			t.Fatalf("error = %v, want context canceled", bindErr)
		}
		if Diagnostic(bindErr) != "foundation_context_canceled" {
			t.Fatalf("Diagnostic() = %q", Diagnostic(bindErr))
		}
	})

	t.Run("bounded timeout", func(t *testing.T) {
		fake := &fakeAuthorizationPolicyBinder{block: true}
		adapter, adapterErr := newAuthorizationPolicyAdapter(
			fake,
			database.FoundationAPI,
			20*time.Millisecond,
		)
		if adapterErr != nil {
			t.Fatalf("newAuthorizationPolicyAdapter() error = %v", adapterErr)
		}

		started := time.Now()
		_, bindErr := adapter.BindAuthorizationPolicy(context.Background(), id)
		if !errors.Is(bindErr, context.DeadlineExceeded) {
			t.Fatalf("error = %v, want deadline exceeded", bindErr)
		}
		if elapsed := time.Since(started); elapsed > time.Second {
			t.Fatalf("operation was not bounded: %s", elapsed)
		}
		if Diagnostic(bindErr) != "foundation_deadline_exceeded" {
			t.Fatalf("Diagnostic() = %q", Diagnostic(bindErr))
		}
	})
}

func TestAuthorizationPolicyAdapterRejectsInvalidConstruction(t *testing.T) {
	for _, testCase := range []struct {
		name    string
		binder  authorizationPolicyBinder
		timeout time.Duration
	}{
		{name: "nil binder", binder: nil, timeout: time.Second},
		{name: "zero timeout", binder: &fakeAuthorizationPolicyBinder{}, timeout: 0},
		{name: "excessive timeout", binder: &fakeAuthorizationPolicyBinder{}, timeout: 6 * time.Second},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			_, err := newAuthorizationPolicyAdapter(
				testCase.binder,
				database.FoundationAPI,
				testCase.timeout,
			)
			if err == nil {
				t.Fatal("newAuthorizationPolicyAdapter() accepted invalid construction")
			}
		})
	}
}
