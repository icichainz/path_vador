package pathvador

import "testing"

func TestResolveShellAutoDefaults(t *testing.T) {
	unixShell, err := ResolveShell("auto", "darwin", func(string) string { return "" })
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if unixShell != ShellSH {
		t.Fatalf("expected sh, got %q", unixShell)
	}

	windowsShell, err := ResolveShell("auto", "windows", func(string) string { return "" })
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if windowsShell != ShellPowerShell {
		t.Fatalf("expected powershell, got %q", windowsShell)
	}
}

func TestExportCommand(t *testing.T) {
	tests := []struct {
		name     string
		shell    Shell
		variable string
		value    string
		want     string
	}{
		{
			name:     "sh",
			shell:    ShellSH,
			variable: "PROJECT_ROOT",
			value:    "/tmp/demo path",
			want:     "export PROJECT_ROOT='/tmp/demo path'",
		},
		{
			name:     "powershell",
			shell:    ShellPowerShell,
			variable: "PROJECT_ROOT",
			value:    "C:\\Demo's Path",
			want:     "$Env:PROJECT_ROOT = 'C:\\Demo''s Path'",
		},
		{
			name:     "cmd",
			shell:    ShellCMD,
			variable: "PROJECT_ROOT",
			value:    `C:\Program Files\App`,
			want:     `set "PROJECT_ROOT=C:\Program Files\App"`,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := ExportCommand(test.shell, test.variable, test.value)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != test.want {
				t.Fatalf("expected %q, got %q", test.want, got)
			}
		})
	}
}

func TestUnsetCommand(t *testing.T) {
	tests := []struct {
		name     string
		shell    Shell
		variable string
		want     string
	}{
		{
			name:     "sh",
			shell:    ShellSH,
			variable: "PROJECT_ROOT",
			want:     "unset PROJECT_ROOT",
		},
		{
			name:     "powershell",
			shell:    ShellPowerShell,
			variable: "PROJECT_ROOT",
			want:     "Remove-Item Env:PROJECT_ROOT",
		},
		{
			name:     "cmd",
			shell:    ShellCMD,
			variable: "PROJECT_ROOT",
			want:     `set "PROJECT_ROOT="`,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := UnsetCommand(test.shell, test.variable)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != test.want {
				t.Fatalf("expected %q, got %q", test.want, got)
			}
		})
	}
}

func TestExportCommandRejectsInvalidVariableNames(t *testing.T) {
	if _, err := ExportCommand(ShellSH, "1INVALID", "value"); err == nil {
		t.Fatal("expected invalid variable name to be rejected")
	}
}
