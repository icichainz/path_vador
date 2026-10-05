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

MODE ?= debug
ifeq ($(MODE),release)
	MACOS_CONFIG := Release
else
	MACOS_CONFIG := Debug
endif
MACOS_APP := ui/build/macos/Build/Products/$(MACOS_CONFIG)/PathVador.app

.PHONY: build test ui-native ui-macos dmg clean

# CLI and TUI binary.
build:
	$(GO) build -o bin/path_vador .

test:
	$(GO) test ./...

# c-shared library loaded by the Flutter UI (see ui/ENGINE.md). Needs cgo.
ui-native:
	CGO_ENABLED=1 $(GO) build -buildmode=c-shared $(UI_LDFLAGS) -o $(UI_LIB) ./cmd/libpathvador

# macOS app bundle with the engine in Contents/Frameworks and the CLI in
# Contents/Helpers (where the onboarding installer looks for it). The copies
# are signed ad hoc, then the bundle is re-signed keeping its entitlements.
ui-macos: build ui-native
	cd ui && flutter build macos --$(MODE)
	mkdir -p "$(MACOS_APP)/Contents/Helpers"
	cp $(UI_LIB) "$(MACOS_APP)/Contents/Frameworks/"
	cp bin/path_vador "$(MACOS_APP)/Contents/Helpers/"
	codesign --force --sign - "$(MACOS_APP)/Contents/Frameworks/libpathvador.dylib"
	codesign --force --sign - "$(MACOS_APP)/Contents/Helpers/path_vador"
	codesign --force --sign - --preserve-metadata=entitlements,identifier,flags "$(MACOS_APP)"

# Release app packaged as dist/PathVador-<version>.dmg (see the script for signing).
dmg:
	scripts/make_dmg.sh

clean:
	rm -rf bin dist ui/native/macos ui/native/linux ui/native/windows
