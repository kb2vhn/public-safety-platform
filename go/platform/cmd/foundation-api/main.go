package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/bootstrap"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	os.Exit(bootstrap.Run(ctx, os.Stderr, database.FoundationAPI))
}
