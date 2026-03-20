export const RUNTIME_MODULE_ID = "\0wite-runtime";

export const RUNTIME_MODULE_CODE = `
const __cache = new Map();
const __listeners = new Map();

export function __witeGetInstance(url, importObject) {
  const key = url;
  let entry = __cache.get(key);
  if (!entry) {
    entry = WebAssembly.instantiateStreaming(fetch(url), importObject);
    __cache.set(key, entry);
  }
  return entry;
}

export function __witeInvalidate(url) {
  __cache.delete(url);
}

export function __witeReload(url, importObject) {
  __cache.delete(url);
  const entry = WebAssembly.instantiateStreaming(
    fetch(url + (url.includes('?') ? '&' : '?') + 't=' + Date.now()),
    importObject
  );
  __cache.set(url, entry);
  return entry;
}

export function __witeOnUpdate(url, callback) {
  if (!__listeners.has(url)) __listeners.set(url, []);
  __listeners.get(url).push(callback);
}

export function __witeNotifyUpdate(url) {
  const cbs = __listeners.get(url);
  if (cbs) cbs.forEach(cb => cb());
}
`;
