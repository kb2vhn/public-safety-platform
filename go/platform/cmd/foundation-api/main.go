package main

import (
	"os"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/bootstrap"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func main() {
	os.Exit(bootstrap.Run(os.Stderr, database.FoundationAPI))
}
