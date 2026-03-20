// Cloudflare Workers entry point
// Uses the same wasm import as client/server
import { add } from "./add.wasm";

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
