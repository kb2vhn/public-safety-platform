package processhost

import (
	"context"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

func mapLookup(values map[string]string) LookupEnv {
	return func(name string) (string, bool) {
		value, ok := values[name]
		return value, ok
	}
}

func TestLoadStandaloneWithoutNotificationEnvironment(t *testing.T) {
	t.Parallel()

	notifier, err := Load(mapLookup(nil), 1234)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if notifier.Enabled() || notifier.WatchdogEnabled() {
		t.Fatal("standalone notifier unexpectedly enabled")
	}
	if err := notifier.Ready(); err != nil {
		t.Fatalf("standalone Ready() error = %v", err)
	}
}

func TestLoadRejectsInconsistentOrMalformedWatchdogEnvironment(t *testing.T) {
	t.Parallel()

	tests := []map[string]string{
		{EnvWatchdogUsec: "30000000"},
		{EnvNotifySocket: "/run/notify.sock", EnvWatchdogPID: "1234"},
		{EnvNotifySocket: "/run/notify.sock", EnvWatchdogUsec: ""},
		{EnvNotifySocket: "/run/notify.sock", EnvWatchdogUsec: "not-a-number"},
		{EnvNotifySocket: "/run/notify.sock", EnvWatchdogUsec: "1"},
		{EnvNotifySocket: "/run/notify.sock", EnvWatchdogUsec: "999999999999"},
		{
			EnvNotifySocket: "/run/notify.sock",
			EnvWatchdogUsec: "30000000",
			EnvWatchdogPID:  "not-a-pid",
		},
	}

	for index, values := range tests {
		values := values
		t.Run(strconv.Itoa(index), func(t *testing.T) {
			t.Parallel()
			_, err := Load(mapLookup(values), 1234)
			if err == nil || !IsConfiguration(err) {
				t.Fatalf("Load() error = %v, want configuration error", err)
			}
		})
	}
}

func TestLoadRejectsMalformedNotificationSocket(t *testing.T) {
	t.Parallel()

	for _, value := range []string{"", "relative.sock", "@"} {
		value := value
		t.Run(strconv.Quote(value), func(t *testing.T) {
			t.Parallel()
			_, err := Load(
				mapLookup(map[string]string{EnvNotifySocket: value}),
				1234,
			)
			if err == nil || IsConfiguration(err) {
				t.Fatalf("Load() error = %v, want operating-system class", err)
			}
		})
	}
}

func TestWatchdogPIDMismatchDisablesOnlyWatchdog(t *testing.T) {
	t.Parallel()

	notifier, err := Load(
		mapLookup(map[string]string{
			EnvNotifySocket: "/run/notify.sock",
			EnvWatchdogUsec: "30000000",
			EnvWatchdogPID:  "4321",
		}),
		1234,
	)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !notifier.Enabled() {
		t.Fatal("notification unexpectedly disabled")
	}
	if notifier.WatchdogEnabled() {
		t.Fatal("watchdog remained enabled for another process")
	}
}

func TestFilesystemNotificationMessages(t *testing.T) {
	t.Parallel()

	directory := t.TempDir()
	socketPath := filepath.Join(directory, "notify.sock")
	listener := listenUnixgram(t, socketPath)
	defer listener.Close()

	notifier, err := Load(
		mapLookup(map[string]string{
			EnvNotifySocket: socketPath,
			EnvWatchdogUsec: "2000000",
			EnvWatchdogPID:  strconv.Itoa(os.Getpid()),
		}),
		os.Getpid(),
	)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if notifier.WatchdogPeriod() != time.Second {
		t.Fatalf("WatchdogPeriod() = %s", notifier.WatchdogPeriod())
	}

	if err := notifier.Ready(); err != nil {
		t.Fatalf("Ready() error = %v", err)
	}
	if message := readMessage(t, listener); message != "READY=1\nSTATUS=ready" {
		t.Fatalf("ready message = %q", message)
	}

	if err := notifier.Watchdog(); err != nil {
		t.Fatalf("Watchdog() error = %v", err)
	}
	if message := readMessage(t, listener); message != "WATCHDOG=1" {
		t.Fatalf("watchdog message = %q", message)
	}

	if err := notifier.Stopping(); err != nil {
		t.Fatalf("Stopping() error = %v", err)
	}
	if message := readMessage(t, listener); message != "STOPPING=1\nSTATUS=stopping" {
		t.Fatalf("stopping message = %q", message)
	}
}

func TestAbstractNamespaceNotification(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("Linux abstract namespace is required")
	}

	name := "issp-step4-" + strconv.Itoa(os.Getpid()) + "-" +
		strings.ReplaceAll(t.Name(), "/", "-")
	listener := listenUnixgram(t, "\x00"+name)
	defer listener.Close()

	notifier, err := Load(
		mapLookup(map[string]string{EnvNotifySocket: "@" + name}),
		os.Getpid(),
	)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if err := notifier.Ready(); err != nil {
		t.Fatalf("Ready() error = %v", err)
	}
	if message := readMessage(t, listener); message != "READY=1\nSTATUS=ready" {
		t.Fatalf("abstract ready message = %q", message)
	}
}

func TestRunWatchdogStopsOnCancellation(t *testing.T) {
	t.Parallel()

	directory := t.TempDir()
	socketPath := filepath.Join(directory, "notify.sock")
	listener := listenUnixgram(t, socketPath)
	defer listener.Close()

	notifier, err := Load(
		mapLookup(map[string]string{
			EnvNotifySocket: socketPath,
			EnvWatchdogUsec: "2000000",
		}),
		os.Getpid(),
	)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan error, 1)
	go func() {
		result <- notifier.RunWatchdog(ctx)
	}()

	if message := readMessage(t, listener); message != "WATCHDOG=1" {
		t.Fatalf("initial watchdog message = %q", message)
	}
	cancel()

	select {
	case err := <-result:
		if err != nil {
			t.Fatalf("RunWatchdog() error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("RunWatchdog() did not stop after cancellation")
	}
}

func TestRunWatchdogReportsDisappearedSocket(t *testing.T) {
	t.Parallel()

	socketPath := filepath.Join(t.TempDir(), "missing.sock")
	notifier, err := Load(
		mapLookup(map[string]string{
			EnvNotifySocket: socketPath,
			EnvWatchdogUsec: "2000000",
		}),
		os.Getpid(),
	)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	err = notifier.RunWatchdog(context.Background())
	if err == nil || IsConfiguration(err) {
		t.Fatalf("RunWatchdog() error = %v, want operating-system class", err)
	}
	if strings.Contains(err.Error(), socketPath) {
		t.Fatalf("error disclosed notification socket path: %v", err)
	}
}

func listenUnixgram(t *testing.T, name string) *net.UnixConn {
	t.Helper()

	address := &net.UnixAddr{Name: name, Net: "unixgram"}
	listener, err := net.ListenUnixgram("unixgram", address)
	if err != nil {
		t.Fatalf("ListenUnixgram() error = %v", err)
	}
	return listener
}

func readMessage(t *testing.T, listener *net.UnixConn) string {
	t.Helper()

	if err := listener.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatalf("SetReadDeadline() error = %v", err)
	}
	buffer := make([]byte, maxNotificationSize)
	count, _, err := listener.ReadFromUnix(buffer)
	if err != nil {
		t.Fatalf("ReadFromUnix() error = %v", err)
	}
	return string(buffer[:count])
}
