# Race to Dead End - Godot 4.7.2 Project Makefile
# Build, test, lint, asset verification, and release automation.

SHELL := /bin/bash

GODOT        ?= $(shell command -v godot 2>/dev/null || command -v godot4 2>/dev/null || echo godot)
PYTHON       ?= $(shell command -v python3 2>/dev/null || echo python3)
CURL         ?= $(shell command -v curl 2>/dev/null || echo curl)
UNZIP        ?= $(shell command -v unzip 2>/dev/null || echo unzip)
GDLINT       ?= $(shell command -v gdlint 2>/dev/null || true)
GDFORMAT     ?= $(shell command -v gdformat 2>/dev/null || true)
MARKDOWNLINT ?= $(shell command -v markdownlint 2>/dev/null || true)

GODOT_VERSION ?= 4.7.2
GUT_VERSION   ?= 9.7.1
GUT_URL       ?= https://github.com/bitwes/Gut/archive/refs/tags/v$(GUT_VERSION).zip
COI_SW_SHA    ?= 7b1d2a092d0d2dd2b7270b6f12f13605de26f214
COI_SW_URL    ?= https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/$(COI_SW_SHA)/coi-serviceworker.js

BUILD_DIR     ?= build
WEB_DIR       ?= $(BUILD_DIR)/web
LINUX_DIR     ?= $(BUILD_DIR)/linux
MACOS_DIR     ?= $(BUILD_DIR)/macos
ANDROID_DIR   ?= $(BUILD_DIR)/android
IOS_DIR       ?= $(BUILD_DIR)/ios

PYTHON_SCRIPTS := scripts/check_bg.py scripts/remove_bg.py scripts/restructure_scripts.py scripts/update_gd.py

.PHONY: all help ci check check-godot deps deps-python install-gut import run editor \
	test test-unit test-integration test-runner test-scripts \
	lint lint-gd lint-python lint-docs fmt fmt-check check-assets \
	build build-web build-linux build-macos build-android build-ios build-all serve-web \
	clean clean-all

# Default target
all: check

## help: Print available targets and descriptions
help:
	@echo "Race to Dead End (Godot $(GODOT_VERSION)) - Makefile Targets"
	@echo ""
	@echo "Setup & Dependencies:"
	@echo "  check-godot       Verify Godot binary is installed and print version"
	@echo "  deps              Install GUT ($(GUT_VERSION)) addon if missing"
	@echo "  install-gut       Force (re)install GUT v$(GUT_VERSION) into addons/gut/"
	@echo "  deps-python       Install Python script dependencies from scripts/requirements.txt"
	@echo "  import            Import project resources in headless Godot"
	@echo ""
	@echo "Run & Develop:"
	@echo "  run               Launch the game with Godot"
	@echo "  editor            Open the project in the Godot Editor"
	@echo ""
	@echo "Testing:"
	@echo "  test              Run full GUT test suite (unit + integration)"
	@echo "  test-unit         Run GUT unit tests (tests/unit)"
	@echo "  test-integration  Run GUT integration tests (tests/integration)"
	@echo "  test-runner       Run custom headless SceneTree test runner (scripts/run_tests.gd)"
	@echo "  test-scripts      Run legacy batched test script (scripts/run_tests.sh)"
	@echo ""
	@echo "Linting & Verification:"
	@echo "  check             Run check-godot, lint, and full test suite"
	@echo "  ci                Alias for check (mirrors CI verification gate)"
	@echo "  lint              Run Python syntax checks and optional gdlint/markdownlint"
	@echo "  lint-gd           Run gdlint on scripts/ and tests/ (if installed)"
	@echo "  lint-python       Byte-compile Python utility scripts under scripts/"
	@echo "  lint-docs         Lint Markdown docs with markdownlint (if installed)"
	@echo "  fmt               Format GDScript files with gdformat (if installed)"
	@echo "  fmt-check         Check GDScript formatting with gdformat --check (if installed)"
	@echo "  check-assets      Inspect enemy sprite alpha channels via scripts/check_bg.py"
	@echo ""
	@echo "Build & Export:"
	@echo "  build             Export Web build (default release artifact)"
	@echo "  build-web         Export Web build and inject pinned coi-serviceworker.js"
	@echo "  build-linux       Export Linux x86_64 release build"
	@echo "  build-macos       Export macOS universal release build"
	@echo "  build-android     Export Android APK release build"
	@echo "  build-ios         Export iOS IPA release build"
	@echo "  build-all         Export Web, Linux, and macOS builds"
	@echo "  serve-web         Serve $(WEB_DIR) locally with COOP/COEP headers on :8080"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean             Remove exported build artifacts ($(BUILD_DIR)/ and builds/)"
	@echo "  clean-all         Remove build artifacts, .godot/ cache, and addons/gut/"

# ==============================================================================
# Setup & Dependencies
# ==============================================================================

check-godot:
	@command -v "$(GODOT)" >/dev/null 2>&1 || { \
		echo "Error: Godot binary '$(GODOT)' not found in PATH."; \
		exit 1; \
	}
	@"$(GODOT)" --version

deps:
	@if [ ! -f addons/gut/gut_cmdln.gd ]; then \
		$(MAKE) install-gut; \
	else \
		echo "GUT already installed in addons/gut/"; \
	fi

install-gut:
	@echo "Installing GUT v$(GUT_VERSION) into addons/gut/..."
	@mkdir -p addons/gut
	@TMP_DIR=$$(mktemp -d); \
	$(CURL) -fsSL -o "$$TMP_DIR/gut.zip" "$(GUT_URL)"; \
	$(UNZIP) -q -o "$$TMP_DIR/gut.zip" -d "$$TMP_DIR"; \
	rm -rf addons/gut/*; \
	cp -r "$$TMP_DIR/Gut-$(GUT_VERSION)/addons/gut/"* addons/gut/; \
	rm -rf "$$TMP_DIR"
	@echo "GUT v$(GUT_VERSION) installed."

deps-python:
	$(PYTHON) -m pip install -r scripts/requirements.txt

import: check-godot
	"$(GODOT)" --headless --import --quit

# ==============================================================================
# Run & Develop
# ==============================================================================

run: check-godot
	"$(GODOT)" --path .

editor: check-godot
	"$(GODOT)" --editor --path .

# ==============================================================================
# Testing
# ==============================================================================

test: check-godot deps import
	"$(GODOT)" --headless -s addons/gut/gut_cmdln.gd \
		-gdir=res://tests/unit,res://tests/integration \
		-ginclude_subdirs -gexit -glog=1

test-unit: check-godot deps import
	"$(GODOT)" --headless -s addons/gut/gut_cmdln.gd \
		-gdir=res://tests/unit -gexit -glog=1

test-integration: check-godot deps import
	"$(GODOT)" --headless -s addons/gut/gut_cmdln.gd \
		-gdir=res://tests/integration -gexit -glog=1

test-runner: check-godot deps import
	"$(GODOT)" --headless -s scripts/run_tests.gd

test-scripts: check-godot deps import
	GODOT="$(GODOT)" bash scripts/run_tests.sh

# ==============================================================================
# Linting & Verification
# ==============================================================================

lint: lint-python lint-gd

lint-python:
	@echo "Checking Python scripts..."
	$(PYTHON) -B -m py_compile $(PYTHON_SCRIPTS)

lint-gd:
	@if [ -n "$(GDLINT)" ]; then \
		echo "Running gdlint..."; \
		$(GDLINT) scripts tests demo; \
	else \
		echo "gdlint not found; skipping GDScript style lint (install gdtoolkit to enable)."; \
	fi

lint-docs:
	@if [ -n "$(MARKDOWNLINT)" ]; then \
		echo "Running markdownlint..."; \
		$(MARKDOWNLINT) README.md docs/*.md; \
	else \
		echo "markdownlint not found; skipping Markdown lint."; \
	fi

fmt:
	@if [ -n "$(GDFORMAT)" ]; then \
		$(GDFORMAT) scripts tests demo; \
	else \
		echo "gdformat not found; install gdtoolkit to format GDScript files."; \
		exit 1; \
	fi

fmt-check:
	@if [ -n "$(GDFORMAT)" ]; then \
		$(GDFORMAT) --check scripts tests demo; \
	else \
		echo "gdformat not found; skipping GDScript format check."; \
	fi

check-assets:
	$(PYTHON) scripts/check_bg.py

check: check-godot lint test
	@echo "=========================================================="
	@echo "  Race to Dead End local verification passed!"
	@echo "=========================================================="

ci: check

# ==============================================================================
# Build & Export
# ==============================================================================

build: build-web

build-web: check-godot import
	@mkdir -p "$(WEB_DIR)"
	"$(GODOT)" --headless --export-release "Web" "$(WEB_DIR)/index.html"
	$(CURL) -fsSL -o "$(WEB_DIR)/coi-serviceworker.js" "$(COI_SW_URL)"
	@if ! grep -q 'coi-serviceworker.js' "$(WEB_DIR)/index.html"; then \
		sed -i 's|<head>|<head><script src="coi-serviceworker.js"></script>|g' "$(WEB_DIR)/index.html"; \
	fi
	@echo "Web build exported to $(WEB_DIR)/"

build-linux: check-godot import
	@mkdir -p "$(LINUX_DIR)"
	"$(GODOT)" --headless --export-release "Linux" "$(LINUX_DIR)/RaceToDeadEnd.x86_64"
	@echo "Linux build exported to $(LINUX_DIR)/"

build-macos: check-godot import
	@mkdir -p "$(MACOS_DIR)"
	"$(GODOT)" --headless --export-release "macOS" "$(MACOS_DIR)/RaceToDeadEnd.zip"
	@echo "macOS build exported to $(MACOS_DIR)/"

build-android: check-godot import
	@mkdir -p "$(ANDROID_DIR)"
	"$(GODOT)" --headless --export-release "Android" "$(ANDROID_DIR)/RaceToDeadEnd.apk"
	@echo "Android build exported to $(ANDROID_DIR)/"

build-ios: check-godot import
	@mkdir -p "$(IOS_DIR)"
	"$(GODOT)" --headless --export-release "iOS" "$(IOS_DIR)/RaceToDeadEnd.ipa"
	@echo "iOS build exported to $(IOS_DIR)/"

build-all: build-web build-linux build-macos

serve-web:
	@test -f "$(WEB_DIR)/index.html" || { echo "Run 'make build-web' first."; exit 1; }
	@echo "Serving $(WEB_DIR) at http://127.0.0.1:8080 (with COOP/COEP headers)..."
	@$(PYTHON) -c '\
import http.server, functools; \
class COIHandler(http.server.SimpleHTTPRequestHandler): \
    def end_headers(self): \
        self.send_header("Cross-Origin-Opener-Policy", "same-origin"); \
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp"); \
        super().end_headers(); \
http.server.test(HandlerClass=functools.partial(COIHandler, directory="$(WEB_DIR)"), port=8080, bind="127.0.0.1")'

# ==============================================================================
# Cleanup
# ==============================================================================

clean:
	rm -rf "$(BUILD_DIR)" builds
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +

clean-all: clean
	rm -rf addons/gut .godot
