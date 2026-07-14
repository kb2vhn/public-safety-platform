package observability

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

type safeTestError struct{}

func (safeTestError) Error() string       { return "secret raw error" }
func (safeTestError) SafeMessage() string { return "safe diagnostic" }

func TestSafeErrorRejectsArbitraryErrorText(t *testing.T) {
	t.Parallel()

	const secret = "postgresql://role:do-not-log@example.test/db"
	if value := SafeError(errors.New(secret)); strings.Contains(value, secret) {
		t.Fatalf("SafeError() disclosed %q", value)
	}
	if value := SafeError(safeTestError{}); value != "safe diagnostic" {
		t.Fatalf("SafeError() = %q", value)
	}
}

func TestJSONLoggerAddsProcessWithoutSecret(t *testing.T) {
	t.Parallel()

	var output bytes.Buffer
	logger := NewJSONLogger(&output, "foundation-api")
	logger.Info("configuration rejected", "diagnostic", SafeError(errors.New("password=do-not-log")))

	text := output.String()
	if !strings.Contains(text, `"process":"foundation-api"`) {
		t.Fatalf("log = %q", text)
	}
	if strings.Contains(text, "do-not-log") {
		t.Fatalf("log disclosed secret: %q", text)
	}
}
