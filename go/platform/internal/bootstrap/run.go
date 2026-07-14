// Package bootstrap owns process startup ordering. Step 2 intentionally stops
// before configuration, listeners, database pools, or worker loops exist.
package bootstrap

import (
	"fmt"
	"io"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

// ExitConfiguration is the sysexits-compatible status used while an
// executable has no accepted runtime configuration or implementation.
const ExitConfiguration = 78

// Run emits the bounded skeleton status and returns without opening any
// listener, loading any credential, or contacting PostgreSQL.
func Run(output io.Writer, identity database.ServiceIdentity) int {
	_, _ = fmt.Fprintf(
		output,
		"%s: Phase 6 Step 2 executable skeleton; runtime bootstrap is not implemented\n",
		identity.ProcessName,
	)
	return ExitConfiguration
}
