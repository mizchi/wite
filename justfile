# MoonBit Project Commands

# Default target (js for browser compatibility)
target := "js"

# Default task: check and test
default: check test

# Install wite to ~/.local/bin (JS version, requires Node.js)
install:
    moon build src/main --target js
    mkdir -p ~/.local/bin
    printf '#!/usr/bin/env node\n' > ~/.local/bin/wite
    cat target/js/release/build/main/main.js >> ~/.local/bin/wite
    chmod +x ~/.local/bin/wite
    @echo "installed: ~/.local/bin/wite"

# Install wite native binary to ~/.local/bin (no Node.js needed)
install-native:
    moon build src/main --target native
    mkdir -p ~/.local/bin
    cp target/native/release/build/main/main.exe ~/.local/bin/wite
    @echo "installed: ~/.local/bin/wite (native)"

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

# Run optimize speed benchmark (native binary, fixed iterations)
bench-optimize-speed iterations="5":
    node scripts/bench_optimize_speed.js --iterations={{iterations}}

# Run analyze speed benchmark (native binary, fixed iterations)
bench-analyze-speed iterations="5":
    node scripts/bench_analyze_speed.js --iterations={{iterations}}

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

# Build WAT deps for minimal example
example-minimal-deps:
    mkdir -p examples/minimal/deps/example
    wasm-tools parse examples/minimal/src/add.wat -o examples/minimal/deps/example/add.wasm
    wasm-tools parse examples/minimal/src/mul.wat -o examples/minimal/deps/example/mul.wasm

# Build minimal example (compose components)
example-minimal: example-minimal-deps
    mkdir -p examples/minimal/dist
    moon run src/main --target {{target}} -- build ./examples/minimal/main.wac --config=./examples/minimal/wite.config.jsonc -o ./examples/minimal/dist/composed.wasm

# Build WAT deps for wat-moonbit example
example-wat-moonbit-deps:
    mkdir -p examples/wat-moonbit/deps/example
    wasm-tools parse examples/wat-moonbit/src/add.wat -o examples/wat-moonbit/deps/example/add.wasm

# Build wat-moonbit example (requires: wasm-tools, moon)
# Note: moonbit guest build needs manual step - see examples/wat-moonbit/README.md
example-wat-moonbit: example-wat-moonbit-deps
    mkdir -p examples/wat-moonbit/dist
    moon run src/main --target {{target}} -- build ./examples/wat-moonbit/main.wac --config=./examples/wat-moonbit/wite.config.jsonc -o ./examples/wat-moonbit/dist/composed.wasm

# Build Rust guest deps for moonbit-rust example (requires: cargo-component)
example-moonbit-rust-deps:
    cd examples/moonbit-rust/guest/rust && cargo component build --release
    mkdir -p examples/moonbit-rust/deps/example
    cp examples/moonbit-rust/guest/rust/target/wasm32-wasip1/release/guest_rust.wasm examples/moonbit-rust/deps/example/rust-guest.wasm

# Build moonbit-rust example (compose)
example-moonbit-rust: example-moonbit-rust-deps
    mkdir -p examples/moonbit-rust/dist
    moon run src/main --target {{target}} -- build ./examples/moonbit-rust/main.wac --config=./examples/moonbit-rust/wite.config.jsonc -o ./examples/moonbit-rust/dist/composed.wasm

# Build Rust guest deps for moonbit-mixed example (requires: cargo-component)
example-moonbit-mixed-deps:
    cd examples/moonbit-mixed/guest/rust && cargo component build --release
    mkdir -p examples/moonbit-mixed/deps/example
    cp examples/moonbit-mixed/guest/rust/target/wasm32-wasip1/release/guest_rust.wasm examples/moonbit-mixed/deps/example/rust-guest.wasm

# Build moonbit-mixed example (compose Rust guest part)
example-moonbit-mixed: example-moonbit-mixed-deps
    mkdir -p examples/moonbit-mixed/dist
    moon run src/main --target {{target}} -- build ./examples/moonbit-mixed/main.wac --config=./examples/moonbit-mixed/wite.config.jsonc -o ./examples/moonbit-mixed/dist/composed.wasm

# Build moonbit-wasi guest, fetch WASI deps, optimize, and run (requires: moon, wasmtime)
example-moonbit-wasi:
    cd examples/moonbit-wasi && moon build --target wasm
    moon run src/main --target {{target}} -- deps sync --config=./examples/moonbit-wasi/wite.config.jsonc --dir=./examples/moonbit-wasi/deps --fail-fast
    moon run src/main --target {{target}} -- build --config=./examples/moonbit-wasi/wite.config.jsonc
    wasmtime run examples/moonbit-wasi/dist/app.min.wasm

# Build sample app component bundle under examples/sample_app
example-sample-app:
    moon run src/main --target {{target}} -- build ./examples/sample_app/main.wac --no-config -o ./examples/sample_app/sample.composed.wasm

# Test all buildable examples
test-examples: example-minimal example-wat-moonbit-deps example-moonbit-rust example-moonbit-mixed example-moonbit-wasi
    test -f examples/minimal/dist/composed.wasm
    wasm-tools print examples/minimal/dist/composed.wasm > /dev/null
    test -f examples/wat-moonbit/deps/example/add.wasm
    wasm-tools print examples/wat-moonbit/deps/example/add.wasm > /dev/null
    test -f examples/moonbit-rust/dist/composed.wasm
    wasm-tools print examples/moonbit-rust/dist/composed.wasm > /dev/null
    test -f examples/moonbit-mixed/dist/composed.wasm
    wasm-tools print examples/moonbit-mixed/dist/composed.wasm > /dev/null
    test -f examples/moonbit-wasi/_build/wasm/release/build/app.wasm
    test -d examples/moonbit-wasi/deps/wasi_cli
    test -f examples/moonbit-wasi/dist/app.min.wasm
    wasmtime run examples/moonbit-wasi/dist/app.min.wasm | grep -q "hello from moonbit-wasi"
    @echo "all example tests passed"

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test
