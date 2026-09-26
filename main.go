package main

import (
	"fmt"
	"os"

	"github.com/icichainz/path_vador/internal/cli"
	"github.com/icichainz/path_vador/internal/tui"
)

func main() {
	if len(os.Args) == 1 {
		if err := tui.Run(); err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "path_vador: %v\n", err)
			os.Exit(1)
		}
		return
	}

	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr))
}
