import { add } from "./add.wasm";

document.getElementById("result")!.textContent = `1 + 2 = ${add(1, 2)}`;
