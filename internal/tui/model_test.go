package tui

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
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

	if !strings.HasPrefix(preview.Body, expectedPrefix) {
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

func typeRunes(m *Model, s string) tea.Cmd {
	var last tea.Cmd
	for _, r := range s {
		_, last = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
	}
	return last
}

func TestTypingLettersStaysInCurrentField(t *testing.T) {
	m := NewModel()
	m.Init()
	m.Update(tea.WindowSizeMsg{Width: 60, Height: 40})
	m.clearCurrentOperation()

	typeRunes(m, "jkhlbudfgGq/build")

	if got := m.selectedOperation().ID; got != opJoin {
		t.Fatalf("typing changed the operation to %q", got)
	}
	if got := m.inputs[0].Value(); got != "jkhlbudfgGq/build" {
		t.Fatalf("expected every rune in the field, got %q", got)
	}
}

func TestUpDownStillSelectOperations(t *testing.T) {
	m := NewModel()
	m.Update(tea.KeyMsg{Type: tea.KeyDown})
	if got := m.selectedOperation().ID; got != opClean {
		t.Fatalf("expected down to select clean, got %q", got)
	}
}
