// Cloudflare Workers entry point
// Import wasm directly — wrangler handles the wasm binding
import addWasm from "./add.wasm";

const instance = await WebAssembly.instantiate(addWasm, {});
const add = instance.exports.add as (a: number, b: number) => number;

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/add") {
      const a = Number(url.searchParams.get("a") ?? 1);
      const b = Number(url.searchParams.get("b") ?? 2);
      const result = add(a, b);
      return new Response(JSON.stringify({ a, b, result }), {
        headers: { "content-type": "application/json" },
      });
    }

    return new Response(`wasm add(40, 2) = ${add(40, 2)}`, {
      headers: { "content-type": "text/plain" },
    });
  },
};
