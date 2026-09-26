package engine

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type decoded struct {
	OK     bool              `json:"ok"`
	Result map[string]string `json:"result"`
	Error  string            `json:"error"`
}

func eval(t *testing.T, req string) decoded {
	t.Helper()
	out := Eval([]byte(req))
	if !json.Valid(out) {
		t.Fatalf("response is not valid JSON: %q", out)
	}
	var resp decoded
	if err := json.Unmarshal(out, &resp); err != nil {
		t.Fatalf("decode %q: %v", out, err)
	}
	return resp
}

func stubHost(t *testing.T, hostOS, shell, home string) {
	t.Helper()
	oldGOOS, oldGetenv, oldHome := goos, getenv, userHomeDir
	t.Cleanup(func() { goos, getenv, userHomeDir = oldGOOS, oldGetenv, oldHome })

	goos = hostOS
	getenv = func(key string) string {
		if key == "SHELL" {
			return shell
		}
		return ""
	}
	userHomeDir = func() (string, error) { return home, nil }
}

func TestEvalSuccess(t *testing.T) {
	stubHost(t, "linux", "/bin/zsh", "/home/you")

	root, err := filepath.Abs(filepath.Join("testroot", "dev"))
	if err != nil {
		t.Fatalf("abs: %v", err)
	}
	inspectReq, _ := json.Marshal(map[string]string{
		"op":   "inspect",
		"path": "./internal/../pkg/env.go",
		"base": root,
	})
	joinReq, _ := json.Marshal(map[string]any{"op": "join", "parts": []string{"src", "assets", "logo.svg"}})

	tests := []struct {
		name     string
		req      string
		expected map[string]string
	}{
		{
			name: "detect",
			req:  `{"op":"detect"}`,
			expected: map[string]string{
				"shell": "sh", "goos": "linux", "separator": string(filepath.Separator), "home": "/home/you",
			},
		},
		{
			name: "inspect",
			req:  string(inspectReq),
			expected: map[string]string{
				"clean": filepath.Join("pkg", "env.go"),
				"abs":   filepath.Join(root, "pkg", "env.go"),
				"dir":   "pkg",
				"base":  "env.go",
				"ext":   ".go",
				"stem":  "env",
			},
		},
		{
			name:     "join",
			req:      string(joinReq),
			expected: map[string]string{"joined": filepath.Join("src", "assets", "logo.svg")},
		},
		{
			name:     "env export sh",
			req:      `{"op":"env","shell":"bash","name":"PROJECT_ROOT","value":"/Users/you/dev"}`,
			expected: map[string]string{"command": "export PROJECT_ROOT='/Users/you/dev'", "shell": "sh", "kind": "export"},
		},
		{
			name:     "env export auto",
			req:      `{"op":"env","shell":"auto","name":"PROJECT_ROOT","value":"/tmp"}`,
			expected: map[string]string{"command": "export PROJECT_ROOT='/tmp'", "shell": "sh", "kind": "export"},
		},
		{
			name:     "env export powershell",
			req:      `{"op":"env","shell":"pwsh","name":"PROJECT_ROOT","value":"C:\\dev"}`,
			expected: map[string]string{"command": "$Env:PROJECT_ROOT = 'C:\\dev'", "shell": "powershell", "kind": "export"},
		},
		{
			name:     "env unset on empty value",
			req:      `{"op":"env","shell":"cmd","name":"PROJECT_ROOT","value":""}`,
			expected: map[string]string{"command": `set "PROJECT_ROOT="`, "shell": "cmd", "kind": "unset"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := eval(t, tt.req)
			if !resp.OK {
				t.Fatalf("expected ok, got error %q", resp.Error)
			}
			if len(resp.Result) != len(tt.expected) {
				t.Fatalf("expected result %v, got %v", tt.expected, resp.Result)
			}
			for key, want := range tt.expected {
				if got := resp.Result[key]; got != want {
					t.Fatalf("result[%q]: expected %q, got %q", key, want, got)
				}
			}
		})
	}
}

func TestEvalInspectEmptyBaseUsesWorkingDirectory(t *testing.T) {
	workingDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}

	resp := eval(t, `{"op":"inspect","path":"file.txt"}`)
	if !resp.OK {
		t.Fatalf("expected ok, got error %q", resp.Error)
	}
	if expected := filepath.Join(workingDir, "file.txt"); resp.Result["abs"] != expected {
		t.Fatalf("expected abs %q, got %q", expected, resp.Result["abs"])
	}
}

func TestEvalErrors(t *testing.T) {
	stubHost(t, "linux", "/bin/sh", "/home/you")

	tests := []struct {
		name    string
		req     string
		message string
	}{
		{name: "bad JSON", req: `{"op":`, message: "invalid request"},
		{name: "not an object", req: `[1,2]`, message: "invalid request"},
		{name: "empty input", req: ``, message: "invalid request"},
		{name: "unknown op", req: `{"op":"rename"}`, message: `unknown op "rename"`},
		{name: "missing op", req: `{}`, message: `unknown op ""`},
		{name: "inspect empty path", req: `{"op":"inspect","path":""}`, message: "path is empty"},
		{name: "invalid variable name", req: `{"op":"env","shell":"sh","name":"1BAD","value":"x"}`, message: `invalid variable name "1BAD"`},
		{name: "invalid name on unset", req: `{"op":"env","shell":"sh","name":"A-B","value":""}`, message: `invalid variable name "A-B"`},
		{name: "cmd value with percent", req: `{"op":"env","shell":"cmd","name":"X","value":"100%"}`, message: "cmd cannot safely set"},
		{name: "unsupported shell", req: `{"op":"env","shell":"fish","name":"X","value":"y"}`, message: `unsupported shell "fish"`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := eval(t, tt.req)
			if resp.OK {
				t.Fatalf("expected error, got result %v", resp.Result)
			}
			if !strings.Contains(resp.Error, tt.message) {
				t.Fatalf("expected error containing %q, got %q", tt.message, resp.Error)
			}
			if resp.Result != nil {
				t.Fatalf("expected no result on error, got %v", resp.Result)
			}
		})
	}
}

func TestEvalAlwaysReturnsValidJSON(t *testing.T) {
	inputs := []string{
		"", "null", "\x00\xff", `"op"`, `{"op":"join"}`, `{"op":"join","parts":null}`,
		`{"op":"inspect","path":"\u0000"}`, `{"op":"env","value":"\ud800"}`, strings.Repeat("{", 10000),
	}
	for _, input := range inputs {
		if out := Eval([]byte(input)); !json.Valid(out) {
			t.Fatalf("input %q produced invalid JSON %q", input, out)
		}
	}
}
