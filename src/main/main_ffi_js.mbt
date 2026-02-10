// JS FFI functions for main.mbt

///|
extern "js" fn js_ensure_parent_dir_for_file(path : String) -> Unit =
  #| (path) => {
  #|   try {
  #|     const fs = require('node:fs');
  #|     const p = require('node:path');
  #|     const dir = p.dirname(String(path));
  #|     if (dir && dir !== '.') {
  #|       fs.mkdirSync(dir, { recursive: true });
  #|     }
  #|   } catch (_) {}
  #| }

///|
extern "js" fn js_make_temp_wasm_path(prefix : String) -> String =
  #| (prefix) => {
  #|   const os = require('node:os');
  #|   const path = require('node:path');
  #|   const base = String(prefix || 'wite-diff').replace(/[^a-zA-Z0-9._-]/g, '-');
  #|   const token = Date.now().toString(36) + '-' + Math.floor(Math.random() * 1e9).toString(36);
  #|   return path.join(os.tmpdir(), base + '-' + token + '.wasm');
  #| }

///|
extern "js" fn js_run_wasm_opt_cli(
  wasm_opt_bin : String,
  args_spec : String,
  input_path : String,
  output_path : String,
) -> String =
  #| (wasmOptBin, argsSpec, inputPath, outputPath) => {
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   try {
  #|     const { spawnSync } = require('node:child_process');
  #|     const args = (argsSpec && argsSpec.length > 0) ? argsSpec.split('\t') : [];
  #|     args.push(inputPath, '-o', outputPath);
  #|     const result = spawnSync(wasmOptBin, args, { encoding: 'utf8' });
  #|     if (result.error) {
  #|       return 'error\tspawn\t' + sanitize(result.error.message || result.error);
  #|     }
  #|     const status = (result.status == null) ? -1 : result.status;
  #|     if (status !== 0) {
  #|       const detail = (result.stderr && result.stderr.length > 0)
  #|         ? result.stderr
  #|         : (result.stdout || '');
  #|       return 'error\texit:' + String(status) + '\t' + sanitize(detail);
  #|     }
  #|     return 'ok\t0\t';
  #|   } catch (e) {
  #|     const detail = (e && (e.stack || e.message)) ? (e.stack || e.message) : e;
  #|     return 'error\texception\t' + sanitize(detail);
  #|   }
  #| }
