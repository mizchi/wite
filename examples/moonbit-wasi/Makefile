WASMTIME_VERSION := 41.0.3
ADAPTER := wasi_snapshot_preview1.command.wasm
ADAPTER_URL := https://github.com/bytecodealliance/wasmtime/releases/download/v$(WASMTIME_VERSION)/$(ADAPTER)

CORE_WASM := _build/wasm/release/build/app.wasm
COMPONENT_WASM := dist/app.component.wasm
JS_DIR := dist/js

.PHONY: build run clean

# moon build → component → jco transpile
build: $(CORE_WASM) $(ADAPTER)
	mkdir -p dist
	wasm-tools component new $(CORE_WASM) \
		--adapt wasi_snapshot_preview1=$(ADAPTER) \
		-o $(COMPONENT_WASM)
	jco transpile $(COMPONENT_WASM) -o $(JS_DIR)

$(CORE_WASM): main.mbt moon.pkg moon.mod.json
	moon build --target wasm

$(ADAPTER):
	curl -sL -o $@ $(ADAPTER_URL)

# Run transpiled JS with Node.js
run: build
	node --input-type=module -e 'import { run } from "./$(JS_DIR)/app.component.js"; run.run()'

clean:
	moon clean
	rm -rf dist
