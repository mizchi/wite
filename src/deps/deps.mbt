///|
pub enum DependencyProtocol {
  Wkg
  Warg
  Oci
}

///|
pub struct WasmDependencySpec {
  ns : String
  name : String
  version : String
}

///|
priv struct ParsedDependencyInput {
  protocol : DependencyProtocol
  spec : WasmDependencySpec
  host : String?
}

///|
pub struct DepConfigEntry {
  name : String
  url : String
}

///|
priv enum VerifyBackend {
  Oci(@oci_types.OciConfig)
  Warg(@oci_types.WargConfig)
}

///|
fn dependency_protocol_name(protocol : DependencyProtocol) -> String {
  match protocol {
    DependencyProtocol::Wkg => "wkg"
    DependencyProtocol::Warg => "warg"
    DependencyProtocol::Oci => "oci"
  }
}

///|
fn parse_dependency_protocol(name : String) -> DependencyProtocol? {
  match name.to_lower() {
    "wkg" => Some(DependencyProtocol::Wkg)
    "warg" => Some(DependencyProtocol::Warg)
    "oci" => Some(DependencyProtocol::Oci)
    _ => None
  }
}

///|
fn normalize_dependency_host(raw : String) -> String {
  let mut host = raw.trim().to_string()
  if host.has_prefix("https://") {
    host = host[8:].to_string() catch { _ => host }
  } else if host.has_prefix("http://") {
    host = host[7:].to_string() catch { _ => host }
  }
  if host.has_suffix("/") {
    host = host[:host.length() - 1].to_string() catch { _ => host }
  }
  host
}

///|
fn default_dependency_host(_protocol : DependencyProtocol) -> String {
  "wa.dev"
}

///|
fn parse_versioned_segment(raw : String) -> (String, String) {
  let text = raw.trim().to_string()
  match text.rev_find("@") {
    Some(index) if index > 0 && index + 1 < text.length() => {
      let base = text[:index].to_string() catch { _ => text }
      let version = text[index + 1:].to_string() catch { _ => "latest" }
      (base, version)
    }
    _ => (text, "latest")
  }
}

///|
fn parse_wasm_dependency_spec(raw : String) -> WasmDependencySpec? {
  let (base, version) = parse_versioned_segment(raw)
  if base.is_empty() || version.is_empty() {
    return None
  }
  if base.contains("/") {
    let first_slash = base.find("/")
    let last_slash = base.rev_find("/")
    match (first_slash, last_slash) {
      (Some(first), Some(last)) if first == last &&
        first > 0 &&
        first + 1 < base.length() => {
        let ns = base[:first].to_string() catch { _ => "" }
        let name = base[first + 1:].to_string() catch { _ => "" }
        if ns.contains(":") || name.contains(":") {
          return None
        }
        let colon_name = ns + ":" + name
        if @oci_types.PackageName::parse(colon_name) is None {
          return None
        }
        return Some({ ns, name, version })
      }
      _ => return None
    }
  }
  let first_colon = base.find(":")
  let last_colon = base.rev_find(":")
  match (first_colon, last_colon) {
    (Some(first), Some(last)) if first == last &&
      first > 0 &&
      first + 1 < base.length() => ()
    _ => return None
  }
  let parsed = @oci_types.PackageName::parse(base)
  match parsed {
    Some(pkg) => Some({ ns: pkg.ns, name: pkg.name, version })
    None => None
  }
}

///|
fn parse_https_dependency_url(raw : String) -> (String, WasmDependencySpec)? {
  let text = raw.trim().to_string()
  let rest = if text.has_prefix("https://") {
    text[8:].to_string() catch {
      _ => ""
    }
  } else if text.has_prefix("http://") {
    text[7:].to_string() catch {
      _ => ""
    }
  } else {
    return None
  }
  if rest.is_empty() {
    return None
  }
  let slash = match rest.find("/") {
    Some(i) if i > 0 && i + 1 < rest.length() => i
    _ => return None
  }
  let host = normalize_dependency_host(
    rest[:slash].to_string() catch {
      _ => ""
    },
  )
  if host.is_empty() {
    return None
  }
  let mut spec_text = rest[slash + 1:].to_string() catch { _ => "" }
  match spec_text.find("?") {
    Some(i) => spec_text = spec_text[:i].to_string() catch { _ => spec_text }
    None => ()
  }
  match spec_text.find("#") {
    Some(i) => spec_text = spec_text[:i].to_string() catch { _ => spec_text }
    None => ()
  }
  match parse_wasm_dependency_spec(spec_text) {
    Some(spec) => Some((host, spec))
    None => None
  }
}

///|
fn parse_dependency_input(
  raw : String,
  default_protocol : DependencyProtocol,
) -> ParsedDependencyInput? {
  match parse_https_dependency_url(raw) {
    Some((host, spec)) =>
      return Some({ protocol: default_protocol, spec, host: Some(host) })
    None => ()
  }
  let text = raw.trim().to_string()
  if text.is_empty() {
    return None
  }
  let first_colon = text.find(":")
  match first_colon {
    Some(i) if i > 0 && i + 1 < text.length() => {
      let candidate = text[:i].to_string() catch { _ => "" }
      match parse_dependency_protocol(candidate) {
        Some(protocol) => {
          let body = text[i + 1:].to_string() catch { _ => "" }
          match parse_wasm_dependency_spec(body) {
            Some(spec) => Some({ protocol, spec, host: None })
            None => None
          }
        }
        None =>
          match parse_wasm_dependency_spec(text) {
            Some(spec) => Some({ protocol: default_protocol, spec, host: None })
            None => None
          }
      }
    }
    _ =>
      match parse_wasm_dependency_spec(text) {
        Some(spec) => Some({ protocol: default_protocol, spec, host: None })
        None => None
      }
  }
}

///|
fn normalize_dep_key(input : ParsedDependencyInput) -> String {
  input.spec.ns + "/" + input.spec.name
}

///|
fn build_dep_url(host : String, spec : WasmDependencySpec) -> String {
  let version_suffix = if spec.version == "latest" {
    ""
  } else {
    "@" + spec.version
  }
  "https://" + host + "/" + spec.ns + ":" + spec.name + version_suffix
}

///|
fn resolve_verify_backend(
  protocol : DependencyProtocol,
  config : @oci_types.RegistryConfig,
) -> Result[VerifyBackend, String] {
  match protocol {
    DependencyProtocol::Oci =>
      match config.oci {
        Some(oci) => Ok(VerifyBackend::Oci(oci))
        None => Err("registry does not provide oci backend")
      }
    DependencyProtocol::Warg =>
      match config.warg {
        Some(warg) => Ok(VerifyBackend::Warg(warg))
        None => Err("registry does not provide warg backend")
      }
    DependencyProtocol::Wkg =>
      match config.oci {
        Some(oci) => Ok(VerifyBackend::Oci(oci))
        None =>
          match config.warg {
            Some(warg) => Ok(VerifyBackend::Warg(warg))
            None => Err("registry does not provide oci/warg backend")
          }
      }
  }
}

///|
fn build_verify_package_spec(spec : WasmDependencySpec) -> String {
  let base = spec.ns + ":" + spec.name
  if spec.version == "latest" {
    base
  } else {
    base + "@" + spec.version
  }
}

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
fn exit_process(code : Int) -> Unit {
  js_set_process_exit_code(code)
  js_force_process_exit(code)
  @sys.exit(code)
}

///|
fn parse_wkg_verify_cli_result(raw : String) -> Result[Unit, String] {
  let parts : Array[String] = []
  for part in raw.split("\t") {
    parts.push(part.to_string())
  }
  if parts.length() > 0 && parts[0] == "ok" {
    return Ok(())
  }
  let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
  let detail = if parts.length() >= 3 { parts[2] } else { raw }
  Err(stage + ": " + detail)
}

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
fn normalize_dep_sync_output_dir(raw : String) -> String {
  let text = raw.trim()
  if text.is_empty() {
    "deps"
  } else if text.has_suffix("/") {
    text[:text.length() - 1].to_string() catch {
      _ => text.to_string()
    }
  } else {
    text.to_string()
  }
}

///|
fn build_dep_sync_target_dir(
  base_dir : String,
  dependency_name : String,
) -> String {
  let base = normalize_dep_sync_output_dir(base_dir)
  let safe_name = js_sanitize_dep_sync_name(dependency_name)
  if base.is_empty() {
    safe_name
  } else {
    base + "/" + safe_name
  }
}

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

///|
fn parse_wkg_sync_cli_result(raw : String) -> Result[String, String] {
  let parts : Array[String] = []
  for part in raw.split("\t") {
    parts.push(part.to_string())
  }
  if parts.length() > 0 && parts[0] == "ok" {
    return Ok(if parts.length() >= 2 { parts[1] } else { "" })
  }
  let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
  let detail = if parts.length() >= 3 { parts[2] } else { raw }
  Err(stage + ": " + detail)
}

///|
fn sync_dep_entry_with_wkg_cli(
  host : String,
  spec : WasmDependencySpec,
  output_dir : String,
) -> Result[String, String] {
  let package_spec = build_verify_package_spec(spec)
  let raw = js_sync_wkg_package_cli(package_spec, host, output_dir)
  parse_wkg_sync_cli_result(raw)
}

///|
fn sync_dep_spec_to_file_with_wkg_cli(
  host : String,
  spec : WasmDependencySpec,
  output_path : String,
) -> Result[String, String] {
  let package_spec = build_verify_package_spec(spec)
  let raw = js_sync_wkg_package_to_file_cli(package_spec, host, output_path)
  parse_wkg_sync_cli_result(raw)
}

///|
fn upsert_wasm_dependency_config_json(
  root : Json,
  dependency_name : String,
  resolved_url : String,
) -> Result[Json, String] {
  if dependency_name.is_empty() {
    return Err("dependency name must not be empty")
  }
  if parse_https_dependency_url(resolved_url) is None {
    return Err("invalid dependency url: " + resolved_url)
  }
  let root_object = match root {
    Json::Object(object) => object.copy()
    _ => return Err("config root must be object")
  }
  let deps = match root_object.get("deps") {
    Some(Json::Object(object)) => object.copy()
    Some(_) => return Err("config deps must be object")
    None => {}
  }
  deps[dependency_name] = Json::string(resolved_url)
  root_object["deps"] = Json::object(deps)
  Ok(Json::object(root_object))
}

///|
priv struct AddCommandOptions {
  config_path : String
  dependency_name : String
  resolved_url : String
  parsed : ParsedDependencyInput
  verify : Bool
}

///|
priv struct DepsVerifyCommandOptions {
  config_path : String
  fail_fast : Bool
}

///|
priv struct DepsSyncCommandOptions {
  config_path : String
  output_dir : String
  fail_fast : Bool
  verify : Bool
}

///|
fn parse_add_command_options(
  args : Array[String],
) -> Result[AddCommandOptions, String] {
  if args.length() < 3 {
    return Err("add requires <dep-spec>")
  }
  let mut config_path = "wite.config.jsonc"
  let mut dependency_name : String? = None
  let mut protocol_override : DependencyProtocol? = None
  let mut registry_host : String? = None
  let mut verify = false
  let positional : Array[String] = []
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "--config" {
      if i + 1 >= args.length() {
        return Err("missing path after --config")
      }
      config_path = args[i + 1]
      i += 2
      continue
    }
    if arg == "--name" {
      if i + 1 >= args.length() {
        return Err("missing name after --name")
      }
      dependency_name = Some(args[i + 1])
      i += 2
      continue
    }
    if arg == "--protocol" {
      if i + 1 >= args.length() {
        return Err("missing protocol after --protocol")
      }
      match parse_dependency_protocol(args[i + 1]) {
        Some(p) => protocol_override = Some(p)
        None => return Err("unknown protocol: " + args[i + 1])
      }
      i += 2
      continue
    }
    if arg == "--registry" {
      if i + 1 >= args.length() {
        return Err("missing registry after --registry")
      }
      registry_host = Some(args[i + 1])
      i += 2
      continue
    }
    if arg == "--verify" {
      verify = true
      i += 1
      continue
    }
    if arg == "--no-verify" {
      verify = false
      i += 1
      continue
    }
    match arg.strip_prefix("--config=") {
      Some(value) => {
        config_path = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--name=") {
      Some(value) => {
        dependency_name = Some(value.to_string())
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--protocol=") {
      Some(value) =>
        match parse_dependency_protocol(value.to_string()) {
          Some(p) => {
            protocol_override = Some(p)
            i += 1
            continue
          }
          None => return Err("unknown protocol: " + value.to_string())
        }
      None => ()
    }
    match arg.strip_prefix("--registry=") {
      Some(value) => {
        registry_host = Some(value.to_string())
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--verify=") {
      Some(value) => {
        match value.to_lower() {
          "true" | "1" | "yes" | "on" => verify = true
          "false" | "0" | "no" | "off" => verify = false
          _ => return Err("invalid value for --verify: " + value.to_string())
        }
        i += 1
        continue
      }
      None => ()
    }
    if arg.has_prefix("--") {
      return Err("unknown add option: " + arg)
    }
    positional.push(arg)
    i += 1
  }
  if positional.length() == 0 {
    return Err("add requires <dep-spec>")
  }
  if positional.length() > 1 {
    return Err("unexpected add argument: " + positional[1])
  }
  let fallback_protocol = match protocol_override {
    Some(p) => p
    None => DependencyProtocol::Wkg
  }
  let parsed = match parse_dependency_input(positional[0], fallback_protocol) {
    Some(value) => value
    None => return Err("invalid dep spec: " + positional[0])
  }
  let host = normalize_dependency_host(
    match registry_host {
      Some(raw) => raw
      None =>
        match parsed.host {
          Some(host) => host
          None => default_dependency_host(parsed.protocol)
        }
    },
  )
  if host.is_empty() || not(@oci_types.validate_hostname(host)) {
    return Err("invalid registry host: " + host)
  }
  let resolved_url = build_dep_url(host, parsed.spec)
  let resolved_name = match dependency_name {
    Some(name) => {
      if name.is_empty() {
        return Err("dependency name must not be empty")
      }
      name
    }
    None => normalize_dep_key(parsed)
  }
  Ok({
    config_path,
    dependency_name: resolved_name,
    resolved_url,
    parsed,
    verify,
  })
}

///|
async fn verify_dependency_on_oci_backend(
  backend : @oci_types.OciConfig,
  spec : WasmDependencySpec,
) -> Result[String, String] {
  let package_text = spec.ns + ":" + spec.name
  let package_name = match @oci_types.PackageName::parse(package_text) {
    Some(pkg) => pkg
    None => return Err("invalid package spec for verification: " + package_text)
  }
  let client = @oci_client.OciClient::new(
    backend.registry,
    backend.namespace_prefix,
    package_name,
  ) catch {
    e =>
      return Err(
        "oci client init failed for " + backend.registry + ": " + e.to_string(),
      )
  }
  if spec.version == "latest" {
    let tags = client.list_tags(package_name) catch {
      e =>
        return Err(
          "oci tag lookup failed for " + package_text + ": " + e.to_string(),
        )
    }
    if tags.length() == 0 {
      return Err("oci package has no tags: " + package_text)
    }
    return Ok(
      "oci registry=" +
      backend.registry +
      " namespace_prefix=" +
      backend.namespace_prefix +
      " tags=" +
      tags.length().to_string(),
    )
  }
  let _manifest = client.get_manifest(package_name, spec.version) catch {
    e =>
      return Err(
        "oci manifest lookup failed for " +
        package_text +
        "@" +
        spec.version +
        ": " +
        e.to_string(),
      )
  }
  Ok(
    "oci registry=" +
    backend.registry +
    " namespace_prefix=" +
    backend.namespace_prefix +
    " package=" +
    package_text +
    "@" +
    spec.version,
  )
}

///|
fn verify_dependency_on_warg_backend(
  backend : @oci_types.WargConfig,
  host : String,
  spec : WasmDependencySpec,
) -> Result[String, String] {
  let package_spec = build_verify_package_spec(spec)
  let verify_raw = js_verify_wkg_package_cli(package_spec, host)
  match parse_wkg_verify_cli_result(verify_raw) {
    Ok(_) =>
      Ok(
        "warg url=" +
        backend.url +
        " registry=" +
        host +
        " package=" +
        package_spec,
      )
    Err(msg) =>
      Err(
        "warg package lookup failed for " +
        package_spec +
        " via " +
        host +
        ": " +
        msg,
      )
  }
}

///|
async fn verify_add_dependency(
  options : AddCommandOptions,
) -> Result[String, String] {
  verify_dependency_url(options.resolved_url, options.parsed.protocol)
}

///|
async fn verify_dependency_url(
  resolved_url : String,
  protocol : DependencyProtocol,
) -> Result[String, String] {
  let (host, spec) = match parse_https_dependency_url(resolved_url) {
    Some(value) => value
    None => return Err("invalid resolved dependency url: " + resolved_url)
  }
  let registry_config = @oci_discovery.fetch_registry_config(host) catch {
    e =>
      return Err("registry discovery failed for " + host + ": " + e.to_string())
  }
  let backend = match resolve_verify_backend(protocol, registry_config) {
    Ok(value) => value
    Err(msg) =>
      return Err(
        msg +
        " (host=" +
        host +
        ", protocol=" +
        dependency_protocol_name(protocol) +
        ")",
      )
  }
  match backend {
    VerifyBackend::Oci(oci) => verify_dependency_on_oci_backend(oci, spec)
    VerifyBackend::Warg(warg) =>
      verify_dependency_on_warg_backend(warg, host, spec)
  }
}

///|
fn parse_deps_verify_command_options(
  args : Array[String],
) -> Result[DepsVerifyCommandOptions, String] {
  if args.length() < 3 || args[2] != "verify" {
    return Err("deps requires subcommand 'verify'")
  }
  let mut config_path = "wite.config.jsonc"
  let mut fail_fast = false
  let mut i = 3
  while i < args.length() {
    let arg = args[i]
    if arg == "--config" {
      if i + 1 >= args.length() {
        return Err("missing path after --config")
      }
      config_path = args[i + 1]
      i += 2
      continue
    }
    if arg == "--fail-fast" {
      fail_fast = true
      i += 1
      continue
    }
    if arg == "--no-fail-fast" {
      fail_fast = false
      i += 1
      continue
    }
    match arg.strip_prefix("--config=") {
      Some(value) => {
        config_path = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    if arg.has_prefix("--") {
      return Err("unknown deps verify option: " + arg)
    }
    return Err("unexpected deps verify argument: " + arg)
  }
  Ok({ config_path, fail_fast })
}

///|
fn parse_deps_sync_command_options(
  args : Array[String],
) -> Result[DepsSyncCommandOptions, String] {
  if args.length() < 3 || args[2] != "sync" {
    return Err("deps requires subcommand 'sync'")
  }
  let mut config_path = "wite.config.jsonc"
  let mut output_dir = "deps"
  let mut fail_fast = false
  let mut verify = false
  let mut i = 3
  while i < args.length() {
    let arg = args[i]
    if arg == "--config" {
      if i + 1 >= args.length() {
        return Err("missing path after --config")
      }
      config_path = args[i + 1]
      i += 2
      continue
    }
    if arg == "--dir" || arg == "--output-dir" || arg == "--out-dir" {
      if i + 1 >= args.length() {
        return Err("missing path after " + arg)
      }
      output_dir = args[i + 1]
      i += 2
      continue
    }
    if arg == "--fail-fast" {
      fail_fast = true
      i += 1
      continue
    }
    if arg == "--no-fail-fast" {
      fail_fast = false
      i += 1
      continue
    }
    if arg == "--verify" {
      verify = true
      i += 1
      continue
    }
    if arg == "--no-verify" {
      verify = false
      i += 1
      continue
    }
    match arg.strip_prefix("--config=") {
      Some(value) => {
        config_path = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--dir=") {
      Some(value) => {
        output_dir = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--output-dir=") {
      Some(value) => {
        output_dir = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--out-dir=") {
      Some(value) => {
        output_dir = value.to_string()
        i += 1
        continue
      }
      None => ()
    }
    if arg.has_prefix("--") {
      return Err("unknown deps sync option: " + arg)
    }
    return Err("unexpected deps sync argument: " + arg)
  }
  let normalized_output_dir = normalize_dep_sync_output_dir(output_dir)
  if normalized_output_dir.is_empty() {
    return Err("deps sync output dir must not be empty")
  }
  Ok({ config_path, output_dir: normalized_output_dir, fail_fast, verify })
}

///|
fn compare_dep_config_entry(a : DepConfigEntry, b : DepConfigEntry) -> Int {
  a.name.compare(b.name)
}

///|
fn collect_dep_entries_from_config_json(
  root : Json,
) -> Result[Array[DepConfigEntry], String] {
  let root_object = match root {
    Json::Object(object) => object
    _ => return Err("config root must be object")
  }
  let deps = match root_object.get("deps") {
    Some(Json::Object(object)) => object
    Some(_) => return Err("config deps must be object")
    None => return Ok([])
  }
  let out : Array[DepConfigEntry] = []
  let mut invalid_key : String? = None
  deps.each((name, value) => match value {
    Json::String(url) => out.push({ name, url })
    _ => if invalid_key is None { invalid_key = Some(name) }
  })
  match invalid_key {
    Some(name) => Err("config deps entry must be string: " + name)
    None => {
      out.sort_by(compare_dep_config_entry)
      Ok(out)
    }
  }
}

///|
fn load_config_json_for_add(path : String) -> Json {
  if not(@fs.path_exists(path)) {
    return Json::object({})
  }
  let text = @fs.read_file_to_string(path) catch {
    e => {
      println(
        "failed to read config file: " + path + " (" + e.to_string() + ")",
      )
      exit_process(1)
      "{}"
    }
  }
  @json5.parse(text) catch {
    e => {
      println(
        "failed to parse config file: " + path + " (" + e.to_string() + ")",
      )
      exit_process(1)
      Json::object({})
    }
  }
}

///|
fn write_config_json_for_add(path : String, config : Json) -> Unit {
  let text = config.stringify(indent=2) + "\n"
  @fs.write_string_to_file(path, text) catch {
    e => {
      println(
        "failed to write config file: " + path + " (" + e.to_string() + ")",
      )
      exit_process(1)
    }
  }
}

///|
fn path_dirname(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let index = match (slash, backslash) {
    (Some(a), Some(b)) => if a >= b { Some(a) } else { Some(b) }
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match index {
    Some(i) if i > 0 => path[:i].to_string() catch { _ => "." }
    Some(_) => "."
    None => "."
  }
}

///|
fn parse_wac_package_name(pkg_name : String) -> WasmDependencySpec? {
  match @wite_bundle.parse_wac_package_name(pkg_name) {
    Some((ns, name)) => Some({ ns, name, version: "latest" })
    None => None
  }
}

///|
fn build_wac_dep_target_path(
  base_dir : String,
  spec : WasmDependencySpec,
) -> String {
  @wite_bundle.build_wac_dep_target_path(base_dir, spec.ns, spec.name)
}

///|
fn collect_wac_new_package_names(
  source : String,
) -> Result[Array[String], String] {
  @wite_bundle.collect_wac_new_package_names(source)
}

///|
pub struct WacConfiguredDependency {
  url : String
  host : String
  spec : WasmDependencySpec
}

///|
fn build_wac_dependency_lookup(
  entries : Array[DepConfigEntry],
) -> Result[Map[String, WacConfiguredDependency], String] {
  let lookup : Map[String, WacConfiguredDependency] = {}
  for entry in entries {
    let (host, spec) = match parse_https_dependency_url(entry.url) {
      Some(v) => v
      None => return Err("invalid dependency url: " + entry.url)
    }
    let pkg_name = spec.ns + ":" + spec.name
    match lookup.get(pkg_name) {
      Some(prev) =>
        if prev.url != entry.url {
          return Err(
            "duplicate dependency package with different urls: " +
            pkg_name +
            " (" +
            prev.url +
            " vs " +
            entry.url +
            ")",
          )
        }
      None => lookup.set(pkg_name, { url: entry.url, host, spec })
    }
  }
  Ok(lookup)
}

///|
pub fn materialize_wac_dependencies_from_config(
  config_path : String,
  wac_path : String,
  best_effort : Bool,
) -> Result[UInt, String] {
  let config_json = load_config_json_for_add(config_path)
  let entries = match collect_dep_entries_from_config_json(config_json) {
    Ok(v) => v
    Err(msg) => return Err("failed to read deps: " + msg)
  }
  if entries.length() == 0 {
    return Ok(0U)
  }
  let source = @fs.read_file_to_string(wac_path) catch {
    e =>
      return Err(
        "failed to read wac file: " + wac_path + " (" + e.to_string() + ")",
      )
  }
  let required_packages = match collect_wac_new_package_names(source) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if required_packages.length() == 0 {
    return Ok(0U)
  }
  let lookup = match build_wac_dependency_lookup(entries) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let base_dir = path_dirname(wac_path)
  let mut synced = 0U
  for pkg_name in required_packages {
    let dep = lookup.get(pkg_name)
    match dep {
      Some(value) => {
        let target_path = build_wac_dep_target_path(base_dir, value.spec)
        let synced_path = sync_dep_spec_to_file_with_wkg_cli(
          value.host,
          value.spec,
          target_path,
        )
        match synced_path {
          Ok(path) => {
            synced += 1U
            println("materialized wac dep: " + pkg_name)
            println("  source: " + value.url)
            println("  output: " + path)
          }
          Err(msg) =>
            if best_effort {
              println("warn: failed to materialize wac dep: " + pkg_name)
              println("  reason: " + msg)
            } else {
              return Err(
                "failed to materialize wac dep " + pkg_name + ": " + msg,
              )
            }
        }
      }
      None => {
        let spec = parse_wac_package_name(pkg_name)
        match spec {
          Some(parsed) => {
            let target_path = build_wac_dep_target_path(base_dir, parsed)
            if @fs.path_exists(target_path) {
              println("use local wac dep: " + pkg_name)
              println("  path: " + target_path)
            } else if best_effort {
              println("warn: missing wac dep in config: " + pkg_name)
              println("  expected: " + target_path)
            } else {
              return Err(
                "missing wac dep in config: " +
                pkg_name +
                " (expected " +
                target_path +
                ")",
              )
            }
          }
          None =>
            if best_effort {
              println("warn: invalid wac package name: " + pkg_name)
            } else {
              return Err("invalid wac package name: " + pkg_name)
            }
        }
      }
    }
  }
  Ok(synced)
}

///|
pub fn config_has_dep_entries_or_exit(config_path : String) -> Bool {
  let config_json = load_config_json_for_add(config_path)
  let entries = match collect_dep_entries_from_config_json(config_json) {
    Ok(value) => value
    Err(msg) => {
      println("failed to read deps: " + msg)
      exit_process(1)
      []
    }
  }
  entries.length() > 0
}

///|
pub fn noop_usage_printer() -> Unit {
  ()
}

///|
pub async fn run_add_command(
  args : Array[String],
  usage_printer : () -> Unit,
) -> Unit {
  let options = match parse_add_command_options(args) {
    Ok(value) => value
    Err(msg) => {
      println(msg)
      usage_printer()
      exit_process(1)
      AddCommandOptions::{
        config_path: "wite.config.jsonc",
        dependency_name: "example/example",
        resolved_url: "https://wa.dev/wasi:http",
        parsed: {
          protocol: DependencyProtocol::Wkg,
          spec: { ns: "wasi", name: "http", version: "latest" },
          host: Some("wa.dev"),
        },
        verify: false,
      }
    }
  }
  if options.verify {
    let verify_result = match verify_add_dependency(options) {
      Ok(msg) => msg
      Err(msg) => {
        println("verify failed: " + msg)
        exit_process(1)
        ""
      }
    }
    println("verified dep: " + options.dependency_name)
    println("  verify: " + verify_result)
  }
  let current = load_config_json_for_add(options.config_path)
  let updated = match
    upsert_wasm_dependency_config_json(
      current,
      options.dependency_name,
      options.resolved_url,
    ) {
    Ok(value) => value
    Err(msg) => {
      println("failed to update deps: " + msg)
      exit_process(1)
      Json::object({})
    }
  }
  write_config_json_for_add(options.config_path, updated)
  println("added dep: " + options.dependency_name)
  println(
    "  package: " + options.parsed.spec.ns + ":" + options.parsed.spec.name,
  )
  println("  protocol: " + dependency_protocol_name(options.parsed.protocol))
  println("  url: " + options.resolved_url)
  println("  config: " + options.config_path)
}

///|
async fn run_deps_verify_command(
  args : Array[String],
  usage_printer : () -> Unit,
) -> Unit {
  let options = match parse_deps_verify_command_options(args) {
    Ok(value) => value
    Err(msg) => {
      println(msg)
      usage_printer()
      exit_process(1)
      { config_path: "wite.config.jsonc", fail_fast: false }
    }
  }
  let config = load_config_json_for_add(options.config_path)
  let entries = match collect_dep_entries_from_config_json(config) {
    Ok(value) => value
    Err(msg) => {
      println("failed to read deps: " + msg)
      exit_process(1)
      []
    }
  }
  if entries.length() == 0 {
    println("no deps found in " + options.config_path)
    return
  }
  println("deps verify: " + entries.length().to_string() + " entries")
  let failures : Array[String] = []
  for entry in entries {
    let verified = verify_dependency_url(entry.url, DependencyProtocol::Wkg)
    match verified {
      Ok(msg) => {
        println("ok: " + entry.name)
        println("  url: " + entry.url)
        println("  verify: " + msg)
      }
      Err(msg) => {
        println("fail: " + entry.name)
        println("  url: " + entry.url)
        println("  reason: " + msg)
        failures.push(entry.name + ": " + msg)
        if options.fail_fast {
          break
        }
      }
    }
  }
  if failures.length() > 0 {
    println(
      "deps verify failed: " +
      failures.length().to_string() +
      "/" +
      entries.length().to_string(),
    )
    for failure in failures {
      println("  - " + failure)
    }
    exit_process(1)
  }
  println(
    "deps verify succeeded: " +
    entries.length().to_string() +
    "/" +
    entries.length().to_string(),
  )
}

///|
fn validate_dep_sync_targets(
  entries : Array[DepConfigEntry],
  output_dir : String,
) -> Result[Unit, String] {
  let seen : Map[String, String] = {}
  for entry in entries {
    let target = build_dep_sync_target_dir(output_dir, entry.name)
    match seen.get(target) {
      Some(prev_name) =>
        return Err(
          "deps sync target collision: " +
          prev_name +
          " and " +
          entry.name +
          " -> " +
          target,
        )
      None => seen.set(target, entry.name)
    }
  }
  Ok(())
}

///|
pub async fn run_deps_sync_command(
  args : Array[String],
  usage_printer : () -> Unit,
) -> Unit {
  let options = match parse_deps_sync_command_options(args) {
    Ok(value) => value
    Err(msg) => {
      println(msg)
      usage_printer()
      exit_process(1)
      {
        config_path: "wite.config.jsonc",
        output_dir: "deps",
        fail_fast: false,
        verify: false,
      }
    }
  }
  let config = load_config_json_for_add(options.config_path)
  let entries = match collect_dep_entries_from_config_json(config) {
    Ok(value) => value
    Err(msg) => {
      println("failed to read deps: " + msg)
      exit_process(1)
      []
    }
  }
  if entries.length() == 0 {
    println("no deps found in " + options.config_path)
    return
  }
  match validate_dep_sync_targets(entries, options.output_dir) {
    Ok(_) => ()
    Err(msg) => {
      println(msg)
      exit_process(1)
    }
  }
  println(
    "deps sync: " +
    entries.length().to_string() +
    " entries -> " +
    options.output_dir,
  )
  let failures : Array[String] = []
  let mut synced = 0
  for entry in entries {
    let (host, spec) = match parse_https_dependency_url(entry.url) {
      Some(value) => value
      None => {
        let msg = "invalid dependency url: " + entry.url
        println("fail: " + entry.name)
        println("  url: " + entry.url)
        println("  reason: " + msg)
        failures.push(entry.name + ": " + msg)
        if options.fail_fast {
          break
        }
        continue
      }
    }
    if options.verify {
      let verified = verify_dependency_url(entry.url, DependencyProtocol::Wkg)
      match verified {
        Ok(msg) => {
          println("verify ok: " + entry.name)
          println("  verify: " + msg)
        }
        Err(msg) => {
          println("verify fail: " + entry.name)
          println("  url: " + entry.url)
          println("  reason: " + msg)
          failures.push(entry.name + ": " + msg)
          if options.fail_fast {
            break
          }
          continue
        }
      }
    }
    let target_dir = build_dep_sync_target_dir(options.output_dir, entry.name)
    let sync_result = sync_dep_entry_with_wkg_cli(host, spec, target_dir)
    match sync_result {
      Ok(output) => {
        synced += 1
        println("ok: " + entry.name)
        println("  url: " + entry.url)
        println("  output: " + output)
      }
      Err(msg) => {
        println("fail: " + entry.name)
        println("  url: " + entry.url)
        println("  output: " + target_dir)
        println("  reason: " + msg)
        failures.push(entry.name + ": " + msg)
        if options.fail_fast {
          break
        }
      }
    }
  }
  if failures.length() > 0 {
    println(
      "deps sync failed: " +
      failures.length().to_string() +
      "/" +
      entries.length().to_string(),
    )
    for failure in failures {
      println("  - " + failure)
    }
    exit_process(1)
  }
  println(
    "deps sync succeeded: " +
    synced.to_string() +
    "/" +
    entries.length().to_string(),
  )
}

///|
pub async fn run_deps_command(
  args : Array[String],
  usage_printer : () -> Unit,
) -> Unit {
  if args.length() < 3 {
    println("deps requires subcommand")
    usage_printer()
    exit_process(1)
    return
  }
  match args[2] {
    "verify" => run_deps_verify_command(args, usage_printer)
    "sync" => run_deps_sync_command(args, usage_printer)
    _ => {
      println("unknown deps subcommand: " + args[2])
      usage_printer()
      exit_process(1)
    }
  }
}
