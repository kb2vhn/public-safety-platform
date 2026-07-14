package transport

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"testing"
	"time"
)

func TestAdministrativeShutdownIsBoundedWithInflightRequest(t *testing.T) {
	t.Parallel()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}

	entered := make(chan struct{})
	release := make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(entered)
		<-release
		w.WriteHeader(http.StatusOK)
	})

	server := &Server{
		listener: listener,
		http: &http.Server{
			Handler:           handler,
			ReadHeaderTimeout: time.Second,
		},
	}

	serveResult := make(chan error, 1)
	go func() {
		serveResult <- server.Serve()
	}()

	requestResult := make(chan error, 1)
	go func() {
		response, requestErr := http.Get(
			"http://" + listener.Addr().String(),
		)
		if requestErr == nil {
			_, _ = io.Copy(io.Discard, response.Body)
			requestErr = response.Body.Close()
		}
		requestResult <- requestErr
	}()

	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("administrative request did not enter handler")
	}

	shutdownContext, cancel := context.WithTimeout(
		context.Background(),
		50*time.Millisecond,
	)
	defer cancel()

	err = server.Shutdown(shutdownContext)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf(
			"Shutdown() error = %v, want context deadline exceeded",
			err,
		)
	}

	close(release)

	select {
	case requestErr := <-requestResult:
		if requestErr != nil {
			t.Fatalf("administrative request error = %v", requestErr)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("administrative request did not drain after release")
	}

	select {
	case serveErr := <-serveResult:
		if serveErr != nil {
			t.Fatalf("Serve() error after bounded shutdown = %v", serveErr)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Serve() did not stop after bounded shutdown")
	}
}

func TestServeReportsUnexpectedListenerClosure(t *testing.T) {
	t.Parallel()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}

	server := &Server{
		listener: listener,
		http: &http.Server{
			Handler:           http.NewServeMux(),
			ReadHeaderTimeout: time.Second,
		},
	}

	serveResult := make(chan error, 1)
	go func() {
		serveResult <- server.Serve()
	}()

	if err := listener.Close(); err != nil {
		t.Fatalf("listener.Close() error = %v", err)
	}

	select {
	case serveErr := <-serveResult:
		if serveErr == nil {
			t.Fatal("Serve() accepted unexpected listener closure")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Serve() did not report unexpected listener closure")
	}
}
