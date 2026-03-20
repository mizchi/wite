// Web Worker example: wasm runs off the main thread
// The ?wite-worker suffix tells vite-plugin-wite to use webworker runtime
// Functions return Promises (communication via postMessage)
import { add, __witeTerminate } from "./add.wasm?wite-worker";

async function run() {
  const el = document.getElementById("result")!;

  // Call wasm function in Worker (returns Promise)
  const result = await add(40, 2);
  el.textContent = `[Web Worker] wasm add(40, 2) = ${result}`;

  // Run multiple calls in parallel
  const results = await Promise.all([
    add(1, 2),
    add(10, 20),
    add(100, 200),
  ]);
  console.log("[webworker] parallel results:", results);

  // Clean up worker when done (optional)
  // __witeTerminate();
}

run().catch(console.error);
