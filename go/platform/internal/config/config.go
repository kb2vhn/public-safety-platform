package config

import (
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
	EnvAdminListenAddress               = "ISSP_ADMIN_LISTEN_ADDRESS"
	EnvDatabaseDSNFile                  = "ISSP_DATABASE_DSN_FILE"
	EnvDatabaseAllowInsecureLocal       = "ISSP_DATABASE_ALLOW_INSECURE_LOCAL"
	EnvDatabaseConnectTimeout           = "ISSP_DATABASE_CONNECT_TIMEOUT"
	EnvDatabaseMaxConnections           = "ISSP_DATABASE_MAX_CONNECTIONS"
	EnvDatabaseMinConnections           = "ISSP_DATABASE_MIN_CONNECTIONS"
	EnvDatabaseMaxConnectionLife        = "ISSP_DATABASE_MAX_CONNECTION_LIFETIME"
	EnvDatabaseMaxConnectionIdle        = "ISSP_DATABASE_MAX_CONNECTION_IDLE_TIME"
	EnvDatabaseHealthCheckPeriod        = "ISSP_DATABASE_HEALTH_CHECK_PERIOD"
	EnvStartupTimeout                   = "ISSP_STARTUP_TIMEOUT"
	EnvShutdownTimeout                  = "ISSP_SHUTDOWN_TIMEOUT"
	maximumSecretFileSize         int64 = 16 * 1024
)

// LookupEnv is compatible with os.LookupEnv and permits deterministic tests.
type LookupEnv func(string) (string, bool)

// Config is the complete Step 3 runtime configuration. It intentionally does
// not contain the PostgreSQL URL or password.
type Config struct {
	ProcessName        string
	AdminListenAddress string
	StartupTimeout     time.Duration
	ShutdownTimeout    time.Duration
	Database           Database
}

// Database contains only non-secret database settings and the path from which
// the PostgreSQL URL is read.
type Database struct {
	DSNFile               string
	AllowInsecureLocal    bool
	ConnectTimeout        time.Duration
	MaxConnections        int32
	MinConnections        int32
	MaxConnectionLifetime time.Duration
	MaxConnectionIdleTime time.Duration
	HealthCheckPeriod     time.Duration
}

// Error is safe to place in a structured log. It identifies the invalid field
// without echoing the supplied value.
type Error struct {
	Field  string
	Reason string
}

func (e *Error) Error() string {
	return fmt.Sprintf("configuration field %s is invalid: %s", e.Field, e.Reason)
}

// SafeMessage marks Error as already redacted for observability.SafeError.
func (e *Error) SafeMessage() string { return e.Error() }

// Load reads and validates typed configuration. Missing optional values receive
// conservative bounded defaults.
func Load(processName string, lookup LookupEnv) (Config, error) {
	if lookup == nil {
		lookup = os.LookupEnv
	}

	adminAddress, err := required(lookup, EnvAdminListenAddress)
	if err != nil {
		return Config{}, err
	}
	if err := validateLoopbackAddress(adminAddress); err != nil {
		return Config{}, &Error{Field: EnvAdminListenAddress, Reason: err.Error()}
	}

	dsnFile, err := required(lookup, EnvDatabaseDSNFile)
	if err != nil {
		return Config{}, err
	}
	if !filepath.IsAbs(dsnFile) {
		return Config{}, &Error{Field: EnvDatabaseDSNFile, Reason: "path must be absolute"}
	}

	allowInsecureLocal, err := optionalBool(lookup, EnvDatabaseAllowInsecureLocal, false)
	if err != nil {
		return Config{}, err
	}
	connectTimeout, err := optionalDuration(lookup, EnvDatabaseConnectTimeout, 5*time.Second, time.Second, 30*time.Second)
	if err != nil {
		return Config{}, err
	}
	maxConnections, err := optionalInt32(lookup, EnvDatabaseMaxConnections, 4, 1, 16)
	if err != nil {
		return Config{}, err
	}
	minConnections, err := optionalInt32(lookup, EnvDatabaseMinConnections, 0, 0, 4)
	if err != nil {
		return Config{}, err
	}
	if minConnections > maxConnections {
		return Config{}, &Error{Field: EnvDatabaseMinConnections, Reason: "must not exceed maximum connections"}
	}
	maxLifetime, err := optionalDuration(lookup, EnvDatabaseMaxConnectionLife, 30*time.Minute, time.Minute, 24*time.Hour)
	if err != nil {
		return Config{}, err
	}
	maxIdle, err := optionalDuration(lookup, EnvDatabaseMaxConnectionIdle, 5*time.Minute, 30*time.Second, time.Hour)
	if err != nil {
		return Config{}, err
	}
	healthPeriod, err := optionalDuration(lookup, EnvDatabaseHealthCheckPeriod, 30*time.Second, 5*time.Second, 5*time.Minute)
	if err != nil {
		return Config{}, err
	}
	startupTimeout, err := optionalDuration(lookup, EnvStartupTimeout, 15*time.Second, time.Second, time.Minute)
	if err != nil {
		return Config{}, err
	}
	shutdownTimeout, err := optionalDuration(lookup, EnvShutdownTimeout, 10*time.Second, time.Second, time.Minute)
	if err != nil {
		return Config{}, err
	}

	return Config{
		ProcessName:        processName,
		AdminListenAddress: adminAddress,
		StartupTimeout:     startupTimeout,
		ShutdownTimeout:    shutdownTimeout,
		Database: Database{
			DSNFile:               dsnFile,
			AllowInsecureLocal:    allowInsecureLocal,
			ConnectTimeout:        connectTimeout,
			MaxConnections:        maxConnections,
			MinConnections:        minConnections,
			MaxConnectionLifetime: maxLifetime,
			MaxConnectionIdleTime: maxIdle,
			HealthCheckPeriod:     healthPeriod,
		},
	}, nil
}

// SafeFields returns only non-secret values suitable for structured logs.
func (c Config) SafeFields() map[string]any {
	return map[string]any{
		"process":                       c.ProcessName,
		"admin_listen_address":          c.AdminListenAddress,
		"startup_timeout":               c.StartupTimeout.String(),
		"shutdown_timeout":              c.ShutdownTimeout.String(),
		"database_dsn_file_configured":  c.Database.DSNFile != "",
		"database_allow_insecure_local": c.Database.AllowInsecureLocal,
		"database_connect_timeout":      c.Database.ConnectTimeout.String(),
		"database_max_connections":      c.Database.MaxConnections,
		"database_min_connections":      c.Database.MinConnections,
	}
}

func (c Config) String() string { return "[REDACTED CONFIGURATION]" }

// ReadDatabaseURL reads one PostgreSQL URL from the protected file named by the
// typed configuration. It rejects symlinks and any group or other permissions.
func ReadDatabaseURL(path string) (string, error) {
	pathInfo, err := os.Lstat(path)
	if err != nil {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "cannot stat configured file"}
	}
	if pathInfo.Mode()&os.ModeSymlink != 0 {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "symlinks are prohibited"}
	}
	if !pathInfo.Mode().IsRegular() {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "must name a regular file"}
	}
	if pathInfo.Mode().Perm()&0o077 != 0 {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "group and other permission bits must be zero"}
	}
	if pathInfo.Size() <= 0 || pathInfo.Size() > maximumSecretFileSize {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "file size is outside the accepted boundary"}
	}

	file, err := os.Open(path)
	if err != nil {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "cannot open configured file"}
	}
	defer file.Close()

	openedInfo, err := file.Stat()
	if err != nil || !openedInfo.Mode().IsRegular() || !os.SameFile(pathInfo, openedInfo) {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "configured file changed during validation"}
	}

	content, err := io.ReadAll(io.LimitReader(file, maximumSecretFileSize+1))
	if err != nil {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "cannot read configured file"}
	}
	if len(content) == 0 || int64(len(content)) > maximumSecretFileSize {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "file size is outside the accepted boundary"}
	}
	value := strings.TrimSpace(string(content))
	if value == "" {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "file is empty"}
	}
	if strings.ContainsAny(value, "\r\n\x00") {
		return "", &Error{Field: EnvDatabaseDSNFile, Reason: "file must contain exactly one text line"}
	}

	return value, nil
}

func required(lookup LookupEnv, name string) (string, error) {
	value, ok := lookup(name)
	if !ok || strings.TrimSpace(value) == "" {
		return "", &Error{Field: name, Reason: "required value is missing"}
	}
	return strings.TrimSpace(value), nil
}

func optionalBool(lookup LookupEnv, name string, fallback bool) (bool, error) {
	value, ok := lookup(name)
	if !ok || strings.TrimSpace(value) == "" {
		return fallback, nil
	}
	parsed, err := strconv.ParseBool(strings.TrimSpace(value))
	if err != nil {
		return false, &Error{Field: name, Reason: "must be a boolean"}
	}
	return parsed, nil
}

func optionalDuration(lookup LookupEnv, name string, fallback, minimum, maximum time.Duration) (time.Duration, error) {
	value, ok := lookup(name)
	if !ok || strings.TrimSpace(value) == "" {
		return fallback, nil
	}
	parsed, err := time.ParseDuration(strings.TrimSpace(value))
	if err != nil || parsed < minimum || parsed > maximum {
		return 0, &Error{Field: name, Reason: fmt.Sprintf("must be between %s and %s", minimum, maximum)}
	}
	return parsed, nil
}

func optionalInt32(lookup LookupEnv, name string, fallback, minimum, maximum int32) (int32, error) {
	value, ok := lookup(name)
	if !ok || strings.TrimSpace(value) == "" {
		return fallback, nil
	}
	parsed, err := strconv.ParseInt(strings.TrimSpace(value), 10, 32)
	if err != nil || parsed < int64(minimum) || parsed > int64(maximum) {
		return 0, &Error{Field: name, Reason: fmt.Sprintf("must be between %d and %d", minimum, maximum)}
	}
	return int32(parsed), nil
}

func validateLoopbackAddress(address string) error {
	host, portText, err := net.SplitHostPort(address)
	if err != nil {
		return fmt.Errorf("must be a host:port address")
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("host must be a literal loopback address")
	}
	port, err := strconv.Atoi(portText)
	if err != nil || port < 1 || port > 65535 {
		return fmt.Errorf("port must be between 1 and 65535")
	}
	return nil
}
