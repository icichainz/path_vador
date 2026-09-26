package cli

import (
	"fmt"
	"io"
	"os"
	"runtime"

	"github.com/icichainz/path_vador/pkg/pathvador"
)

const usageText = `path_vador normalizes file paths and prints shell commands for temporary environment variables.

Usage:
  path_vador help
  path_vador join <part> [<part>...]
  path_vador clean <path>
  path_vador abs <path>
  path_vador base <path>
  path_vador dir <path>
  path_vador env export [--shell auto|sh|powershell|cmd] <NAME> <VALUE>
  path_vador env unset [--shell auto|sh|powershell|cmd] <NAME>
`

var getenv = os.Getenv

// Run executes the CLI and returns a process exit code.
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		printUsage(stdout)
		return 0
	}

	switch args[0] {
	case "help", "-h", "--help":
		printUsage(stdout)
		return 0
	case "join":
		if len(args) < 2 {
			return writeError(stderr, "join requires at least one path fragment")
		}
		_, _ = fmt.Fprintln(stdout, pathvador.Join(args[1:]...))
		return 0
	case "clean":
		if len(args) != 2 {
			return writeError(stderr, "clean requires exactly one path")
		}
		_, _ = fmt.Fprintln(stdout, pathvador.Clean(args[1]))
		return 0
	case "abs":
		if len(args) != 2 {
			return writeError(stderr, "abs requires exactly one path")
		}
		absolutePath, err := pathvador.Abs(args[1])
		if err != nil {
			return writeError(stderr, err.Error())
		}
		_, _ = fmt.Fprintln(stdout, absolutePath)
		return 0
	case "base":
		if len(args) != 2 {
			return writeError(stderr, "base requires exactly one path")
		}
		_, _ = fmt.Fprintln(stdout, pathvador.Base(args[1]))
		return 0
	case "dir":
		if len(args) != 2 {
			return writeError(stderr, "dir requires exactly one path")
		}
		_, _ = fmt.Fprintln(stdout, pathvador.Dir(args[1]))
		return 0
	case "env":
		return runEnv(args[1:], stdout, stderr)
	default:
		return writeError(stderr, fmt.Sprintf("unknown command %q", args[0]))
	}
}

func runEnv(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return writeError(stderr, "env requires a subcommand: export or unset")
	}

	switch args[0] {
	case "export":
		shellName, remaining, err := parseShellArg(args[1:])
		if err != nil {
			return writeError(stderr, err.Error())
		}
		if len(remaining) != 2 {
			return writeError(stderr, "env export requires a variable name and value")
		}

		shell, err := pathvador.ResolveShell(shellName, runtime.GOOS, getenv)
		if err != nil {
			return writeError(stderr, err.Error())
		}

		command, err := pathvador.ExportCommand(shell, remaining[0], remaining[1])
		if err != nil {
			return writeError(stderr, err.Error())
		}
		_, _ = fmt.Fprintln(stdout, command)
		return 0
	case "unset":
		shellName, remaining, err := parseShellArg(args[1:])
		if err != nil {
			return writeError(stderr, err.Error())
		}
		if len(remaining) != 1 {
			return writeError(stderr, "env unset requires a variable name")
		}

		shell, err := pathvador.ResolveShell(shellName, runtime.GOOS, getenv)
		if err != nil {
			return writeError(stderr, err.Error())
		}

		command, err := pathvador.UnsetCommand(shell, remaining[0])
		if err != nil {
			return writeError(stderr, err.Error())
		}
		_, _ = fmt.Fprintln(stdout, command)
		return 0
	default:
		return writeError(stderr, fmt.Sprintf("unknown env subcommand %q", args[0]))
	}
}

func parseShellArg(args []string) (string, []string, error) {
	if len(args) == 0 {
		return "auto", args, nil
	}

	if args[0] != "--shell" {
		return "auto", args, nil
	}

	if len(args) < 2 {
		return "", nil, fmt.Errorf("missing shell value after --shell")
	}

	return args[1], args[2:], nil
}

func printUsage(w io.Writer) {
	_, _ = fmt.Fprint(w, usageText)
}

func writeError(w io.Writer, message string) int {
	_, _ = fmt.Fprintf(w, "Error: %s\n\n", message)
	printUsage(w)
	return 1
}
