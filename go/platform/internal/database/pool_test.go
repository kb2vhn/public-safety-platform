package database

import (
	"errors"
	"testing"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
)

func TestValidateDatabaseURLBindsExactRole(t *testing.T) {
	t.Parallel()

	_, err := validateDatabaseURL(
		"postgresql://issp_service_integration_delivery:secret@127.0.0.1:5432/issp?sslmode=disable",
		true,
		FoundationAPI,
	)
	if err == nil {
		t.Fatal("validateDatabaseURL() accepted the wrong service role")
	}
}

func TestValidateDatabaseURLRequiresExplicitRemoteVerification(t *testing.T) {
	t.Parallel()

	_, err := validateDatabaseURL(
		"postgresql://issp_service_authorization:secret@db.example.test:5432/issp?sslmode=require",
		false,
		FoundationAPI,
	)
	if err == nil {
		t.Fatal("validateDatabaseURL() accepted sslmode=require")
	}

	if _, err := validateDatabaseURL(
		"postgresql://issp_service_authorization:secret@db.example.test:5432/issp?sslmode=verify-full&sslrootcert=/run/credentials/root.pem",
		false,
		FoundationAPI,
	); err != nil {
		t.Fatalf("validateDatabaseURL() error = %v", err)
	}
}

func TestDatabaseErrorsDoNotExposeWrappedSecret(t *testing.T) {
	t.Parallel()

	const secret = "postgresql://role:do-not-log@example.test/db"
	err := &Error{Stage: "configuration", Cause: errors.New(secret)}
	if err.Error() == secret {
		t.Fatal("Error() exposed the wrapped secret")
	}
	if Diagnostic(err) != "database_configuration" {
		t.Fatalf("Diagnostic() = %q", Diagnostic(err))
	}

	cfgErr := &config.Error{Field: config.EnvDatabaseDSNFile, Reason: "cannot read configured file"}
	if cfgErr.SafeMessage() == "" {
		t.Fatal("safe configuration message is empty")
	}
}

func TestValidateDatabaseURLRequiresExplicitPort(t *testing.T) {
	t.Parallel()

	_, err := validateDatabaseURL(
		"postgresql://issp_service_authorization:secret@127.0.0.1/issp?sslmode=disable",
		true,
		FoundationAPI,
	)
	if err == nil {
		t.Fatal("validateDatabaseURL() accepted a URL without an explicit port")
	}
}

func TestValidateDatabaseURLRejectsDuplicateOptions(t *testing.T) {
	t.Parallel()

	_, err := validateDatabaseURL(
		"postgresql://issp_service_authorization:secret@127.0.0.1:5432/issp?sslmode=disable&sslmode=verify-full",
		true,
		FoundationAPI,
	)
	if err == nil {
		t.Fatal("validateDatabaseURL() accepted a duplicate sslmode option")
	}
}
