GO ?= go

ifeq ($(OS),Windows_NT)
	HOST_OS := windows
else
	HOST_OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
endif

ifeq ($(HOST_OS),darwin)
	UI_LIB := ui/native/macos/libpathvador.dylib
	# @rpath lets the app bundle load the library from Contents/Frameworks.
	UI_LDFLAGS := -ldflags=-extldflags=-Wl,-install_name,@rpath/libpathvador.dylib
else ifeq ($(HOST_OS),linux)
	UI_LIB := ui/native/linux/libpathvador.so
else
	UI_LIB := ui/native/windows/pathvador.dll
endif

.PHONY: build test ui-native clean

# CLI and TUI binary.
build:
	$(GO) build -o bin/path_vador .

test:
	$(GO) test ./...

# c-shared library loaded by the Flutter UI (see ui/ENGINE.md). Needs cgo.
ui-native:
	CGO_ENABLED=1 $(GO) build -buildmode=c-shared $(UI_LDFLAGS) -o $(UI_LIB) ./cmd/libpathvador

clean:
	rm -rf bin ui/native/macos ui/native/linux ui/native/windows
