export const RUNTIME_MODULE_ID = "\0wite-runtime";

export const RUNTIME_MODULE_CODE = `
const __cache = new Map();

export function __witeGetInstance(url, importObject) {
  const key = url;
  let entry = __cache.get(key);
  if (!entry) {
    entry = WebAssembly.instantiateStreaming(fetch(url), importObject);
    __cache.set(key, entry);
  }
  return entry;
}
`;
