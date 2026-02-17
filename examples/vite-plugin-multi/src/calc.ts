import { add } from "./add.wasm";
import { mul } from "./mul.wasm";

document.getElementById("add-result")!.textContent = `3 + 4 = ${add(3, 4)}`;
document.getElementById("mul-result")!.textContent = `3 * 4 = ${mul(3, 4)}`;
