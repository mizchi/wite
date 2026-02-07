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

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test
