package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunJoin(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"join", "one", "two", "three.txt"}, &stdout, &stderr)
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d", exitCode)
	}

	expected := filepath.Join("one", "two", "three.txt") + "\n"
	if stdout.String() != expected {
		t.Fatalf("expected stdout %q, got %q", expected, stdout.String())
	}

	if stderr.Len() != 0 {
		t.Fatalf("expected no stderr output, got %q", stderr.String())
	}
}

func TestRunEnvExport(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"env", "export", "--shell", "sh", "PROJECT_ROOT", "/tmp/project"}, &stdout, &stderr)
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d", exitCode)
	}

	expected := "export PROJECT_ROOT='/tmp/project'\n"
	if stdout.String() != expected {
		t.Fatalf("expected stdout %q, got %q", expected, stdout.String())
	}

	if stderr.Len() != 0 {
		t.Fatalf("expected no stderr output, got %q", stderr.String())
	}
}

func TestRunAbs(t *testing.T) {
	workingDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"abs", "README.MD"}, &stdout, &stderr)
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d", exitCode)
	}

	expected := filepath.Join(workingDir, "README.MD") + "\n"
	if stdout.String() != expected {
		t.Fatalf("expected stdout %q, got %q", expected, stdout.String())
	}

	if stderr.Len() != 0 {
		t.Fatalf("expected no stderr output, got %q", stderr.String())
	}
}

func TestRunReportsUsageForInvalidCommand(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"unknown"}, &stdout, &stderr)
	if exitCode != 1 {
		t.Fatalf("expected exit code 1, got %d", exitCode)
	}

	if stdout.Len() != 0 {
		t.Fatalf("expected no stdout output, got %q", stdout.String())
	}

	if !strings.Contains(stderr.String(), "unknown command") {
		t.Fatalf("expected unknown command error, got %q", stderr.String())
	}

	if !strings.Contains(stderr.String(), "Usage:") {
		t.Fatalf("expected usage text in stderr, got %q", stderr.String())
	}
}

func TestRunAbsFrom(t *testing.T) {
	root, err := filepath.Abs(filepath.Join("testroot", "dev"))
	if err != nil {
		t.Fatalf("abs: %v", err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"abs", "--from", root, filepath.Join("internal", "..", "pkg", "env.go")}, &stdout, &stderr)
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d (stderr %q)", exitCode, stderr.String())
	}

	expected := filepath.Join(root, "pkg", "env.go") + "\n"
	if stdout.String() != expected {
		t.Fatalf("expected stdout %q, got %q", expected, stdout.String())
	}
}

func TestRunAbsFromMissingValue(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"abs", "--from"}, &stdout, &stderr)
	if exitCode != 1 {
		t.Fatalf("expected exit code 1, got %d", exitCode)
	}

	if !strings.Contains(stderr.String(), "missing from value after --from") {
		t.Fatalf("expected missing value error, got %q", stderr.String())
	}
}

func TestRunExtAndStem(t *testing.T) {
	tests := []struct {
		args     []string
		expected string
	}{
		{args: []string{"ext", filepath.Join("pkg", "env.go")}, expected: ".go\n"},
		{args: []string{"ext", "archive.tar.gz"}, expected: ".gz\n"},
		{args: []string{"stem", filepath.Join("pkg", "env.go")}, expected: "env\n"},
		{args: []string{"stem", "archive.tar.gz"}, expected: "archive.tar\n"},
		{args: []string{"stem", ".bashrc"}, expected: ".bashrc\n"},
	}

	for _, tt := range tests {
		var stdout bytes.Buffer
		var stderr bytes.Buffer

		exitCode := Run(tt.args, &stdout, &stderr)
		if exitCode != 0 {
			t.Fatalf("%v: expected exit code 0, got %d", tt.args, exitCode)
		}
		if stdout.String() != tt.expected {
			t.Fatalf("%v: expected stdout %q, got %q", tt.args, tt.expected, stdout.String())
		}
	}
}

func TestRunEnvMissingShellValue(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := Run([]string{"env", "export", "--shell"}, &stdout, &stderr)
	if exitCode != 1 {
		t.Fatalf("expected exit code 1, got %d", exitCode)
	}

	if !strings.Contains(stderr.String(), "missing shell value after --shell") {
		t.Fatalf("expected missing shell error, got %q", stderr.String())
	}
}
