# Engine contract: Go ⇄ Flutter

The Flutter app never reimplements path or shell logic. It calls the Go
library `pkg/pathvador` through one C-ABI function exported from a
`c-shared` build, exchanging JSON strings.

## C ABI

```c
// Evaluates one request and returns a malloc'd, NUL-terminated JSON string.
// The caller must release it with pv_free.
char* pv_eval(const char* request_json);
void  pv_free(char* p);
```

Library file, built by `make ui-native` from the repo root:

| OS      | Path                                   |
|---------|----------------------------------------|
| macOS   | `ui/native/macos/libpathvador.dylib`   |
| Linux   | `ui/native/linux/libpathvador.so`      |
| Windows | `ui/native/windows/pathvador.dll`      |

Dart resolves the library in this order: `$PATHVADOR_LIB` (a full path),
next to the running executable (`../Frameworks/` on macOS, `.` elsewhere),
then `ui/native/<os>/` relative to the working directory (development).

## Requests and responses

Every response is `{"ok": true, "result": {...}}` or
`{"ok": false, "error": "<human-readable message>"}`.

### detect

```json
{"op": "detect"}
→ {"ok": true, "result": {"shell": "sh", "goos": "darwin", "separator": "/", "home": "/Users/you"}}
```

`shell` is the resolved auto-detection (`sh` | `powershell` | `cmd`), from
`pathvador.ResolveShell("auto", runtime.GOOS, os.Getenv)`.

### inspect

```json
{"op": "inspect", "path": "./internal/../pkg/env.go", "base": "/Users/you/dev"}
→ {"ok": true, "result": {
     "clean": "pkg/env.go",
     "abs":   "/Users/you/dev/pkg/env.go",
     "dir":   "pkg",
     "base":  "env.go",
     "ext":   ".go",
     "stem":  "env"
   }}
```

`base` is the folder relative paths resolve against (`pathvador.AbsFrom`).
Empty `base` means the process working directory. Empty `path` is an
error.

### join

```json
{"op": "join", "parts": ["src", "assets", "logo.svg"]}
→ {"ok": true, "result": {"joined": "src/assets/logo.svg"}}
```

### env

```json
{"op": "env", "shell": "auto", "name": "PROJECT_ROOT", "value": "/Users/you/dev"}
→ {"ok": true, "result": {"command": "export PROJECT_ROOT='/Users/you/dev'", "shell": "sh", "kind": "export"}}
```

An empty `value` produces an unset command (`"kind": "unset"`).
`shell` accepts everything `pathvador.ResolveShell` accepts
(`auto`, `sh`, `bash`, `zsh`, `powershell`, `pwsh`, `cmd`). Invalid
variable names and unsafe cmd values come back as `ok: false` with the
library's own error message, which the UI shows verbatim.

Unknown `op` → `ok: false`.
