// Package workers implements the two accepted Phase 6 Step 7 delivery loops.
// It contains no generic job framework and no direct SQL authority.
package workers

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

const (
	deliveryEnvelopeVersion  = "ISSP-DELIVERY-V1"
	maximumEnvelopeBytes     = 256 * 1024
	maximumResponseDrain     = 4 * 1024
	databaseOperationTimeout = 3 * time.Second
)

type deliveryKind string

const (
	integrationKind deliveryKind = "integration_outbox"
	monitoringKind  deliveryKind = "monitoring_delivery"
)

// Runner is the bounded lifecycle contract consumed by bootstrap.
type Runner interface {
	Run(context.Context) error
	Close()
}

// Error is a redacted worker error.
type Error struct {
	Stage string
	Code  string
	Cause error
}

func (e *Error) Error() string {
	stage := strings.TrimSpace(e.Stage)
	if stage == "" {
		stage = "delivery"
	}
	return "worker " + stage + " failed"
}
func (e *Error) Unwrap() error       { return e.Cause }
func (e *Error) SafeMessage() string { return e.Error() }

// Diagnostic returns a bounded classification suitable for logs and stored
// retry state. It never returns endpoint, token, payload, response, or IDs.
func Diagnostic(err error) string {
	if err == nil {
		return "delivery_no_error"
	}
	if errors.Is(err, context.Canceled) {
		return "delivery_context_canceled"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "delivery_timeout"
	}
	var workerError *Error
	if errors.As(err, &workerError) && workerError.Code != "" {
		return workerError.Code
	}
	databaseDiagnostic := database.Diagnostic(err)
	if databaseDiagnostic != "database_operation_failed" {
		return databaseDiagnostic
	}
	return "delivery_operation_failed"
}

type relayEnvelope struct {
	Version        string          `json:"version"`
	Kind           deliveryKind    `json:"kind"`
	DeliveryID     string          `json:"delivery_id"`
	AttemptNumber  int32           `json:"attempt_number"`
	ClaimExpiresAt time.Time       `json:"claim_expires_at"`
	Metadata       json.RawMessage `json:"metadata"`
	Payload        json.RawMessage `json:"payload"`
}

type relayClient interface {
	Deliver(context.Context, relayEnvelope) error
}

type httpRelayClient struct {
	endpoint       string
	token          []byte
	requestTimeout time.Duration
	client         *http.Client
	closeOnce      sync.Once
}

func newHTTPRelayClient(identity database.ServiceIdentity, cfg config.DeliveryWorker, token []byte) (*httpRelayClient, error) {
	if identity != database.IntegrationDeliveryWorker && identity != database.MonitoringDeliveryWorker {
		return nil, &Error{Stage: "relay construction", Code: "delivery_identity_rejected", Cause: errors.New("unsupported identity")}
	}
	if !cfg.Enabled || strings.TrimSpace(cfg.Endpoint) == "" || cfg.RequestTimeout < time.Second || cfg.RequestTimeout > 30*time.Second {
		return nil, &Error{Stage: "relay construction", Code: "delivery_configuration_rejected", Cause: errors.New("invalid relay configuration")}
	}
	if len(token) < 32 || len(token) > 64 {
		return nil, &Error{Stage: "relay construction", Code: "delivery_credential_rejected", Cause: errors.New("invalid relay credential")}
	}

	transport := &http.Transport{
		Proxy:                 nil,
		DialContext:           (&net.Dialer{Timeout: 3 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          int(cfg.MaxConcurrent),
		MaxIdleConnsPerHost:   int(cfg.MaxConcurrent),
		IdleConnTimeout:       30 * time.Second,
		TLSHandshakeTimeout:   5 * time.Second,
		ResponseHeaderTimeout: cfg.RequestTimeout,
		ExpectContinueTimeout: time.Second,
		DisableCompression:    true,
		TLSClientConfig:       &tls.Config{MinVersion: tls.VersionTLS12},
	}
	return &httpRelayClient{
		endpoint:       cfg.Endpoint,
		token:          append([]byte(nil), token...),
		requestTimeout: cfg.RequestTimeout,
		client: &http.Client{
			Transport: transport,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return errors.New("redirects are prohibited")
			},
		},
	}, nil
}

// Close releases idle relay connections and zeroes the retained credential.
// It is called only after the worker loop has drained, so it does not race with
// an active request.
func (c *httpRelayClient) Close() {
	if c == nil {
		return
	}
	c.closeOnce.Do(func() {
		if c.client != nil {
			c.client.CloseIdleConnections()
		}
		for index := range c.token {
			c.token[index] = 0
		}
		c.token = nil
	})
}

func (c *httpRelayClient) Deliver(ctx context.Context, envelope relayEnvelope) error {
	if c == nil || c.client == nil || ctx == nil {
		return &Error{Stage: "relay request", Code: "delivery_client_unavailable", Cause: errors.New("relay client unavailable")}
	}
	body, err := json.Marshal(envelope)
	if err != nil || len(body) == 0 || len(body) > maximumEnvelopeBytes {
		return &Error{Stage: "relay encoding", Code: "delivery_payload_rejected", Cause: err}
	}

	requestContext, cancel := context.WithTimeout(ctx, c.requestTimeout)
	defer cancel()
	request, err := http.NewRequestWithContext(requestContext, http.MethodPost, c.endpoint, bytes.NewReader(body))
	if err != nil {
		return &Error{Stage: "relay request", Code: "delivery_request_rejected", Cause: err}
	}
	request.Header.Set("Authorization", "Bearer "+base64.RawURLEncoding.EncodeToString(c.token))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	request.Header.Set("User-Agent", "iron-signal-platform/phase6-step7")
	request.Header.Set("Idempotency-Key", envelope.DeliveryID)
	request.Header.Set("X-ISSP-Delivery-Kind", string(envelope.Kind))
	request.Header.Set("X-ISSP-Delivery-Attempt", strconv.FormatInt(int64(envelope.AttemptNumber), 10))

	response, err := c.client.Do(request)
	if err != nil {
		if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
			return &Error{Stage: "relay request", Code: "delivery_timeout", Cause: err}
		}
		return &Error{Stage: "relay request", Code: "delivery_network_error", Cause: err}
	}
	defer response.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, maximumResponseDrain))

	if response.StatusCode >= 200 && response.StatusCode <= 299 {
		return nil
	}
	if response.StatusCode == http.StatusRequestTimeout ||
		response.StatusCode == http.StatusTooEarly ||
		response.StatusCode == http.StatusTooManyRequests ||
		response.StatusCode >= 500 {
		return &Error{Stage: "relay response", Code: "delivery_relay_unavailable", Cause: errors.New("transient relay response")}
	}
	return &Error{Stage: "relay response", Code: "delivery_relay_rejected", Cause: errors.New("permanent relay response")}
}

func retryDelay(initial, maximum time.Duration, attempt int32) time.Duration {
	if initial <= 0 || maximum < initial {
		return maximum
	}
	if attempt < 1 {
		attempt = 1
	}
	delay := initial
	for index := int32(1); index < attempt && delay < maximum; index++ {
		if delay > maximum/2 {
			return maximum
		}
		delay *= 2
	}
	if delay > maximum {
		return maximum
	}
	return delay
}

func compactMetadata(value any) (json.RawMessage, error) {
	encoded, err := json.Marshal(value)
	if err != nil || len(encoded) == 0 || len(encoded) > 32*1024 {
		return nil, &Error{Stage: "metadata encoding", Code: "delivery_metadata_rejected", Cause: err}
	}
	return encoded, nil
}
