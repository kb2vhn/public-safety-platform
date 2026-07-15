package authentication

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"sync"
	"testing"
	"time"
)

var testKey = []byte("0123456789abcdef0123456789abcdef")

func TestVerifierAcceptsValidHandoffAndRejectsReplay(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	verifier, err := NewVerifier(testKey, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewVerifier() error = %v", err)
	}
	input := signedInput(now, []byte(`{"decision_id":"11111111-1111-1111-1111-111111111111"}`))
	contextValue, err := verifier.Verify(input)
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if contextValue.RequestID.String() != input.RequestID || contextValue.Subject != input.Subject {
		t.Fatalf("context = %#v", contextValue)
	}
	_, err = verifier.Verify(input)
	var handoffError *Error
	if !errors.As(err, &handoffError) || handoffError.Kind != ErrorReplay {
		t.Fatalf("replay error = %v", err)
	}
}

func TestVerifierRejectsInvalidStaleAndMalformedHandoffs(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	tests := []struct {
		name   string
		mutate func(*Input)
		kind   ErrorKind
	}{
		{name: "signature", mutate: func(input *Input) { input.Signature = "v1=" + string(make([]byte, 64)) }, kind: ErrorMalformed},
		{name: "stale", mutate: func(input *Input) {
			input.AuthenticatedAt = now.Add(-time.Minute).Format(time.RFC3339Nano)
			sign(input)
		}, kind: ErrorStale},
		{name: "future", mutate: func(input *Input) {
			input.AuthenticatedAt = now.Add(10 * time.Second).Format(time.RFC3339Nano)
			sign(input)
		}, kind: ErrorStale},
		{name: "subject", mutate: func(input *Input) { input.Subject = "bad subject"; sign(input) }, kind: ErrorMalformed},
		{name: "nonce", mutate: func(input *Input) { input.Nonce = "bad"; sign(input) }, kind: ErrorMalformed},
		{name: "path", mutate: func(input *Input) { input.Path = "/wrong"; sign(input) }, kind: ErrorMalformed},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			verifier, err := NewVerifier(testKey, func() time.Time { return now })
			if err != nil {
				t.Fatalf("NewVerifier() error = %v", err)
			}
			input := signedInput(now, []byte(`{}`))
			test.mutate(&input)
			_, err = verifier.Verify(input)
			var handoffError *Error
			if !errors.As(err, &handoffError) || handoffError.Kind != test.kind {
				t.Fatalf("error = %v, want kind %s", err, test.kind)
			}
		})
	}
}

func TestVerifierAllowsExactlyOneConcurrentReplayWinner(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	verifier, err := NewVerifier(testKey, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewVerifier() error = %v", err)
	}
	input := signedInput(now, []byte(`{}`))

	const callers = 16
	var wait sync.WaitGroup
	results := make(chan error, callers)
	for index := 0; index < callers; index++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			_, verifyErr := verifier.Verify(input)
			results <- verifyErr
		}()
	}
	wait.Wait()
	close(results)

	successes := 0
	replays := 0
	for result := range results {
		if result == nil {
			successes++
			continue
		}
		var handoffError *Error
		if errors.As(result, &handoffError) && handoffError.Kind == ErrorReplay {
			replays++
			continue
		}
		t.Fatalf("unexpected error = %v", result)
	}
	if successes != 1 || replays != callers-1 {
		t.Fatalf("successes=%d replays=%d", successes, replays)
	}
}

func TestNewVerifierRejectsUnboundedKeys(t *testing.T) {
	for _, key := range [][]byte{make([]byte, MinimumKeyBytes-1), make([]byte, MaximumKeyBytes+1)} {
		if _, err := NewVerifier(key, time.Now); err == nil {
			t.Fatalf("NewVerifier(%d bytes) accepted invalid key", len(key))
		}
	}
}

func signedInput(now time.Time, body []byte) Input {
	input := Input{
		Method:          "POST",
		Path:            "/v1/foundation/authorization-policy-bindings",
		BodyDigest:      sha256.Sum256(body),
		RequestID:       "11111111-1111-1111-1111-111111111111",
		CorrelationID:   "22222222-2222-2222-2222-222222222222",
		Subject:         "identity:example-user",
		Provider:        "gateway:test",
		AssertionID:     "assertion:test-1",
		AuthenticatedAt: now.Format(time.RFC3339Nano),
		Nonce:           base64.RawURLEncoding.EncodeToString([]byte("0123456789abcdef")),
	}
	sign(&input)
	return input
}

func sign(input *Input) {
	mac := hmac.New(sha256.New, testKey)
	_, _ = mac.Write([]byte(canonicalInput(*input)))
	input.Signature = "v1=" + hex.EncodeToString(mac.Sum(nil))
}
