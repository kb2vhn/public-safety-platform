package database

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/url"
	"path"
	"strconv"
	"strings"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	minimumPostgreSQLVersion = 180000
	maximumPostgreSQLVersion = 190000
)

// Compatibility records the non-secret server facts proven during startup.
type Compatibility struct {
	CurrentUser               string
	CurrentDatabase           string
	ServerVersionNumber       int
	ApplicationName           string
	TimeZone                  string
	SearchPath                string
	StandardConformingStrings string
}

// Error is a redacted database error. The wrapped cause remains available to
// tests and diagnostics without being emitted by Error().
type Error struct {
	Stage string
	Cause error
}

func (e *Error) Error() string       { return fmt.Sprintf("database %s failed", e.Stage) }
func (e *Error) Unwrap() error       { return e.Cause }
func (e *Error) SafeMessage() string { return e.Error() }

// Diagnostic returns a bounded non-secret error classification.
func Diagnostic(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code != "" {
		return "postgres_sqlstate_" + pgErr.Code
	}
	var dbErr *Error
	if errors.As(err, &dbErr) && dbErr.Stage != "" {
		return "database_" + strings.ReplaceAll(dbErr.Stage, " ", "_")
	}
	return "database_operation_failed"
}

// Open reads the protected PostgreSQL URL, creates one bounded pool, and proves
// the exact service identity and PostgreSQL 18 compatibility contract.
func Open(ctx context.Context, cfg config.Config, identity ServiceIdentity) (*pgxpool.Pool, Compatibility, error) {
	databaseURL, err := config.ReadDatabaseURL(cfg.Database.DSNFile)
	if err != nil {
		return nil, Compatibility{}, &Error{Stage: "credential loading", Cause: err}
	}

	parsedURL, err := validateDatabaseURL(databaseURL, cfg.Database.AllowInsecureLocal, identity)
	if err != nil {
		return nil, Compatibility{}, &Error{Stage: "configuration", Cause: err}
	}

	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, Compatibility{}, &Error{Stage: "configuration", Cause: err}
	}

	poolConfig.MaxConns = cfg.Database.MaxConnections
	poolConfig.MinConns = cfg.Database.MinConnections
	poolConfig.MaxConnLifetime = cfg.Database.MaxConnectionLifetime
	poolConfig.MaxConnIdleTime = cfg.Database.MaxConnectionIdleTime
	poolConfig.HealthCheckPeriod = cfg.Database.HealthCheckPeriod
	poolConfig.ConnConfig.ConnectTimeout = cfg.Database.ConnectTimeout
	poolConfig.ConnConfig.Fallbacks = nil
	if poolConfig.ConnConfig.RuntimeParams == nil {
		poolConfig.ConnConfig.RuntimeParams = make(map[string]string)
	}
	poolConfig.ConnConfig.RuntimeParams["application_name"] = "issp/" + identity.ProcessName
	poolConfig.ConnConfig.RuntimeParams["TimeZone"] = "UTC"
	poolConfig.ConnConfig.RuntimeParams["search_path"] = "pg_catalog"
	poolConfig.ConnConfig.RuntimeParams["statement_timeout"] = "5000"
	poolConfig.ConnConfig.RuntimeParams["lock_timeout"] = "2000"
	poolConfig.ConnConfig.RuntimeParams["idle_in_transaction_session_timeout"] = "5000"

	// ParseConfig may use environment defaults. Reassert the identity and host
	// already proven from the complete URL so ambient PG* variables cannot
	// silently change the accepted boundary.
	poolConfig.ConnConfig.User = identity.PostgreSQLRole
	poolConfig.ConnConfig.Host = parsedURL.Hostname()
	portNumber, parseErr := strconv.ParseUint(parsedURL.Port(), 10, 16)
	if parseErr != nil || portNumber == 0 {
		return nil, Compatibility{}, &Error{Stage: "configuration", Cause: fmt.Errorf("invalid PostgreSQL port")}
	}
	poolConfig.ConnConfig.Port = uint16(portNumber)
	poolConfig.ConnConfig.Database = strings.TrimPrefix(path.Clean(parsedURL.Path), "/")

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, Compatibility{}, &Error{Stage: "pool creation", Cause: err}
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, Compatibility{}, &Error{Stage: "connectivity", Cause: err}
	}

	report, err := CheckCompatibility(ctx, pool, identity)
	if err != nil {
		pool.Close()
		return nil, Compatibility{}, err
	}

	return pool, report, nil
}

// CheckCompatibility executes the only SQL introduced by Step 3. It reads
// session and server facts; it performs no protected operation or mutation.
func CheckCompatibility(ctx context.Context, pool *pgxpool.Pool, identity ServiceIdentity) (Compatibility, error) {
	const query = `
SELECT
    current_user,
    current_database(),
    current_setting('server_version_num')::integer,
    current_setting('application_name'),
    current_setting('TimeZone'),
    current_setting('search_path'),
    current_setting('standard_conforming_strings')`

	var report Compatibility
	if err := pool.QueryRow(ctx, query).Scan(
		&report.CurrentUser,
		&report.CurrentDatabase,
		&report.ServerVersionNumber,
		&report.ApplicationName,
		&report.TimeZone,
		&report.SearchPath,
		&report.StandardConformingStrings,
	); err != nil {
		return Compatibility{}, &Error{Stage: "compatibility query", Cause: err}
	}

	if report.CurrentUser != identity.PostgreSQLRole {
		return Compatibility{}, &Error{Stage: "identity verification", Cause: fmt.Errorf("unexpected PostgreSQL role")}
	}
	if report.CurrentDatabase == "" {
		return Compatibility{}, &Error{Stage: "database verification", Cause: fmt.Errorf("database name is empty")}
	}
	if report.ServerVersionNumber < minimumPostgreSQLVersion || report.ServerVersionNumber >= maximumPostgreSQLVersion {
		return Compatibility{}, &Error{Stage: "server version verification", Cause: fmt.Errorf("PostgreSQL major version is outside 18")}
	}
	if report.ApplicationName != "issp/"+identity.ProcessName {
		return Compatibility{}, &Error{Stage: "application name verification", Cause: fmt.Errorf("application name mismatch")}
	}
	if report.TimeZone != "UTC" {
		return Compatibility{}, &Error{Stage: "timezone verification", Cause: fmt.Errorf("timezone is not UTC")}
	}
	if report.SearchPath != "pg_catalog" {
		return Compatibility{}, &Error{Stage: "search path verification", Cause: fmt.Errorf("search_path is not pg_catalog")}
	}
	if report.StandardConformingStrings != "on" {
		return Compatibility{}, &Error{Stage: "string semantics verification", Cause: fmt.Errorf("standard_conforming_strings is not on")}
	}

	return report, nil
}

func validateDatabaseURL(databaseURL string, allowInsecureLocal bool, identity ServiceIdentity) (*url.URL, error) {
	parsed, err := url.Parse(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("PostgreSQL URL cannot be parsed")
	}
	if parsed.Scheme != "postgresql" && parsed.Scheme != "postgres" {
		return nil, fmt.Errorf("scheme must be postgresql")
	}
	if parsed.User == nil || parsed.User.Username() != identity.PostgreSQLRole {
		return nil, fmt.Errorf("URL user must equal the compiled service role")
	}
	if parsed.Opaque != "" || parsed.Fragment != "" {
		return nil, fmt.Errorf("opaque URLs and fragments are not accepted in Step 3")
	}
	if strings.Contains(parsed.Host, ",") {
		return nil, fmt.Errorf("multi-host URLs are not accepted in Step 3")
	}
	host := parsed.Hostname()
	if host == "" {
		return nil, fmt.Errorf("host is required")
	}
	portText := parsed.Port()
	portNumber, portErr := strconv.ParseUint(portText, 10, 16)
	if portErr != nil || portNumber == 0 {
		return nil, fmt.Errorf("an explicit TCP port between 1 and 65535 is required")
	}
	if databaseName := strings.TrimPrefix(path.Clean(parsed.Path), "/"); databaseName == "" || databaseName == "." {
		return nil, fmt.Errorf("database name is required")
	}

	query := parsed.Query()
	for key, values := range query {
		if len(values) != 1 {
			return nil, fmt.Errorf("URL option %s must appear exactly once", key)
		}
		switch key {
		case "sslmode", "sslrootcert", "sslcert", "sslkey":
		default:
			return nil, fmt.Errorf("URL option %s is not accepted in Step 3", key)
		}
	}

	sslMode := query.Get("sslmode")
	ip := net.ParseIP(host)
	isLoopback := ip != nil && ip.IsLoopback()
	if allowInsecureLocal {
		if !isLoopback || sslMode != "disable" {
			return nil, fmt.Errorf("insecure mode requires a literal loopback host and sslmode=disable")
		}
	} else if sslMode != "verify-full" {
		return nil, fmt.Errorf("remote mode requires sslmode=verify-full")
	}

	return parsed, nil
}
