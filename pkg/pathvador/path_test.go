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

func TestExt(t *testing.T) {
	cases := map[string]string{
		"env.go":         ".go",
		"archive.tar.gz": ".gz",
		".bashrc":        ".bashrc",
		"Makefile":       "",
	}
	for input, expected := range cases {
		if actual := Ext(filepath.Join("alpha", input)); actual != expected {
			t.Fatalf("Ext(%q): expected %q, got %q", input, expected, actual)
		}
	}
}

func TestStem(t *testing.T) {
	cases := map[string]string{
		"env.go":         "env",
		"archive.tar.gz": "archive.tar",
		".bashrc":        ".bashrc",
		"Makefile":       "Makefile",
	}
	for input, expected := range cases {
		if actual := Stem(filepath.Join("alpha", input)); actual != expected {
			t.Fatalf("Stem(%q): expected %q, got %q", input, expected, actual)
		}
	}
}

func TestAbsFrom(t *testing.T) {
	root, err := filepath.Abs(filepath.Join("testroot", "dev"))
	if err != nil {
		t.Fatalf("abs: %v", err)
	}

	t.Run("relative path joins base", func(t *testing.T) {
		actual, err := AbsFrom(root, filepath.Join(".", "internal", "..", "pkg", "env.go"))
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		expected := filepath.Join(root, "pkg", "env.go")
		if actual != expected {
			t.Fatalf("expected %q, got %q", expected, actual)
		}
	})

	t.Run("absolute path ignores base", func(t *testing.T) {
		other, err := filepath.Abs(filepath.Join("elsewhere", ".", "file.txt"))
		if err != nil {
			t.Fatalf("abs: %v", err)
		}
		actual, err := AbsFrom(root, other)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if actual != filepath.Clean(other) {
			t.Fatalf("expected %q, got %q", filepath.Clean(other), actual)
		}
	})

	t.Run("empty base uses working directory", func(t *testing.T) {
		actual, err := AbsFrom("", "file.txt")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		expected, err := filepath.Abs("file.txt")
		if err != nil {
			t.Fatalf("abs: %v", err)
		}
		if actual != expected {
			t.Fatalf("expected %q, got %q", expected, actual)
		}
	})
}
