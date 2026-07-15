package config

import (
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	EnvAdminListenAddress                   = "ISSP_ADMIN_LISTEN_ADDRESS"
	EnvBusinessListenAddress                = "ISSP_BUSINESS_LISTEN_ADDRESS"
	EnvTransportHMACKeyFile                 = "ISSP_TRANSPORT_HMAC_KEY_FILE"
	EnvTransportMaxConcurrentRequests       = "ISSP_TRANSPORT_MAX_CONCURRENT_REQUESTS"
	EnvDeliveryEndpoint                     = "ISSP_DELIVERY_ENDPOINT"
	EnvDeliveryTokenFile                    = "ISSP_DELIVERY_TOKEN_FILE"
	EnvDeliveryAllowInsecureLocal           = "ISSP_DELIVERY_ALLOW_INSECURE_LOCAL"
	EnvDeliveryBatchSize                    = "ISSP_DELIVERY_BATCH_SIZE"
	EnvDeliveryMaxConcurrent                = "ISSP_DELIVERY_MAX_CONCURRENT"
	EnvDeliveryClaimLease                   = "ISSP_DELIVERY_CLAIM_LEASE"
	EnvDeliveryPollInterval                 = "ISSP_DELIVERY_POLL_INTERVAL"
	EnvDeliveryRequestTimeout               = "ISSP_DELIVERY_REQUEST_TIMEOUT"
	EnvDeliveryRetryInitial                 = "ISSP_DELIVERY_RETRY_INITIAL"
	EnvDeliveryRetryMaximum                 = "ISSP_DELIVERY_RETRY_MAXIMUM"
	EnvDatabaseDSNFile                      = "ISSP_DATABASE_DSN_FILE"
	EnvDatabaseAllowInsecureLocal           = "ISSP_DATABASE_ALLOW_INSECURE_LOCAL"
	EnvDatabaseConnectTimeout               = "ISSP_DATABASE_CONNECT_TIMEOUT"
	EnvDatabaseMaxConnections               = "ISSP_DATABASE_MAX_CONNECTIONS"
	EnvDatabaseMinConnections               = "ISSP_DATABASE_MIN_CONNECTIONS"
	EnvDatabaseMaxConnectionLife            = "ISSP_DATABASE_MAX_CONNECTION_LIFETIME"
	EnvDatabaseMaxConnectionIdle            = "ISSP_DATABASE_MAX_CONNECTION_IDLE_TIME"
	EnvDatabaseHealthCheckPeriod            = "ISSP_DATABASE_HEALTH_CHECK_PERIOD"
	EnvStartupTimeout                       = "ISSP_STARTUP_TIMEOUT"
	EnvShutdownTimeout                      = "ISSP_SHUTDOWN_TIMEOUT"
	maximumSecretFileSize             int64 = 16 * 1024
)

// LookupEnv is compatible with os.LookupEnv and permits deterministic tests.
type LookupEnv func(string) (string, bool)

// Config is the complete Step 7 runtime configuration. It intentionally does
// not contain the PostgreSQL URL, password, decoded transport HMAC key, or
// decoded delivery token.
type Config struct {
	ProcessName        string
	AdminListenAddress string
	StartupTimeout     time.Duration
	ShutdownTimeout    time.Duration
	Database           Database
	Business           BusinessTransport
	Delivery           DeliveryWorker
}

// BusinessTransport contains the bounded Step 6 listener and authentication
// handoff configuration. It is enabled only for foundation-api.
type BusinessTransport struct {
	Enabled               bool
	ListenAddress         string
	HMACKeyFile           string
	MaxConcurrentRequests int32
}

// DeliveryWorker contains the bounded Step 7 outbound relay configuration.
// It is enabled only for the two delivery-worker processes. The endpoint is a
// deployment-owned relay; claimed database destination metadata is never used
// as a network address.
type DeliveryWorker struct {
	Enabled            bool
	Endpoint           string
	TokenFile          string
	AllowInsecureLocal bool
	BatchSize          int32
	MaxConcurrent      int32
	ClaimLease         time.Duration
	PollInterval       time.Duration
	RequestTimeout     time.Duration
	RetryInitial       time.Duration
	RetryMaximum       time.Duration
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

	business, err := loadBusinessTransport(processName, adminAddress, lookup)
	if err != nil {
		return Config{}, err
	}
	delivery, err := loadDeliveryWorker(processName, lookup)
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
		Business: business,
		Delivery: delivery,
	}, nil
}

// SafeFields returns only non-secret values suitable for structured logs.
func (c Config) SafeFields() map[string]any {
	return map[string]any{
		"process":                            c.ProcessName,
		"admin_listen_address":               c.AdminListenAddress,
		"startup_timeout":                    c.StartupTimeout.String(),
		"shutdown_timeout":                   c.ShutdownTimeout.String(),
		"database_dsn_file_configured":       c.Database.DSNFile != "",
		"database_allow_insecure_local":      c.Database.AllowInsecureLocal,
		"database_connect_timeout":           c.Database.ConnectTimeout.String(),
		"database_max_connections":           c.Database.MaxConnections,
		"database_min_connections":           c.Database.MinConnections,
		"business_transport_enabled":         c.Business.Enabled,
		"business_listen_address":            c.Business.ListenAddress,
		"transport_hmac_key_file_configured": c.Business.HMACKeyFile != "",
		"transport_max_concurrent_requests":  c.Business.MaxConcurrentRequests,
		"delivery_worker_enabled":            c.Delivery.Enabled,
		"delivery_endpoint_configured":       c.Delivery.Endpoint != "",
		"delivery_token_file_configured":     c.Delivery.TokenFile != "",
		"delivery_allow_insecure_local":      c.Delivery.AllowInsecureLocal,
		"delivery_batch_size":                c.Delivery.BatchSize,
		"delivery_max_concurrent":            c.Delivery.MaxConcurrent,
		"delivery_claim_lease":               c.Delivery.ClaimLease.String(),
		"delivery_poll_interval":             c.Delivery.PollInterval.String(),
		"delivery_request_timeout":           c.Delivery.RequestTimeout.String(),
		"delivery_retry_initial":             c.Delivery.RetryInitial.String(),
		"delivery_retry_maximum":             c.Delivery.RetryMaximum.String(),
	}
}

func (c Config) String() string { return "[REDACTED CONFIGURATION]" }

// ReadDatabaseURL reads one PostgreSQL URL from the protected file named by the
// typed configuration. It rejects symlinks and any group or other permissions.
func ReadDatabaseURL(path string) (string, error) {
	return readProtectedSingleLine(path, EnvDatabaseDSNFile)
}

// ReadTransportHMACKey reads and decodes one base64url service-specific HMAC
// key. The encoded or decoded key is never retained in Config or SafeFields.
func ReadTransportHMACKey(path string) ([]byte, error) {
	encoded, err := readProtectedSingleLine(path, EnvTransportHMACKeyFile)
	if err != nil {
		return nil, err
	}
	decoded, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil || len(decoded) < 32 || len(decoded) > 64 ||
		base64.RawURLEncoding.EncodeToString(decoded) != encoded {
		return nil, &Error{Field: EnvTransportHMACKeyFile, Reason: "must contain canonical base64url for 32 to 64 bytes"}
	}
	return decoded, nil
}

// ReadDeliveryToken reads one canonical base64url relay credential. The token
// remains outside Config and is never returned by SafeFields.
func ReadDeliveryToken(path string) ([]byte, error) {
	encoded, err := readProtectedSingleLine(path, EnvDeliveryTokenFile)
	if err != nil {
		return nil, err
	}
	decoded, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil || len(decoded) < 32 || len(decoded) > 64 ||
		base64.RawURLEncoding.EncodeToString(decoded) != encoded {
		return nil, &Error{Field: EnvDeliveryTokenFile, Reason: "must contain canonical base64url for 32 to 64 bytes"}
	}
	return decoded, nil
}

func readProtectedSingleLine(path, field string) (string, error) {
	pathInfo, err := os.Lstat(path)
	if err != nil {
		return "", &Error{Field: field, Reason: "cannot stat configured file"}
	}
	if pathInfo.Mode()&os.ModeSymlink != 0 {
		return "", &Error{Field: field, Reason: "symlinks are prohibited"}
	}
	if !pathInfo.Mode().IsRegular() {
		return "", &Error{Field: field, Reason: "must name a regular file"}
	}
	if pathInfo.Mode().Perm()&0o077 != 0 {
		return "", &Error{Field: field, Reason: "group and other permission bits must be zero"}
	}
	if pathInfo.Size() <= 0 || pathInfo.Size() > maximumSecretFileSize {
		return "", &Error{Field: field, Reason: "file size is outside the accepted boundary"}
	}

	file, err := os.Open(path)
	if err != nil {
		return "", &Error{Field: field, Reason: "cannot open configured file"}
	}
	defer file.Close()

	openedInfo, err := file.Stat()
	if err != nil || !openedInfo.Mode().IsRegular() || !os.SameFile(pathInfo, openedInfo) {
		return "", &Error{Field: field, Reason: "configured file changed during validation"}
	}

	content, err := io.ReadAll(io.LimitReader(file, maximumSecretFileSize+1))
	if err != nil {
		return "", &Error{Field: field, Reason: "cannot read configured file"}
	}
	if len(content) == 0 || int64(len(content)) > maximumSecretFileSize {
		return "", &Error{Field: field, Reason: "file size is outside the accepted boundary"}
	}
	value := strings.TrimSpace(string(content))
	if value == "" {
		return "", &Error{Field: field, Reason: "file is empty"}
	}
	if strings.ContainsAny(value, "\r\n\x00") {
		return "", &Error{Field: field, Reason: "file must contain exactly one text line"}
	}
	return value, nil
}

func loadBusinessTransport(processName, adminAddress string, lookup LookupEnv) (BusinessTransport, error) {
	criticalNames := []string{
		EnvBusinessListenAddress,
		EnvTransportHMACKeyFile,
		EnvTransportMaxConcurrentRequests,
	}
	if processName != "foundation-api" {
		for _, name := range criticalNames {
			if value, ok := lookup(name); ok && strings.TrimSpace(value) != "" {
				return BusinessTransport{}, &Error{Field: name, Reason: "is accepted only for foundation-api"}
			}
		}
		return BusinessTransport{}, nil
	}

	listenAddress, err := required(lookup, EnvBusinessListenAddress)
	if err != nil {
		return BusinessTransport{}, err
	}
	if err := validateLoopbackAddress(listenAddress); err != nil {
		return BusinessTransport{}, &Error{Field: EnvBusinessListenAddress, Reason: err.Error()}
	}
	if listenAddress == adminAddress {
		return BusinessTransport{}, &Error{Field: EnvBusinessListenAddress, Reason: "must differ from the administrative listener"}
	}

	keyFile, err := required(lookup, EnvTransportHMACKeyFile)
	if err != nil {
		return BusinessTransport{}, err
	}
	if !filepath.IsAbs(keyFile) {
		return BusinessTransport{}, &Error{Field: EnvTransportHMACKeyFile, Reason: "path must be absolute"}
	}

	maximumConcurrent, err := optionalInt32(lookup, EnvTransportMaxConcurrentRequests, 8, 1, 32)
	if err != nil {
		return BusinessTransport{}, err
	}
	return BusinessTransport{
		Enabled:               true,
		ListenAddress:         listenAddress,
		HMACKeyFile:           keyFile,
		MaxConcurrentRequests: maximumConcurrent,
	}, nil
}

func loadDeliveryWorker(processName string, lookup LookupEnv) (DeliveryWorker, error) {
	criticalNames := []string{
		EnvDeliveryEndpoint,
		EnvDeliveryTokenFile,
		EnvDeliveryAllowInsecureLocal,
		EnvDeliveryBatchSize,
		EnvDeliveryMaxConcurrent,
		EnvDeliveryClaimLease,
		EnvDeliveryPollInterval,
		EnvDeliveryRequestTimeout,
		EnvDeliveryRetryInitial,
		EnvDeliveryRetryMaximum,
	}
	isWorker := processName == "integration-delivery-worker" || processName == "monitoring-delivery-worker"
	if !isWorker {
		for _, name := range criticalNames {
			if value, ok := lookup(name); ok && strings.TrimSpace(value) != "" {
				return DeliveryWorker{}, &Error{Field: name, Reason: "is accepted only for delivery workers"}
			}
		}
		return DeliveryWorker{}, nil
	}

	endpoint, err := required(lookup, EnvDeliveryEndpoint)
	if err != nil {
		return DeliveryWorker{}, err
	}
	allowInsecure, err := optionalBool(lookup, EnvDeliveryAllowInsecureLocal, false)
	if err != nil {
		return DeliveryWorker{}, err
	}
	if err := validateDeliveryEndpoint(endpoint, allowInsecure); err != nil {
		return DeliveryWorker{}, &Error{Field: EnvDeliveryEndpoint, Reason: err.Error()}
	}
	tokenFile, err := required(lookup, EnvDeliveryTokenFile)
	if err != nil {
		return DeliveryWorker{}, err
	}
	if !filepath.IsAbs(tokenFile) {
		return DeliveryWorker{}, &Error{Field: EnvDeliveryTokenFile, Reason: "path must be absolute"}
	}
	batchSize, err := optionalInt32(lookup, EnvDeliveryBatchSize, 8, 1, 32)
	if err != nil {
		return DeliveryWorker{}, err
	}
	maximumConcurrent, err := optionalInt32(lookup, EnvDeliveryMaxConcurrent, 4, 1, 16)
	if err != nil {
		return DeliveryWorker{}, err
	}
	if maximumConcurrent > batchSize {
		return DeliveryWorker{}, &Error{Field: EnvDeliveryMaxConcurrent, Reason: "must not exceed delivery batch size"}
	}
	claimLease, err := optionalDuration(lookup, EnvDeliveryClaimLease, 30*time.Second, 10*time.Second, 5*time.Minute)
	if err != nil {
		return DeliveryWorker{}, err
	}
	pollInterval, err := optionalDuration(lookup, EnvDeliveryPollInterval, time.Second, 100*time.Millisecond, 30*time.Second)
	if err != nil {
		return DeliveryWorker{}, err
	}
	requestTimeout, err := optionalDuration(lookup, EnvDeliveryRequestTimeout, 5*time.Second, time.Second, 30*time.Second)
	if err != nil {
		return DeliveryWorker{}, err
	}
	if claimLease <= requestTimeout {
		return DeliveryWorker{}, &Error{Field: EnvDeliveryClaimLease, Reason: "must exceed the delivery request timeout"}
	}
	retryInitial, err := optionalDuration(lookup, EnvDeliveryRetryInitial, 5*time.Second, time.Second, 5*time.Minute)
	if err != nil {
		return DeliveryWorker{}, err
	}
	retryMaximum, err := optionalDuration(lookup, EnvDeliveryRetryMaximum, 5*time.Minute, retryInitial, 24*time.Hour)
	if err != nil {
		return DeliveryWorker{}, err
	}

	return DeliveryWorker{
		Enabled:            true,
		Endpoint:           endpoint,
		TokenFile:          tokenFile,
		AllowInsecureLocal: allowInsecure,
		BatchSize:          batchSize,
		MaxConcurrent:      maximumConcurrent,
		ClaimLease:         claimLease,
		PollInterval:       pollInterval,
		RequestTimeout:     requestTimeout,
		RetryInitial:       retryInitial,
		RetryMaximum:       retryMaximum,
	}, nil
}

func validateDeliveryEndpoint(value string, allowInsecureLocal bool) error {
	parsed, err := url.Parse(value)
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return fmt.Errorf("must be an absolute HTTP endpoint")
	}
	if parsed.User != nil || parsed.Fragment != "" || parsed.RawQuery != "" || parsed.RawPath != "" {
		return fmt.Errorf("userinfo, fragments, query strings, and raw paths are prohibited")
	}
	if parsed.Path == "" || parsed.Path == "/" {
		return fmt.Errorf("a fixed non-root path is required")
	}
	if allowInsecureLocal {
		ip := net.ParseIP(parsed.Hostname())
		if parsed.Scheme != "http" || ip == nil || !ip.IsLoopback() {
			return fmt.Errorf("insecure delivery requires HTTP and a literal loopback host")
		}
		return nil
	}
	if parsed.Scheme != "https" {
		return fmt.Errorf("remote delivery requires HTTPS")
	}
	return nil
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
