# MoonBit Project Commands

# Default target (js for browser compatibility)
target := "js"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --deny-warn --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Run benchmarks
bench:
    moon bench --target {{target}}

# Sync benchmark corpus from upstream repositories
bench-sync:
    scripts/sync_bench_corpus.sh

# Collect KPI report (size first, runtime second)
kpi:
    scripts/collect_kpi.sh

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Run main
run:
    moon run src/main --target {{target}}

# Verify configured wasm package dependencies
deps-verify:
    moon run src/main --target {{target}} -- deps verify --config=./wite.config.jsonc --fail-fast

# Sync configured wasm package dependencies to deps/
deps-sync:
    moon run src/main --target {{target}} -- deps sync --config=./wite.config.jsonc --verify --fail-fast

# Run minimal example config under examples/minimal
example-minimal:
    moon run src/main --target {{target}} -- analyze bench/corpus/core/binaryen/br_to_exit.wasm --config=./examples/minimal/wite.config.jsonc

# Build sample app component bundle under examples/sample_app
example-sample-app:
    moon run src/main --target {{target}} -- build ./examples/sample_app/main.wac --no-config -o ./examples/sample_app/sample.composed.wasm

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test
