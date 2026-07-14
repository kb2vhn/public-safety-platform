package bootstrap

import (
	"bytes"
	"context"
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
