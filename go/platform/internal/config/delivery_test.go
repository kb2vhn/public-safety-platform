package config

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadDeliveryWorkerDefaults(t *testing.T) {
	t.Parallel()
	values := workerEnvironment("integration-delivery-worker")
	cfg, err := Load("integration-delivery-worker", mapLookup(values))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !cfg.Delivery.Enabled || cfg.Delivery.BatchSize != 8 || cfg.Delivery.MaxConcurrent != 4 || cfg.Delivery.ClaimLease != 30*time.Second || cfg.Delivery.RequestTimeout != 5*time.Second {
		t.Fatalf("Delivery = %#v", cfg.Delivery)
	}
	if cfg.Business.Enabled {
		t.Fatal("worker unexpectedly received business transport")
	}
}

func TestLoadRejectsDeliveryAuthorityForFoundationAPI(t *testing.T) {
	t.Parallel()
	values := map[string]string{
		EnvAdminListenAddress:    "127.0.0.1:18081",
		EnvBusinessListenAddress: "127.0.0.1:18080",
		EnvTransportHMACKeyFile:  "/run/credentials/foundation-api/transport-hmac-key",
		EnvDatabaseDSNFile:       "/run/credentials/foundation-api/database-url",
		EnvDeliveryEndpoint:      "https://relay.example.test/v1/deliver",
	}
	if _, err := Load("foundation-api", mapLookup(values)); err == nil {
		t.Fatal("Load() accepted delivery authority for foundation-api")
	}
}

func TestLoadRejectsRemoteHTTPAndDatabaseDestinationNetworking(t *testing.T) {
	t.Parallel()
	values := workerEnvironment("monitoring-delivery-worker")
	values[EnvDeliveryEndpoint] = "http://relay.example.test/v1/deliver"
	if _, err := Load("monitoring-delivery-worker", mapLookup(values)); err == nil {
		t.Fatal("Load() accepted insecure remote endpoint")
	}
	values[EnvDeliveryAllowInsecureLocal] = "true"
	if _, err := Load("monitoring-delivery-worker", mapLookup(values)); err == nil {
		t.Fatal("Load() accepted non-loopback insecure endpoint")
	}
}

func TestReadDeliveryToken(t *testing.T) {
	t.Parallel()
	directory := t.TempDir()
	path := filepath.Join(directory, "delivery-token")
	want := []byte("0123456789abcdef0123456789abcdef")
	encoded := base64.RawURLEncoding.EncodeToString(want)
	if err := os.WriteFile(path, []byte(encoded+"\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
	got, err := ReadDeliveryToken(path)
	if err != nil {
		t.Fatalf("ReadDeliveryToken() error = %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("token mismatch")
	}
}

func workerEnvironment(process string) map[string]string {
	port := "18082"
	if process == "monitoring-delivery-worker" {
		port = "18083"
	}
	return map[string]string{
		EnvAdminListenAddress: "127.0.0.1:" + port,
		EnvDatabaseDSNFile:    "/run/credentials/" + process + "/database-url",
		EnvDeliveryEndpoint:   "https://relay.example.test/v1/deliver",
		EnvDeliveryTokenFile:  "/run/credentials/" + process + "/delivery-token",
	}
}

func mapLookup(values map[string]string) LookupEnv {
	return func(name string) (string, bool) {
		value, ok := values[name]
		return value, ok
	}
}
