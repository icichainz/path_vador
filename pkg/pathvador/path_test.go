package pathvador

import (
	"path/filepath"
	"testing"
)

func TestJoin(t *testing.T) {
	expected := filepath.Join("alpha", "beta", "file.txt")
	if actual := Join("alpha", "beta", "file.txt"); actual != expected {
		t.Fatalf("expected %q, got %q", expected, actual)
	}
}

func TestClean(t *testing.T) {
	expected := filepath.Clean(filepath.Join("alpha", ".", "beta", "..", "file.txt"))
	if actual := Clean(filepath.Join("alpha", ".", "beta", "..", "file.txt")); actual != expected {
		t.Fatalf("expected %q, got %q", expected, actual)
	}
}

func TestBaseAndDir(t *testing.T) {
	input := filepath.Join("alpha", "beta", "file.txt")

	if actual := Base(input); actual != "file.txt" {
		t.Fatalf("expected base %q, got %q", "file.txt", actual)
	}

	expectedDir := filepath.Join("alpha", "beta")
	if actual := Dir(input); actual != expectedDir {
		t.Fatalf("expected dir %q, got %q", expectedDir, actual)
	}
}
