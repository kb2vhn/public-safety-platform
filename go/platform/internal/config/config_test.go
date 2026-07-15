package config

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLoadDefaultsAndBounds(t *testing.T) {
	t.Parallel()

	values := map[string]string{
		EnvAdminListenAddress:    "127.0.0.1:18081",
		EnvBusinessListenAddress: "127.0.0.1:18080",
		EnvTransportHMACKeyFile:  "/run/credentials/foundation-api/transport-hmac-key",
		EnvDatabaseDSNFile:       "/run/credentials/foundation-api/database-url",
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
	if !cfg.Business.Enabled || cfg.Business.MaxConcurrentRequests != 8 {
		t.Fatalf("unexpected business transport defaults: %+v", cfg.Business)
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

func TestLoadBusinessTransportIsFoundationOnlyAndSeparated(t *testing.T) {
	t.Parallel()

	base := map[string]string{
		EnvAdminListenAddress:    "127.0.0.1:18081",
		EnvBusinessListenAddress: "127.0.0.1:18080",
		EnvTransportHMACKeyFile:  "/run/credentials/foundation-api/transport-hmac-key",
		EnvDatabaseDSNFile:       "/run/credentials/foundation-api/database-url",
	}
	lookup := func(values map[string]string) LookupEnv {
		return func(name string) (string, bool) {
			value, ok := values[name]
			return value, ok
		}
	}

	if _, err := Load("foundation-api", lookup(base)); err != nil {
		t.Fatalf("foundation Load() error = %v", err)
	}
	if _, err := Load("integration-delivery-worker", lookup(base)); err == nil ||
		!strings.Contains(err.Error(), EnvBusinessListenAddress) {
		t.Fatalf("worker Load() error = %v, want business-setting rejection", err)
	}

	sameAddress := mapsClone(base)
	sameAddress[EnvBusinessListenAddress] = sameAddress[EnvAdminListenAddress]
	if _, err := Load("foundation-api", lookup(sameAddress)); err == nil ||
		!strings.Contains(err.Error(), EnvBusinessListenAddress) {
		t.Fatalf("same-address Load() error = %v", err)
	}
}

func TestReadTransportHMACKeyRequiresProtectedCanonicalBase64URL(t *testing.T) {
	t.Parallel()

	directory := t.TempDir()
	path := filepath.Join(directory, "transport-hmac-key")
	key := []byte("0123456789abcdef0123456789abcdef")
	encoded := base64.RawURLEncoding.EncodeToString(key)
	if err := os.WriteFile(path, []byte(encoded+"\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
	actual, err := ReadTransportHMACKey(path)
	if err != nil {
		t.Fatalf("ReadTransportHMACKey() error = %v", err)
	}
	if string(actual) != string(key) {
		t.Fatalf("decoded key mismatch")
	}
	if err := os.WriteFile(path, []byte("too-short\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
	if _, err := ReadTransportHMACKey(path); err == nil {
		t.Fatal("ReadTransportHMACKey() accepted invalid key")
	}
}

func mapsClone(source map[string]string) map[string]string {
	clone := make(map[string]string, len(source))
	for key, value := range source {
		clone[key] = value
	}
	return clone
}
