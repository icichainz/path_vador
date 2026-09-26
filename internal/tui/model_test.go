package tui

import (
	"path/filepath"
	"runtime"
	"testing"
)

func TestEvaluatePreviewJoin(t *testing.T) {
	op := operation{
		ID: opJoin,
		Fields: []fieldDefinition{{
			Label: "Fragments",
		}},
	}

	preview := evaluatePreview(op, []string{"src | assets | logo.svg"})
	expected := filepath.Join("src", "assets", "logo.svg")

	if preview.Body != expected {
		t.Fatalf("expected %q, got %q", expected, preview.Body)
	}

	if preview.Error {
		t.Fatal("expected successful preview")
	}
}

func TestEvaluatePreviewEnvExportDefaultsShell(t *testing.T) {
	op := operation{
		ID: opEnvExport,
		Fields: []fieldDefinition{
			{Label: "Variable Name"},
			{Label: "Value"},
			{Label: "Shell"},
		},
	}

	preview := evaluatePreview(op, []string{"PROJECT_ROOT", "/tmp/project", ""})

	expectedPrefix := "export PROJECT_ROOT="
	if runtime.GOOS == "windows" {
		expectedPrefix = "$Env:PROJECT_ROOT = "
	}

	if len(preview.Body) == 0 || preview.Body[:len(expectedPrefix)] != expectedPrefix {
		t.Fatalf("expected preview body to start with %q, got %q", expectedPrefix, preview.Body)
	}

	if preview.Error {
		t.Fatal("expected successful preview")
	}
}

func TestEvaluatePreviewRejectsInvalidShell(t *testing.T) {
	op := operation{
		ID: opEnvUnset,
		Fields: []fieldDefinition{
			{Label: "Variable Name"},
			{Label: "Shell"},
		},
	}

	preview := evaluatePreview(op, []string{"PROJECT_ROOT", "fish"})
	if !preview.Error {
		t.Fatal("expected invalid shell to surface as an error preview")
	}
}
