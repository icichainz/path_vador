package pathvador

import (
	"fmt"
	"regexp"
	"strings"
)

type Shell string

const (
	ShellAuto       Shell = "auto"
	ShellSH         Shell = "sh"
	ShellPowerShell Shell = "powershell"
	ShellCMD        Shell = "cmd"
)

var envNamePattern = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

// ResolveShell converts a user-supplied shell name into a supported target shell.
func ResolveShell(shellName string, goos string, lookupEnv func(string) string) (Shell, error) {
	shell, err := normalizeShell(shellName)
	if err != nil {
		return "", err
	}

	if shell != ShellAuto {
		return shell, nil
	}

	return detectShell(goos, lookupEnv), nil
}

// ExportCommand formats a shell command that sets an environment variable.
func ExportCommand(shell Shell, name, value string) (string, error) {
	if err := validateVariableName(name); err != nil {
		return "", err
	}

	switch shell {
	case ShellSH:
		return fmt.Sprintf("export %s=%s", name, quoteForSH(value)), nil
	case ShellPowerShell:
		return fmt.Sprintf("$Env:%s = %s", name, quoteForPowerShell(value)), nil
	case ShellCMD:
		return fmt.Sprintf("set \"%s=%s\"", name, value), nil
	default:
		return "", fmt.Errorf("unsupported shell %q", shell)
	}
}

// UnsetCommand formats a shell command that removes an environment variable.
func UnsetCommand(shell Shell, name string) (string, error) {
	if err := validateVariableName(name); err != nil {
		return "", err
	}

	switch shell {
	case ShellSH:
		return fmt.Sprintf("unset %s", name), nil
	case ShellPowerShell:
		return fmt.Sprintf("Remove-Item Env:%s", name), nil
	case ShellCMD:
		return fmt.Sprintf("set \"%s=\"", name), nil
	default:
		return "", fmt.Errorf("unsupported shell %q", shell)
	}
}

func normalizeShell(shellName string) (Shell, error) {
	switch strings.ToLower(strings.TrimSpace(shellName)) {
	case "", "auto":
		return ShellAuto, nil
	case "sh", "bash", "zsh":
		return ShellSH, nil
	case "powershell", "pwsh":
		return ShellPowerShell, nil
	case "cmd":
		return ShellCMD, nil
	default:
		return "", fmt.Errorf("unsupported shell %q", shellName)
	}
}

func detectShell(goos string, lookupEnv func(string) string) Shell {
	shellHint := strings.ToLower(strings.TrimSpace(lookupEnv("SHELL") + " " + lookupEnv("COMSPEC")))

	switch {
	case strings.Contains(shellHint, "pwsh"), strings.Contains(shellHint, "powershell"):
		return ShellPowerShell
	case strings.Contains(shellHint, "cmd.exe"):
		return ShellCMD
	case goos == "windows":
		return ShellPowerShell
	default:
		return ShellSH
	}
}

func validateVariableName(name string) error {
	if !envNamePattern.MatchString(name) {
		return fmt.Errorf("invalid variable name %q", name)
	}

	return nil
}

func quoteForSH(value string) string {
	return "'" + strings.ReplaceAll(value, "'", `'"'"'`) + "'"
}

func quoteForPowerShell(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "''") + "'"
}
