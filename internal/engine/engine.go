// Package engine answers the JSON requests described in ui/ENGINE.md so the
// Flutter UI can reuse pkg/pathvador through a single C-ABI function.
package engine

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"github.com/icichainz/path_vador/pkg/pathvador"
)

// Hooks into the host environment, replaced in tests.
var (
	goos        = runtime.GOOS
	getenv      = os.Getenv
	userHomeDir = os.UserHomeDir
)

type request struct {
	Op    string   `json:"op"`
	Path  string   `json:"path"`
	Base  string   `json:"base"`
	Parts []string `json:"parts"`
	Shell string   `json:"shell"`
	Name  string   `json:"name"`
	Value string   `json:"value"`
}

type response struct {
	OK     bool   `json:"ok"`
	Result any    `json:"result,omitempty"`
	Error  string `json:"error,omitempty"`
}

// Eval decodes one JSON request, runs it and returns the JSON response.
// It never panics: every failure becomes {"ok":false,"error":"..."}.
func Eval(req []byte) (out []byte) {
	defer func() {
		if r := recover(); r != nil {
			out = encode(response{Error: fmt.Sprintf("internal error: %v", r)})
		}
	}()

	result, err := dispatch(req)
	if err != nil {
		return encode(response{Error: err.Error()})
	}
	return encode(response{OK: true, Result: result})
}

func dispatch(raw []byte) (any, error) {
	var req request
	if err := json.Unmarshal(raw, &req); err != nil {
		return nil, fmt.Errorf("invalid request: %v", err)
	}

	switch req.Op {
	case "detect":
		return detect()
	case "inspect":
		return inspect(req.Path, req.Base)
	case "join":
		return map[string]string{"joined": pathvador.Join(req.Parts...)}, nil
	case "env":
		return env(req.Shell, req.Name, req.Value)
	default:
		return nil, fmt.Errorf("unknown op %q", req.Op)
	}
}

func detect() (any, error) {
	shell, err := pathvador.ResolveShell("auto", goos, getenv)
	if err != nil {
		return nil, err
	}
	// A missing home directory is not fatal to detection; report it empty.
	home, _ := userHomeDir()

	return map[string]string{
		"shell":     string(shell),
		"goos":      goos,
		"separator": string(filepath.Separator),
		"home":      home,
	}, nil
}

func inspect(path, base string) (any, error) {
	if path == "" {
		return nil, errors.New("path is empty")
	}

	absolute, err := pathvador.AbsFrom(base, path)
	if err != nil {
		return nil, err
	}
	clean := pathvador.Clean(path)

	return map[string]string{
		"clean": clean,
		"abs":   absolute,
		"dir":   pathvador.Dir(clean),
		"base":  pathvador.Base(clean),
		"ext":   pathvador.Ext(clean),
		"stem":  pathvador.Stem(clean),
	}, nil
}

func env(shellName, name, value string) (any, error) {
	shell, err := pathvador.ResolveShell(shellName, goos, getenv)
	if err != nil {
		return nil, err
	}

	kind := "export"
	var command string
	if value == "" {
		kind = "unset"
		command, err = pathvador.UnsetCommand(shell, name)
	} else {
		command, err = pathvador.ExportCommand(shell, name, value)
	}
	if err != nil {
		return nil, err
	}

	return map[string]string{"command": command, "shell": string(shell), "kind": kind}, nil
}

func encode(resp response) []byte {
	out, err := json.Marshal(resp)
	if err != nil {
		return []byte(`{"ok":false,"error":"internal error: cannot encode response"}`)
	}
	return out
}
