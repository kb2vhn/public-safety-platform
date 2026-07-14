package transport

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"sync/atomic"
	"time"
)

// State owns the process liveness and readiness state exposed by the local
// administrative listener.
type State struct {
	process string
	ready   atomic.Bool
}

// NewState creates a live but not-ready process state.
func NewState(process string) *State { return &State{process: process} }

// SetReady changes readiness without changing liveness.
func (s *State) SetReady(ready bool) { s.ready.Store(ready) }

// Ready reports the current readiness state.
func (s *State) Ready() bool { return s.ready.Load() }

// Handler returns the complete Step 3 administrative surface.
func (s *State) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.health)
	mux.HandleFunc("/readyz", s.readiness)
	return mux
}

func (s *State) health(w http.ResponseWriter, r *http.Request) {
	if !acceptedMethod(w, r) {
		return
	}
	writeStatus(w, http.StatusOK, map[string]any{
		"process": s.process,
		"status":  "live",
	})
}

func (s *State) readiness(w http.ResponseWriter, r *http.Request) {
	if !acceptedMethod(w, r) {
		return
	}
	statusCode := http.StatusServiceUnavailable
	status := "not_ready"
	if s.Ready() {
		statusCode = http.StatusOK
		status = "ready"
	}
	writeStatus(w, statusCode, map[string]any{
		"process": s.process,
		"status":  status,
	})
}

func acceptedMethod(w http.ResponseWriter, r *http.Request) bool {
	if r.Method == http.MethodGet || r.Method == http.MethodHead {
		return true
	}
	w.Header().Set("Allow", "GET, HEAD")
	writeStatus(w, http.StatusMethodNotAllowed, map[string]any{"status": "method_not_allowed"})
	return false
}

func writeStatus(w http.ResponseWriter, statusCode int, payload map[string]any) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(payload)
}

// Server is the bounded loopback-only administrative HTTP server.
type Server struct {
	listener net.Listener
	http     *http.Server
}

// Listen binds the already-validated loopback address and creates the server.
func Listen(address string, state *State) (*Server, error) {
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return nil, err
	}
	server := &http.Server{
		Handler:           state.Handler(),
		ReadHeaderTimeout: 2 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       30 * time.Second,
		MaxHeaderBytes:    8 * 1024,
	}
	return &Server{listener: listener, http: server}, nil
}

// Addr returns the effective local administrative address.
func (s *Server) Addr() string { return s.listener.Addr().String() }

// Serve blocks until shutdown or an unexpected listener failure.
func (s *Server) Serve() error {
	err := s.http.Serve(s.listener)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

// Shutdown stops accepting requests and waits for active handlers within the
// supplied context.
func (s *Server) Shutdown(ctx context.Context) error { return s.http.Shutdown(ctx) }
