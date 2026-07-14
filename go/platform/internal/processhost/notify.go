// Package processhost owns the bounded Linux service-manager notification
// boundary used by the production processes.
package processhost

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	EnvNotifySocket = "NOTIFY_SOCKET"
	EnvWatchdogUsec = "WATCHDOG_USEC"
	EnvWatchdogPID  = "WATCHDOG_PID"

	maxNotificationSize      = 4 * 1024
	maxUnixSocketName        = 107
	minimumWatchdogInterval  = 2 * time.Second
	maximumWatchdogInterval  = 5 * time.Minute
	notificationWriteTimeout = 500 * time.Millisecond
)

// LookupEnv is compatible with os.LookupEnv and permits deterministic tests.
type LookupEnv func(string) (string, bool)

// ErrorClass separates malformed host configuration from local operating-system
// notification failures.
type ErrorClass string

const (
	ErrorConfiguration   ErrorClass = "configuration"
	ErrorOperatingSystem ErrorClass = "operating_system"
)

// Error contains only bounded, non-secret diagnostics.
type Error struct {
	Class  ErrorClass
	Field  string
	Reason string
}

func (e *Error) Error() string {
	return fmt.Sprintf("process-host field %s is invalid: %s", e.Field, e.Reason)
}

// SafeMessage marks Error as safe for structured logging.
func (e *Error) SafeMessage() string { return e.Error() }

// IsConfiguration reports whether err maps to the configuration exit class.
func IsConfiguration(err error) bool {
	var target *Error
	return errors.As(err, &target) && target.Class == ErrorConfiguration
}

// Diagnostic returns one bounded diagnostic class without exposing socket paths.
func Diagnostic(err error) string {
	var target *Error
	if errors.As(err, &target) {
		return "process_host_" + string(target.Class) + "_failure"
	}
	return "process_host_failure"
}

// Notifier represents optional systemd-compatible service-manager notification.
// A zero-value notifier is valid standalone mode.
type Notifier struct {
	address          *net.UnixAddr
	watchdogInterval time.Duration
}

// Load parses the service-manager environment. Absence of NOTIFY_SOCKET is
// explicit standalone mode. Present malformed values fail closed.
func Load(lookup LookupEnv, pid int) (*Notifier, error) {
	if lookup == nil {
		lookup = os.LookupEnv
	}

	rawSocket, socketPresent := lookup(EnvNotifySocket)
	rawWatchdog, watchdogPresent := lookup(EnvWatchdogUsec)
	rawPID, pidPresent := lookup(EnvWatchdogPID)

	if !socketPresent {
		if watchdogPresent || pidPresent {
			return nil, &Error{
				Class:  ErrorConfiguration,
				Field:  EnvWatchdogUsec,
				Reason: "watchdog environment requires notification socket",
			}
		}
		return &Notifier{}, nil
	}

	address, err := parseAddress(rawSocket)
	if err != nil {
		return nil, err
	}
	notifier := &Notifier{address: address}

	if !watchdogPresent {
		if pidPresent {
			return nil, &Error{
				Class:  ErrorConfiguration,
				Field:  EnvWatchdogPID,
				Reason: "process identifier requires watchdog interval",
			}
		}
		return notifier, nil
	}

	interval, err := parseWatchdogInterval(rawWatchdog)
	if err != nil {
		return nil, err
	}

	if pidPresent {
		watchedPID, parseErr := strconv.Atoi(strings.TrimSpace(rawPID))
		if parseErr != nil || watchedPID <= 0 {
			return nil, &Error{
				Class:  ErrorConfiguration,
				Field:  EnvWatchdogPID,
				Reason: "must be a positive process identifier",
			}
		}
		if watchedPID != pid {
			return notifier, nil
		}
	}

	notifier.watchdogInterval = interval
	return notifier, nil
}

func parseAddress(value string) (*net.UnixAddr, error) {
	if value == "" {
		return nil, &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "value is empty",
		}
	}
	if strings.ContainsRune(value, '\x00') {
		return nil, &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "value contains a NUL byte",
		}
	}

	name := value
	if strings.HasPrefix(value, "@") {
		if len(value) == 1 {
			return nil, &Error{
				Class:  ErrorOperatingSystem,
				Field:  EnvNotifySocket,
				Reason: "abstract socket name is empty",
			}
		}
		name = "\x00" + value[1:]
	} else if !filepath.IsAbs(value) {
		return nil, &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "filesystem socket path must be absolute",
		}
	}

	if len(name) > maxUnixSocketName {
		return nil, &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "socket name exceeds Linux unix-domain limit",
		}
	}

	return &net.UnixAddr{Name: name, Net: "unixgram"}, nil
}

func parseWatchdogInterval(value string) (time.Duration, error) {
	parsed, err := strconv.ParseUint(strings.TrimSpace(value), 10, 64)
	if err != nil || parsed == 0 {
		return 0, &Error{
			Class:  ErrorConfiguration,
			Field:  EnvWatchdogUsec,
			Reason: "must be a positive integer number of microseconds",
		}
	}
	if parsed > uint64(maximumWatchdogInterval/time.Microsecond) {
		return 0, &Error{
			Class:  ErrorConfiguration,
			Field:  EnvWatchdogUsec,
			Reason: "exceeds the accepted maximum",
		}
	}

	interval := time.Duration(parsed) * time.Microsecond
	if interval < minimumWatchdogInterval {
		return 0, &Error{
			Class:  ErrorConfiguration,
			Field:  EnvWatchdogUsec,
			Reason: "is below the accepted minimum",
		}
	}
	return interval, nil
}

// Enabled reports whether service-manager notification is active.
func (n *Notifier) Enabled() bool {
	return n != nil && n.address != nil
}

// WatchdogEnabled reports whether this main process owns the watchdog.
func (n *Notifier) WatchdogEnabled() bool {
	return n.Enabled() && n.watchdogInterval > 0
}

// WatchdogPeriod is one half of the accepted watchdog interval.
func (n *Notifier) WatchdogPeriod() time.Duration {
	if !n.WatchdogEnabled() {
		return 0
	}
	return n.watchdogInterval / 2
}

// Ready sends the bounded ready state.
func (n *Notifier) Ready() error {
	return n.send("READY=1\nSTATUS=ready")
}

// Stopping sends the bounded stopping state.
func (n *Notifier) Stopping() error {
	return n.send("STOPPING=1\nSTATUS=stopping")
}

// Watchdog sends one watchdog keepalive.
func (n *Notifier) Watchdog() error {
	return n.send("WATCHDOG=1")
}

// RunWatchdog sends one immediate keepalive and then one keepalive each half
// interval until cancellation or a local notification failure.
func (n *Notifier) RunWatchdog(ctx context.Context) error {
	if !n.WatchdogEnabled() {
		return nil
	}
	if err := n.Watchdog(); err != nil {
		return err
	}

	ticker := time.NewTicker(n.WatchdogPeriod())
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			if err := n.Watchdog(); err != nil {
				return err
			}
		}
	}
}

func (n *Notifier) send(payload string) error {
	if !n.Enabled() {
		return nil
	}
	if payload == "" || len(payload) > maxNotificationSize ||
		strings.ContainsRune(payload, '\x00') {
		return &Error{
			Class:  ErrorConfiguration,
			Field:  "notification_payload",
			Reason: "payload is outside the accepted boundary",
		}
	}

	connection, err := net.DialUnix("unixgram", nil, n.address)
	if err != nil {
		return &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "cannot connect to notification socket",
		}
	}
	defer connection.Close()

	if err := connection.SetWriteDeadline(
		time.Now().Add(notificationWriteTimeout),
	); err != nil {
		return &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "cannot bound notification write",
		}
	}

	written, err := connection.Write([]byte(payload))
	if err != nil {
		return &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: "notification write failed",
		}
	}
	if written != len(payload) {
		return &Error{
			Class:  ErrorOperatingSystem,
			Field:  EnvNotifySocket,
			Reason: io.ErrShortWrite.Error(),
		}
	}
	return nil
}
