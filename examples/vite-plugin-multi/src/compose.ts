import { add, mul } from "./math.wasm";

document.getElementById("add-result")!.textContent = `3 + 4 = ${add(3, 4)}`;
document.getElementById("mul-result")!.textContent = `3 * 4 = ${mul(3, 4)}`;
