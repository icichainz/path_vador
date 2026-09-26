# path_vador

`path_vador` is a Charm-powered TUI for common path operations and temporary environment-variable commands on macOS, Linux, and Windows. It uses Bubble Tea, Bubbles, and Lip Gloss for the default interface.

## Install

Requires Go 1.24.2 or newer.

```bash
go install github.com/icichainz/path_vador@latest
```

## Launch The TUI

Run `path_vador` with no arguments to open the Bubble Tea interface.

### TUI Keys

```text
up/down      choose an operation
tab          move to the next field
shift+tab    move to the previous field
ctrl+r       clear the current operation
esc/ctrl+c   quit
```

## Examples

```bash
path_vador
```

The TUI presents these tools with a live preview:

- Join Paths
- Clean Path
- Absolute Path
- Base Name
- Directory
- Export Env
- Unset Env

## Optional Command Mode

If you pass arguments, `path_vador` keeps the current non-interactive mode for scripting:

```text
path_vador join <part> [<part>...]
path_vador clean <path>
path_vador abs [--from <dir>] <path>
path_vador base <path>
path_vador dir <path>
path_vador ext <path>
path_vador stem <path>
path_vador env export [--shell auto|sh|powershell|cmd] <NAME> <VALUE>
path_vador env unset [--shell auto|sh|powershell|cmd] <NAME>
```

Path helpers print one result per call:

```bash
path_vador abs --from ~/dev ./internal/../pkg/env.go   # ~/dev/pkg/env.go, resolved
path_vador ext pkg/pathvador/env.go                    # .go
path_vador stem archive.tar.gz                         # archive.tar
path_vador stem .bashrc                                # .bashrc (dotfiles keep their name)
```

Use shell evaluation when you want the generated environment-variable command to affect your current shell session.

```bash
eval "$(path_vador env export PROJECT_ROOT "$PWD")"
eval "$(path_vador env unset PROJECT_ROOT)"
```

On PowerShell the previewed command can be evaluated like this:

```powershell
Invoke-Expression (path_vador env export --shell powershell PROJECT_ROOT $PWD)
Invoke-Expression (path_vador env unset --shell powershell PROJECT_ROOT)
```

## Build From Source

```bash
make build       # CLI/TUI binary in bin/path_vador
make test        # go test ./...
make ui-native   # c-shared library for the Flutter UI in ui/native/<os>/ (needs cgo)
make clean
```
