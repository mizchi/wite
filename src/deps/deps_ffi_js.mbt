///|
extern "js" fn js_verify_wkg_package_cli(
  package_spec : String,
  registry_host : String,
) -> String =
  #| (packageSpec, registryHost) => {
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   let tempDir = '';
  #|   try {
  #|     const os = require('node:os');
  #|     const fs = require('node:fs');
  #|     const path = require('node:path');
  #|     const { spawnSync } = require('node:child_process');
  #|     tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wite-wkg-verify-'));
  #|     const outputPath = path.join(tempDir, 'pkg');
  #|     const args = [
  #|       'get',
  #|       String(packageSpec),
  #|       '--registry',
  #|       String(registryHost),
  #|       '--output',
  #|       outputPath,
  #|       '--overwrite',
  #|     ];
  #|     const result = spawnSync('wkg', args, { encoding: 'utf8' });
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
  #|   } finally {
  #|     try {
  #|       if (tempDir) {
  #|         const fs = require('node:fs');
  #|         fs.rmSync(tempDir, { recursive: true, force: true });
  #|       }
  #|     } catch (_) {
  #|       // ignore cleanup errors
  #|     }
  #|   }
  #| }

///|
extern "js" fn js_set_process_exit_code(code : Int) -> Unit =
  #| (code) => {
  #|   if (typeof process !== 'undefined' && process) {
  #|     process.exitCode = (code | 0);
  #|   }
  #| }

///|
extern "js" fn js_force_process_exit(code : Int) -> Unit =
  #| (code) => {
  #|   if (typeof process !== 'undefined' && process && typeof process.exit === 'function') {
  #|     process.exit(code | 0);
  #|   }
  #| }

///|
extern "js" fn js_sanitize_dep_sync_name(raw : String) -> String =
  #| (raw) => {
  #|   const text = String(raw ?? '').trim();
  #|   if (!text) return 'dep';
  #|   const safe = text
  #|     .replace(/\\/g, '/')
  #|     .split('/')
  #|     .filter((segment) => segment.length > 0 && segment !== '.' && segment !== '..')
  #|     .join('_')
  #|     .replace(/[^a-zA-Z0-9._-]/g, '_')
  #|     .replace(/_+/g, '_')
  #|     .replace(/^_+|_+$/g, '');
  #|   return safe.length > 0 ? safe : 'dep';
  #| }

///|
extern "js" fn js_sync_wkg_package_cli(
  package_spec : String,
  registry_host : String,
  output_dir : String,
) -> String =
  #| (packageSpec, registryHost, outputDir) => {
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   try {
  #|     const fs = require('node:fs');
  #|     const path = require('node:path');
  #|     const { spawnSync } = require('node:child_process');
  #|     const outDir = String(outputDir || 'deps').trim();
  #|     if (!outDir) {
  #|       return 'error\targs\toutput dir must not be empty';
  #|     }
  #|     fs.mkdirSync(outDir, { recursive: true });
  #|     const outArg = outDir.endsWith('/') || outDir.endsWith('\\')
  #|       ? outDir
  #|       : outDir + path.sep;
  #|     const args = [
  #|       'get',
  #|       String(packageSpec),
  #|       '--registry',
  #|       String(registryHost),
  #|       '--output',
  #|       outArg,
  #|       '--overwrite',
  #|     ];
  #|     const result = spawnSync('wkg', args, { encoding: 'utf8' });
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
  #|     return 'ok\t' + sanitize(outDir) + '\t' + sanitize(result.stdout || '');
  #|   } catch (e) {
  #|     const detail = (e && (e.stack || e.message)) ? (e.stack || e.message) : e;
  #|     return 'error\texception\t' + sanitize(detail);
  #|   }
  #| }

///|
extern "js" fn js_sync_wkg_package_to_file_cli(
  package_spec : String,
  registry_host : String,
  output_path : String,
) -> String =
  #| (packageSpec, registryHost, outputPath) => {
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   try {
  #|     const fs = require('node:fs');
  #|     const path = require('node:path');
  #|     const { spawnSync } = require('node:child_process');
  #|     const outPath = String(outputPath || '').trim();
  #|     if (!outPath) {
  #|       return 'error\targs\toutput path must not be empty';
  #|     }
  #|     fs.mkdirSync(path.dirname(outPath), { recursive: true });
  #|     const args = [
  #|       'get',
  #|       String(packageSpec),
  #|       '--registry',
  #|       String(registryHost),
  #|       '--format',
  #|       'wasm',
  #|       '--output',
  #|       outPath,
  #|       '--overwrite',
  #|     ];
  #|     const result = spawnSync('wkg', args, { encoding: 'utf8' });
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
  #|     return 'ok\t' + sanitize(outPath) + '\t' + sanitize(result.stdout || '');
  #|   } catch (e) {
  #|     const detail = (e && (e.stack || e.message)) ? (e.stack || e.message) : e;
  #|     return 'error\texception\t' + sanitize(detail);
  #|   }
  #| }
