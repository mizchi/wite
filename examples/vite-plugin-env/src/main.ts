// Client-side: import wasm module
import { add } from "./add.wasm";

const result = add(40, 2);
document.getElementById("result")!.textContent =
  `wasm add(40, 2) = ${result}`;

console.log("[client] wasm loaded, add(40, 2) =", result);
