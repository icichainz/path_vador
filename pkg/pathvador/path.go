package pathvador

import (
	"path/filepath"
	"strings"
)

// Join combines path fragments using the current OS path separator.
func Join(parts ...string) string {
	return filepath.Join(parts...)
}

// Clean normalizes a path by removing redundant separators and dots.
func Clean(path string) string {
	return filepath.Clean(path)
}

// Abs resolves a path against the current working directory.
func Abs(path string) (string, error) {
	return filepath.Abs(path)
}

// Base returns the last element of a path.
func Base(path string) string {
	return filepath.Base(path)
}

// Dir returns every element except the last one.
func Dir(path string) string {
	return filepath.Dir(path)
}

// Ext returns the file name extension, including the leading dot.
func Ext(path string) string {
	return filepath.Ext(path)
}

// Stem returns the last element of a path without its extension. Dotfiles
// such as ".bashrc" keep their full name: filepath.Ext treats the whole
// name as the extension, which would otherwise leave an empty stem.
func Stem(path string) string {
	base := filepath.Base(path)
	if stem := strings.TrimSuffix(base, filepath.Ext(base)); stem != "" {
		return stem
	}
	return base
}

// AbsFrom resolves a path against base instead of the current working
// directory. Absolute paths are only cleaned; an empty base falls back to Abs.
func AbsFrom(base, path string) (string, error) {
	if base == "" {
		return Abs(path)
	}
	if filepath.IsAbs(path) {
		return Clean(path), nil
	}
	return Clean(Join(base, path)), nil
}
