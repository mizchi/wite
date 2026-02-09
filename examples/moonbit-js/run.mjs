const wasm = await WebAssembly.instantiate(
  await readFile("_build/wasm/release/build/moonbit-js.wasm"),
);
const { add, fib } = wasm.instance.exports;
console.log("add(1, 2) =", add(1, 2));
console.log("fib(10) =", fib(10));

async function readFile(path) {
  // Node.js
  if (typeof process !== "undefined") {
    const fs = await import("node:fs/promises");
    return fs.readFile(new URL(path, import.meta.url));
  }
  // Deno / Browser
  return fetch(new URL(path, import.meta.url)).then((r) => r.arrayBuffer());
}
