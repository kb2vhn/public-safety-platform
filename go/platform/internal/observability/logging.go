package observability

import (
	"io"
	"log/slog"
)

// NewJSONLogger creates the production Step 3 logger. The process field is
// attached once and cannot be omitted by individual log calls.
func NewJSONLogger(output io.Writer, process string) *slog.Logger {
	handler := slog.NewJSONHandler(output, &slog.HandlerOptions{Level: slog.LevelInfo})
	return slog.New(handler).With("process", process)
}

// SafeError returns only an explicitly redacted message. Arbitrary error text
// is never emitted because parser, network, and database errors may contain
// credential-bearing connection details.
func SafeError(err error) string {
	if err == nil {
		return ""
	}
	if safe, ok := err.(interface{ SafeMessage() string }); ok {
		return safe.SafeMessage()
	}
	return "operation failed"
}
