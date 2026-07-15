package authentication

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"
)

func TestPhase6Step8ReplayWindowIsBoundedAndExpires(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	verifier, err := NewVerifier(testKey, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewVerifier() error = %v", err)
	}

	for index := 0; index < MaximumReplayEntries; index++ {
		input := step8UniqueSignedInput(now, index)
		if _, verifyErr := verifier.Verify(input); verifyErr != nil {
			t.Fatalf("Verify(%d) error = %v", index, verifyErr)
		}
	}

	overflow := step8UniqueSignedInput(now, MaximumReplayEntries)
	_, err = verifier.Verify(overflow)
	var handoffError *Error
	if !errors.As(err, &handoffError) || handoffError.Kind != ErrorCapacity {
		t.Fatalf("overflow error = %v, want capacity", err)
	}
	if Diagnostic(err) != "authentication_handoff_capacity" {
		t.Fatalf("Diagnostic() = %q", Diagnostic(err))
	}

	verifier.mu.Lock()
	entries := len(verifier.replays)
	verifier.mu.Unlock()
	if entries != MaximumReplayEntries {
		t.Fatalf("replay entries = %d, want %d", entries, MaximumReplayEntries)
	}

	now = now.Add(MaximumHandoffAge + MaximumFutureSkew)
	fresh := step8UniqueSignedInput(now, MaximumReplayEntries+1)
	if _, err = verifier.Verify(fresh); err != nil {
		t.Fatalf("Verify() after expiration error = %v", err)
	}

	verifier.mu.Lock()
	entries = len(verifier.replays)
	verifier.mu.Unlock()
	if entries != 1 {
		t.Fatalf("expired replay entries were not removed: %d remain", entries)
	}
}

func TestPhase6Step8SignedFieldTamperingFailsClosed(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	body := []byte(`{"decision_id":"33333333-3333-3333-3333-333333333333"}`)

	tests := []struct {
		name   string
		mutate func(*Input)
	}{
		{name: "method", mutate: func(input *Input) { input.Method = "GET" }},
		{name: "path", mutate: func(input *Input) { input.Path += "/other" }},
		{name: "request id", mutate: func(input *Input) { input.RequestID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }},
		{name: "correlation id", mutate: func(input *Input) { input.CorrelationID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" }},
		{name: "subject", mutate: func(input *Input) { input.Subject = "identity:other-user" }},
		{name: "provider", mutate: func(input *Input) { input.Provider = "gateway:other" }},
		{name: "assertion", mutate: func(input *Input) { input.AssertionID = "assertion:other" }},
		{name: "authenticated at", mutate: func(input *Input) { input.AuthenticatedAt = now.Add(-time.Second).Format(time.RFC3339Nano) }},
		{name: "nonce", mutate: func(input *Input) { input.Nonce = base64.RawURLEncoding.EncodeToString([]byte("fedcba9876543210")) }},
		{name: "body digest", mutate: func(input *Input) {
			input.BodyDigest = sha256.Sum256([]byte(`{"decision_id":"44444444-4444-4444-4444-444444444444"}`))
		}},
	}

	for _, testCase := range tests {
		t.Run(testCase.name, func(t *testing.T) {
			verifier, verifierErr := NewVerifier(testKey, func() time.Time { return now })
			if verifierErr != nil {
				t.Fatalf("NewVerifier() error = %v", verifierErr)
			}
			input := signedInput(now, body)
			testCase.mutate(&input)
			_, verifyErr := verifier.Verify(input)
			if verifyErr == nil {
				t.Fatal("Verify() accepted signed-field tampering")
			}
			if strings.Contains(verifyErr.Error(), input.Subject) || strings.Contains(verifyErr.Error(), input.AssertionID) {
				t.Fatalf("error disclosed signed identity: %q", verifyErr)
			}
		})
	}
}

func TestPhase6Step8SignatureFormattingAndKeyMismatchFailClosed(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	base := signedInput(now, []byte(`{}`))

	formatCases := []string{
		strings.ToUpper(base.Signature),
		strings.TrimPrefix(base.Signature, "v1="),
		base.Signature + "00",
		"v2=" + strings.TrimPrefix(base.Signature, "v1="),
	}
	for _, signature := range formatCases {
		verifier, err := NewVerifier(testKey, func() time.Time { return now })
		if err != nil {
			t.Fatalf("NewVerifier() error = %v", err)
		}
		input := base
		input.Signature = signature
		_, err = verifier.Verify(input)
		var handoffError *Error
		if !errors.As(err, &handoffError) || handoffError.Kind != ErrorMalformed {
			t.Fatalf("signature %q error = %v, want malformed", signature, err)
		}
	}

	wrongKey := []byte("abcdef0123456789abcdef0123456789")
	verifier, err := NewVerifier(wrongKey, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewVerifier() error = %v", err)
	}
	_, err = verifier.Verify(base)
	var handoffError *Error
	if !errors.As(err, &handoffError) || handoffError.Kind != ErrorInvalid {
		t.Fatalf("wrong-key error = %v, want invalid", err)
	}
}

func step8UniqueSignedInput(now time.Time, index int) Input {
	input := signedInput(now, []byte(`{}`))
	input.RequestID = fmt.Sprintf("11111111-1111-1111-1111-%012x", index+1)
	nonce := sha256.Sum256([]byte(fmt.Sprintf("phase6-step8-nonce-%d", index)))
	input.Nonce = base64.RawURLEncoding.EncodeToString(nonce[:16])
	sign(&input)
	return input
}
