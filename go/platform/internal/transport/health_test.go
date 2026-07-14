package transport

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthAndReadinessTransitions(t *testing.T) {
	t.Parallel()

	state := NewState("foundation-api")
	handler := state.Handler()

	health := httptest.NewRecorder()
	handler.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if health.Code != http.StatusOK || !strings.Contains(health.Body.String(), `"status":"live"`) {
		t.Fatalf("health response = %d %q", health.Code, health.Body.String())
	}

	notReady := httptest.NewRecorder()
	handler.ServeHTTP(notReady, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if notReady.Code != http.StatusServiceUnavailable {
		t.Fatalf("not-ready response = %d", notReady.Code)
	}

	state.SetReady(true)
	ready := httptest.NewRecorder()
	handler.ServeHTTP(ready, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if ready.Code != http.StatusOK || !strings.Contains(ready.Body.String(), `"status":"ready"`) {
		t.Fatalf("ready response = %d %q", ready.Code, ready.Body.String())
	}
}

func TestAdministrativeSurfaceRejectsOtherMethodsAndPaths(t *testing.T) {
	t.Parallel()

	state := NewState("foundation-api")
	method := httptest.NewRecorder()
	state.Handler().ServeHTTP(method, httptest.NewRequest(http.MethodPost, "/healthz", nil))
	if method.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST /healthz = %d", method.Code)
	}

	missing := httptest.NewRecorder()
	state.Handler().ServeHTTP(missing, httptest.NewRequest(http.MethodGet, "/business", nil))
	if missing.Code != http.StatusNotFound {
		t.Fatalf("GET /business = %d", missing.Code)
	}
}
