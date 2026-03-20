// Type declarations for direct .wasm imports (Cloudflare Workers)
declare module "*.wasm" {
  const wasmModule: WebAssembly.Module;
  export default wasmModule;
}
