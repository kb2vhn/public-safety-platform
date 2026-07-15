package bootstrap

import (
	"bytes"
	"context"
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestRunFailsClosedWithoutConfiguration(t *testing.T) {
	for _, identity := range database.All() {
		identity := identity
		t.Run(identity.ProcessName, func(t *testing.T) {
			t.Setenv("ISSP_ADMIN_LISTEN_ADDRESS", "")
			t.Setenv("ISSP_DATABASE_DSN_FILE", "")

			var output bytes.Buffer
			if code := Run(context.Background(), &output, identity); code != ExitConfiguration {
				t.Fatalf("exit code = %d, want %d", code, ExitConfiguration)
			}
			text := output.String()
			if !strings.Contains(text, `"msg":"configuration rejected"`) {
				t.Fatalf("output = %q", text)
			}
			if strings.Contains(text, "postgresql://") || strings.Contains(text, "password=") {
				t.Fatalf("output disclosed a connection secret: %q", text)
			}
		})
	}
}

func TestRunRejectsMalformedNotificationSocketBeforeDatabaseAccess(t *testing.T) {
	configureMinimumRuntime(t)
	t.Setenv("NOTIFY_SOCKET", "relative-notify.sock")

	var output bytes.Buffer
	code := Run(context.Background(), &output, database.FoundationAPI)
	if code != ExitOperatingSystem {
		t.Fatalf("exit code = %d, want %d", code, ExitOperatingSystem)
	}
	if !strings.Contains(output.String(), "process-host environment rejected") {
		t.Fatalf("output = %q", output.String())
	}
	if strings.Contains(output.String(), "relative-notify.sock") {
		t.Fatalf("output disclosed notification socket path: %q", output.String())
	}
}

func TestRunRejectsWatchdogWithoutNotificationSocket(t *testing.T) {
	configureMinimumRuntime(t)
	t.Setenv("WATCHDOG_USEC", "30000000")

	var output bytes.Buffer
	code := Run(context.Background(), &output, database.FoundationAPI)
	if code != ExitConfiguration {
		t.Fatalf("exit code = %d, want %d", code, ExitConfiguration)
	}
	if !strings.Contains(output.String(), "process-host environment rejected") {
		t.Fatalf("output = %q", output.String())
	}
}

func configureMinimumRuntime(t *testing.T) {
	t.Helper()

	directory := t.TempDir()
	dsnPath := filepath.Join(directory, "database-url")
	keyPath := filepath.Join(directory, "transport-hmac-key")
	if err := os.WriteFile(
		dsnPath,
		[]byte("postgresql://role:secret@127.0.0.1:1/db?sslmode=disable\n"),
		0o600,
	); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}

	encodedKey := base64.RawURLEncoding.EncodeToString(
		[]byte("0123456789abcdef0123456789abcdef"),
	)
	if err := os.WriteFile(keyPath, []byte(encodedKey+"\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}

	t.Setenv("ISSP_ADMIN_LISTEN_ADDRESS", "127.0.0.1:18081")
	t.Setenv("ISSP_BUSINESS_LISTEN_ADDRESS", "127.0.0.1:18080")
	t.Setenv("ISSP_TRANSPORT_HMAC_KEY_FILE", keyPath)
	t.Setenv("ISSP_DATABASE_DSN_FILE", dsnPath)
	t.Setenv("ISSP_DATABASE_ALLOW_INSECURE_LOCAL", "true")
}

func TestRunRejectsMissingTransportCredentialBeforeDatabaseAccess(t *testing.T) {
	configureMinimumRuntime(t)
	t.Setenv("ISSP_TRANSPORT_HMAC_KEY_FILE", filepath.Join(t.TempDir(), "missing-key"))

	var output bytes.Buffer
	code := Run(context.Background(), &output, database.FoundationAPI)
	if code != ExitConfiguration {
		t.Fatalf("exit code = %d, want %d", code, ExitConfiguration)
	}
	if !strings.Contains(output.String(), "transport credential rejected") {
		t.Fatalf("output = %q", output.String())
	}
	if strings.Contains(output.String(), "missing-key") {
		t.Fatalf("output disclosed credential path: %q", output.String())
	}
}
