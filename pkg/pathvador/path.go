package pathvador

import "path/filepath"

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
