package bootstrap

import (
	"bytes"
	"fmt"
	"testing"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestRunIsFailClosedSkeleton(t *testing.T) {
	t.Parallel()

	for _, identity := range database.All() {
		identity := identity
		t.Run(identity.ProcessName, func(t *testing.T) {
			t.Parallel()

			var output bytes.Buffer
			if code := Run(&output, identity); code != ExitConfiguration {
				t.Fatalf("exit code = %d, want %d", code, ExitConfiguration)
			}

			want := fmt.Sprintf(
				"%s: Phase 6 Step 2 executable skeleton; runtime bootstrap is not implemented\n",
				identity.ProcessName,
			)
			if output.String() != want {
				t.Fatalf("output = %q, want %q", output.String(), want)
			}
		})
	}
}
