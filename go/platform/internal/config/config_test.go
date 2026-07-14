package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLoadDefaultsAndBounds(t *testing.T) {
	t.Parallel()

	values := map[string]string{
		EnvAdminListenAddress: "127.0.0.1:18081",
		EnvDatabaseDSNFile:    "/run/credentials/foundation-api/database-url",
	}
	lookup := func(name string) (string, bool) {
		value, ok := values[name]
		return value, ok
	}

	cfg, err := Load("foundation-api", lookup)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Database.MaxConnections != 4 || cfg.Database.MinConnections != 0 {
		t.Fatalf("unexpected pool defaults: %+v", cfg.Database)
	}
	if cfg.StartupTimeout != 15*time.Second || cfg.ShutdownTimeout != 10*time.Second {
		t.Fatalf("unexpected lifecycle defaults: %+v", cfg)
	}
	if strings.Contains(cfg.String(), cfg.Database.DSNFile) {
		t.Fatal("Config.String() disclosed the credential path")
	}
}

func TestLoadRejectsNonLoopbackAdministrativeListener(t *testing.T) {
	t.Parallel()

	values := map[string]string{
		EnvAdminListenAddress: "0.0.0.0:8081",
		EnvDatabaseDSNFile:    "/run/credentials/database-url",
	}
	_, err := Load("foundation-api", func(name string) (string, bool) {
		value, ok := values[name]
		return value, ok
	})
	if err == nil || !strings.Contains(err.Error(), EnvAdminListenAddress) {
		t.Fatalf("Load() error = %v, want loopback rejection", err)
	}
}

func TestLoadRejectsPoolExpansion(t *testing.T) {
	t.Parallel()

	values := map[string]string{
		EnvAdminListenAddress:     "127.0.0.1:8081",
		EnvDatabaseDSNFile:        "/run/credentials/database-url",
		EnvDatabaseMaxConnections: "17",
	}
	_, err := Load("foundation-api", func(name string) (string, bool) {
		value, ok := values[name]
		return value, ok
	})
	if err == nil || !strings.Contains(err.Error(), EnvDatabaseMaxConnections) {
		t.Fatalf("Load() error = %v, want pool-bound rejection", err)
	}
}

func TestReadDatabaseURLRequiresProtectedRegularFile(t *testing.T) {
	t.Parallel()

	directory := t.TempDir()
	path := filepath.Join(directory, "database-url")
	const secret = "postgresql://issp_service_authorization:do-not-log@127.0.0.1:5432/issp?sslmode=disable"
	if err := os.WriteFile(path, []byte(secret+"\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}

	value, err := ReadDatabaseURL(path)
	if err != nil {
		t.Fatalf("ReadDatabaseURL() error = %v", err)
	}
	if value != secret {
		t.Fatalf("ReadDatabaseURL() = %q", value)
	}

	if err := os.Chmod(path, 0o640); err != nil {
		t.Fatalf("Chmod() error = %v", err)
	}
	if _, err := ReadDatabaseURL(path); err == nil {
		t.Fatal("ReadDatabaseURL() accepted group-readable secret")
	}
}

func TestReadDatabaseURLRejectsSymlink(t *testing.T) {
	directory := t.TempDir()
	target := filepath.Join(directory, "target")
	link := filepath.Join(directory, "database-url")
	if err := os.WriteFile(target, []byte("postgresql://role:secret@127.0.0.1:5432/db?sslmode=disable\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
	if err := os.Symlink(target, link); err != nil {
		t.Fatalf("Symlink() error = %v", err)
	}
	if _, err := ReadDatabaseURL(link); err == nil {
		t.Fatal("ReadDatabaseURL() accepted a symbolic link")
	}
}
