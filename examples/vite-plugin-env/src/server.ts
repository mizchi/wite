// SSR entry: same wasm import, different environment
import { add } from "./add.wasm";

export function handler() {
  const result = add(40, 2);
  return `<html><body><h1>SSR: add(40, 2) = ${result}</h1></body></html>`;
}
