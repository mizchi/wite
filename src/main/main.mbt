///|
fn print_usage() -> Unit {
  println("wite commands:")
  println("  init [--force]")
  println("  new [--moonbit|--rust] [--force]")
  println(
    "  analyze <core.wasm> [--config=<path>|--config <path>|--no-config] [--kind=auto|core|component] [--view=summary|deep|functions|blocks|callgraph|host|pipeline|dce|keep|retain] [--limit=<n>] [--diff-limit=<n>] [--opt-level=O1] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println(
    "  build [entry.(wac|wasm)] [--config=<path>|--config <path>|--no-config] [--kind=auto|core|component] [--out=<path>|-o <path>] [--best-effort] [--no-compose-dce] [-O|-O0|-O1|-O2|-O3|-O4|-Os|-Oz] [--strip-all-custom] [--strip-debug] [--strip-dwarf] [--strip-target-features] [--keep-custom=<name>] [--exclude=<name>] [--no-peephole] [--no-vacuum] [--no-merge-blocks] [--no-remove-unused-brs] [--converge] [--rounds=<n>] [--dce-apply] [--dfe-apply] [--msf-apply] [--rume-apply] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode] [--verbose]",
  )
  println(
    "  diff <left.wasm> [right.wasm] [--view=function|section|block] [--limit=<n>] [--baseline=wasm-opt] [--wasm-opt-bin=<path>] [--baseline-opt-level=Oz]",
  )
  println(
    "  add <dep-spec> [--protocol=wkg|warg|oci] [--registry=<host>] [--name=<id>] [--config=<path>] [--verify]  # dep-spec: wkg:mizchi/markdown | mizchi/markdown | wasi:http | https://wa.dev/mizchi:tmgrammar",
  )
  println("  deps verify [--config=<path>|--config <path>] [--fail-fast]")
  println(
    "  deps sync [--config=<path>|--config <path>] [--dir=<path>|--dir <path>] [--verify] [--fail-fast]",
  )
  println("  analyze-host <core.wasm> [limit]")
  println("  analyze-opt <core.wasm> [opt-level] [diff-limit]")
  println("  deep-analyze <core.wasm> [limit]")
  println(
    "  profile <core.wasm> [--config=<path>|--config <path>|--no-config] [--kind=auto|core|component]",
  )
  println("  top-functions <core.wasm> [limit]")
  println("  function-gap <left.wasm> <right.wasm> [limit]")
  println("  block-sizes <core.wasm> [limit]")
  println("  callgraph <core.wasm> [limit]")
  println(
    "  keep-reasons <core.wasm> [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println(
    "  retain-path <core.wasm> [limit] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println("  dce-report <core.wasm> [limit]")
  println(
    "  runtime-profile <core.wasm> [iterations] [--scenario=<export>[:arg1,arg2,...]]",
  )
  println(
    "  hot-size <core.wasm> [iterations] [limit] [--scenario=<export>[:arg1,arg2,...]]",
  )
  println(
    "  optimize <input.wasm> <output.wasm> [--kind=auto|core|component] [-O|-O0|-O1|-O2|-O3|-O4|-Os|-Oz] [--optimize-level=<n>|-ol <n>] [--shrink-level=<n>|-s <n>] [--all-features|--enable-*|--disable-*] [--strip|--strip-all-custom|--strip-debug|--strip-dwarf|--strip-producers|--strip-target-features] [--keep-custom=<name>] [--exclude=<name>] [--no-peephole|--peephole] [--no-vacuum|--vacuum] [--no-merge-blocks|--merge-blocks] [--no-remove-unused-brs|--remove-unused-brs] [--converge|-c] [--rounds=<n>|--rounds <n>] [--dce|--duplicate-function-elimination|--merge-similar-functions|--remove-unused-module-elements] [--dce-apply|--dfe-apply|--msf-apply|--rume-apply] [--closed-world|-cw] [--closed-world-root=<export-name>] [--safe-mode] [--debuginfo|-g] [--verbose]",
  )
  println("  component-profile <component.wasm>")
  println("  component-top-functions <component.wasm> [limit]")
  println("  component-callgraph <component.wasm> [limit]")
  println(
    "  component-dce-kpi <component.wasm> [wit-dir] [--exclude=<name>] [--closed-world-root=<export-name>] [--safe-mode] [--verbose]",
  )
  println("  contract <component.wasm> <wit-dir>")
  println("  root-policy <component.wasm> [wit-dir] [--exclude=<name>]")
}

///|
priv enum AnalyzeView {
  Summary
  Deep
  Functions
  Blocks
  Callgraph
  Host
  Pipeline
  Dce
  Keep
  Retain
}

///|
pub enum BinaryKind {
  Auto
  Core
  Component
}

///|
fn parse_binary_kind(name : String) -> BinaryKind? {
  match name.to_lower() {
    "auto" => Some(BinaryKind::Auto)
    "core" => Some(BinaryKind::Core)
    "component" => Some(BinaryKind::Component)
    _ => None
  }
}

///|
fn binary_kind_name(kind : BinaryKind) -> String {
  match kind {
    BinaryKind::Auto => "auto"
    BinaryKind::Core => "core"
    BinaryKind::Component => "component"
  }
}

///|
fn from_config_binary_kind(kind : @wite_config.BinaryKind) -> BinaryKind {
  match kind {
    @wite_config.BinaryKind::Auto => BinaryKind::Auto
    @wite_config.BinaryKind::Core => BinaryKind::Core
    @wite_config.BinaryKind::Component => BinaryKind::Component
  }
}

///|
fn parse_binary_kind_or_exit(value : String, label : String) -> BinaryKind {
  match parse_binary_kind(value) {
    Some(kind) => kind
    None => {
      println("invalid " + label + ": " + value)
      @sys.exit(1)
      BinaryKind::Auto
    }
  }
}

///|
priv struct BinaryKindFlagParseResult {
  kind : BinaryKind
  flags : Array[String]
}

///|
fn extract_binary_kind_flags(
  flags : Array[String],
  default_kind : BinaryKind,
  label : String,
) -> BinaryKindFlagParseResult {
  let out : Array[String] = []
  let mut kind = default_kind
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    if flag == "--kind" {
      if i + 1 >= flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(flags[i + 1], label)
      i += 2
      continue
    }
    match flag.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), label)
        i += 1
        continue
      }
      None => ()
    }
    out.push(flag)
    i += 1
  }
  { kind, flags: out }
}

///|
fn analyze_view_supports_kind(view : AnalyzeView, kind : BinaryKind) -> Bool {
  match kind {
    BinaryKind::Auto | BinaryKind::Core => true
    BinaryKind::Component =>
      match view {
        AnalyzeView::Summary
        | AnalyzeView::Functions
        | AnalyzeView::Callgraph => true
        _ => false
      }
  }
}

///|
priv enum DiffView {
  Function
  Section
  Block
}

///|
fn parse_diff_view(name : String) -> DiffView? {
  match name {
    "function" => Some(DiffView::Function)
    "section" => Some(DiffView::Section)
    "block" => Some(DiffView::Block)
    _ => None
  }
}

///|
priv enum DiffBaseline {
  WasmOpt
}

///|
fn parse_diff_baseline(name : String) -> DiffBaseline? {
  match name {
    "wasm-opt" => Some(DiffBaseline::WasmOpt)
    _ => None
  }
}

///|
fn parse_analyze_view(name : String) -> AnalyzeView? {
  match name {
    "summary" => Some(AnalyzeView::Summary)
    "deep" => Some(AnalyzeView::Deep)
    "functions" => Some(AnalyzeView::Functions)
    "top-functions" => Some(AnalyzeView::Functions)
    "blocks" => Some(AnalyzeView::Blocks)
    "block-sizes" => Some(AnalyzeView::Blocks)
    "callgraph" => Some(AnalyzeView::Callgraph)
    "host" => Some(AnalyzeView::Host)
    "pipeline" => Some(AnalyzeView::Pipeline)
    "dce" => Some(AnalyzeView::Dce)
    "keep" => Some(AnalyzeView::Keep)
    "retain" => Some(AnalyzeView::Retain)
    _ => None
  }
}

///|
fn normalize_opt_level_token(token : String) -> String {
  if token.has_prefix("-O") {
    token
  } else if token.has_prefix("O") {
    "-".to_string() + token
  } else {
    token
  }
}

///|
fn parse_opt_level_or_exit(token : String) -> @wite.OptimizeConfig {
  let normalized = normalize_opt_level_token(token)
  match @wite.optimize_config_from_opt_level(normalized) {
    Some(config) => config
    None => {
      println("invalid opt-level: " + token)
      @sys.exit(1)
      @wite.OptimizeConfig::o1()
    }
  }
}

///|
fn replace_suffix(text : String, from : String, to : String) -> String {
  if not(text.has_suffix(from)) {
    return text + to
  }
  let prefix = text[:text.length() - from.length()].to_string() catch {
    _ => text.to_string()
  }
  prefix + to
}

///|
fn derive_build_output_path(input_path : String) -> String {
  if input_path.has_suffix(".wac") {
    replace_suffix(input_path, ".wac", ".wasm")
  } else if input_path.has_suffix(".wasm") {
    replace_suffix(input_path, ".wasm", ".min.wasm")
  } else {
    input_path + ".wasm"
  }
}

///|
fn derive_implicit_build_output_path(input_path : String) -> String {
  if input_path == "main.wac" {
    "composed.wasm"
  } else {
    derive_build_output_path(input_path)
  }
}

///|
fn path_dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(index) =>
      if index == 0 {
        "/"
      } else {
        path[:index].to_string() catch {
          _ => "."
        }
      }
    None => "."
  }
}

///|
priv struct BuildInputResolution {
  input_path : String
  raw_flags : Array[String]
  explicit_input : Bool
}

///|
priv enum NewTemplateKind {
  Moonbit
  Rust
}

///|
priv struct NewCommandOptions {
  force : Bool
  template : NewTemplateKind
}

///|
fn pick_default_build_input_path(
  has_main_wac : Bool,
  has_main_wasm : Bool,
) -> String? {
  if has_main_wac {
    Some("main.wac")
  } else if has_main_wasm {
    Some("main.wasm")
  } else {
    None
  }
}

///|
fn resolve_build_input_from_args(
  args : Array[String],
  default_input : String?,
) -> Result[BuildInputResolution, String] {
  if args.length() < 3 {
    return match default_input {
      Some(input_path) =>
        Ok({ input_path, raw_flags: [], explicit_input: false })
      None =>
        Err("build requires entry.(wac|wasm) or main.wac/main.wasm in cwd")
    }
  }
  let token = args[2]
  if token.has_prefix("-") {
    return match default_input {
      Some(input_path) => {
        let raw_flags : Array[String] = []
        for i in 2..<args.length() {
          raw_flags.push(args[i])
        }
        Ok({ input_path, raw_flags, explicit_input: false })
      }
      None =>
        Err("build requires entry.(wac|wasm) or main.wac/main.wasm in cwd")
    }
  }
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  Ok({ input_path: token, raw_flags, explicit_input: true })
}

///|
fn parse_new_command_options(
  args : Array[String],
) -> Result[NewCommandOptions, String] {
  let mut force = false
  let mut template : NewTemplateKind? = None
  for i in 2..<args.length() {
    let arg = args[i]
    if arg == "--force" {
      force = true
      continue
    }
    if arg == "--moonbit" {
      match template {
        Some(NewTemplateKind::Rust) =>
          return Err("conflicting new template flags: --moonbit and --rust")
        Some(NewTemplateKind::Moonbit) => ()
        None => template = Some(NewTemplateKind::Moonbit)
      }
      continue
    }
    if arg == "--rust" {
      match template {
        Some(NewTemplateKind::Moonbit) =>
          return Err("conflicting new template flags: --moonbit and --rust")
        Some(NewTemplateKind::Rust) => ()
        None => template = Some(NewTemplateKind::Rust)
      }
      continue
    }
    return Err("unknown new option: " + arg)
  }
  Ok({
    force,
    template: match template {
      Some(v) => v
      None => NewTemplateKind::Moonbit
    },
  })
}

///|
fn init_wite_config_template_text() -> String {
  let template =
    #|{
    #|  "build": { "kind": "auto", "flags": ["-Oz"] },
    #|  "analyze": { "kind": "core", "flags": ["--view=summary"] },
    #|  "profile": { "kind": "auto", "flags": [] },
    #|  "deps": {}
    #|}
    #|
  template
}

///|
fn init_main_wac_template_text() -> String {
  let template =
    #|package app:composition;
    #|
    #|// Add dependencies:
    #|//   wite add dep:a
    #|//   wite add dep:b
    #|// Then edit this file and wire imports/exports for your components.
    #|let a = new dep:a {};
    #|let b = new dep:b {};
    #|
    #|export a;
    #|export b;
    #|
  template
}

///|
fn new_moonbit_moon_mod_template_text() -> String {
  let template =
    #|{
    #|  "name": "app/moonbit-guest",
    #|  "version": "0.1.0"
    #|}
    #|
  template
}

///|
fn new_moonbit_moon_pkg_template_text() -> String {
  "\n"
}

///|
fn new_moonbit_guest_mbt_template_text() -> String {
  let template =
    #|pub fn greet() -> String {
    #|  "hello from moonbit guest"
    #|}
    #|
  template
}

///|
fn new_moonbit_readme_template_text() -> String {
  let template =
    #|# MoonBit guest template
    #|
    #|Build:
    #|```bash
    #|moon build --target wasm
    #|```
    #|
  template
}

///|
fn new_rust_cargo_toml_template_text() -> String {
  let template =
    #|[package]
    #|name = "guest-rust"
    #|version = "0.1.0"
    #|edition = "2024"
    #|
    #|[package.metadata.component]
    #|package = "app:guest-rust"
    #|
    #|[package.metadata.component.dependencies]
    #|
    #|[dependencies]
    #|wit-bindgen-rt = { version = "0.44.0", features = ["bitflags"] }
    #|
  template
}

///|
fn new_rust_main_template_text() -> String {
  let template =
    #|fn main() {
    #|    println!("hello from rust guest");
    #|}
    #|
  template
}

///|
fn new_rust_readme_template_text() -> String {
  let template =
    #|# Rust guest template
    #|
    #|Build:
    #|```bash
    #|cargo component build
    #|```
    #|
  template
}

///|
priv struct NewTemplateFile {
  path : String
  content : String
}

///|
fn new_template_kind_name(template : NewTemplateKind) -> String {
  match template {
    NewTemplateKind::Moonbit => "moonbit"
    NewTemplateKind::Rust => "rust"
  }
}

///|
fn collect_new_template_files(
  template : NewTemplateKind,
) -> Array[NewTemplateFile] {
  let files : Array[NewTemplateFile] = [
    { path: "wite.config.jsonc", content: init_wite_config_template_text() },
    { path: "main.wac", content: init_main_wac_template_text() },
  ]
  match template {
    NewTemplateKind::Moonbit => {
      files.push({
        path: "guest/moonbit/moon.mod.json",
        content: new_moonbit_moon_mod_template_text(),
      })
      files.push({
        path: "guest/moonbit/moon.pkg",
        content: new_moonbit_moon_pkg_template_text(),
      })
      files.push({
        path: "guest/moonbit/guest.mbt",
        content: new_moonbit_guest_mbt_template_text(),
      })
      files.push({
        path: "guest/moonbit/README.md",
        content: new_moonbit_readme_template_text(),
      })
    }
    NewTemplateKind::Rust => {
      files.push({
        path: "guest/rust/Cargo.toml",
        content: new_rust_cargo_toml_template_text(),
      })
      files.push({
        path: "guest/rust/src/main.rs",
        content: new_rust_main_template_text(),
      })
      files.push({
        path: "guest/rust/README.md",
        content: new_rust_readme_template_text(),
      })
    }
  }
  files
}

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
fn write_init_file(path : String, content : String, force : Bool) -> Bool {
  if @fs.path_exists(path) && not(force) {
    return false
  }
  js_ensure_parent_dir_for_file(path)
  @fs.write_string_to_file(path, content) catch {
    e => {
      println("failed to write file: " + path + " (" + e.to_string() + ")")
      @sys.exit(1)
    }
  }
  true
}

///|
fn run_new_command(args : Array[String]) -> Unit {
  let options = match parse_new_command_options(args) {
    Ok(v) => v
    Err(msg) => {
      println(msg)
      print_usage()
      @sys.exit(1)
      { force: false, template: NewTemplateKind::Moonbit }
    }
  }
  let files = collect_new_template_files(options.template)
  for file in files {
    let written = write_init_file(file.path, file.content, options.force)
    if written {
      println("created: " + file.path)
    } else {
      println("kept: " + file.path)
    }
  }
  let template_name = new_template_kind_name(options.template)
  println("template: " + template_name)
  println("next:")
  match options.template {
    NewTemplateKind::Moonbit => {
      println("  (cd guest/moonbit && moon build --target wasm)")
      println("  # edit guest/moonbit/guest.mbt")
      println("  # edit main.wac and wire guest exports")
      println("  wite build")
    }
    NewTemplateKind::Rust => {
      println("  (cd guest/rust && cargo component build)")
      println("  # edit guest/rust/src/main.rs")
      println("  # edit main.wac and wire guest exports")
      println("  wite build")
    }
  }
}

///|
fn run_init_command(args : Array[String]) -> Unit {
  let mut force = false
  for i in 2..<args.length() {
    let arg = args[i]
    if arg == "--force" {
      force = true
      continue
    }
    println("unknown init option: " + arg)
    print_usage()
    @sys.exit(1)
  }
  let config_path = "wite.config.jsonc"
  let wac_path = "main.wac"
  let config_written = write_init_file(
    config_path,
    init_wite_config_template_text(),
    force,
  )
  let wac_written = write_init_file(
    wac_path,
    init_main_wac_template_text(),
    force,
  )
  if config_written {
    println("created: " + config_path)
  } else {
    println("kept: " + config_path)
  }
  if wac_written {
    println("created: " + wac_path)
  } else {
    println("kept: " + wac_path)
  }
  println("next:")
  println("  wite add dep:a")
  println("  wite add dep:b")
  println("  # edit main.wac")
  println("  wite build")
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
fn parse_wac_package_name(pkg_name : String) -> WasmDependencySpec? {
  match @wite_bundle.parse_wac_package_name(pkg_name) {
    Some((ns, name)) => Some({ ns, name, version: "latest" })
    None => None
  }
}

///|
priv struct WacConfiguredDependency {
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
pub struct WiteConfigFile {
  build_flags : Array[String]
  analyze_flags : Array[String]
  profile_flags : Array[String]
  build_kind : BinaryKind
  analyze_kind : BinaryKind
  profile_kind : BinaryKind
}

///|
fn empty_wite_config_file() -> WiteConfigFile {
  {
    build_flags: [],
    analyze_flags: [],
    profile_flags: [],
    build_kind: BinaryKind::Auto,
    analyze_kind: BinaryKind::Auto,
    profile_kind: BinaryKind::Auto,
  }
}

///|
fn parse_json_string_array(
  json_value : Json,
  label : String,
) -> Result[Array[String], String] {
  match json_value {
    Array(values) => {
      let out : Array[String] = []
      for i in 0..<values.length() {
        match values[i] {
          String(value) => out.push(value)
          _ =>
            return Err(
              "config " + label + "[" + i.to_string() + "] must be string",
            )
        }
      }
      Ok(out)
    }
    _ => Err("config " + label + " must be string array")
  }
}

///|
fn parse_wite_config_section(
  json_value : Json,
  label : String,
) -> Result[(Array[String], BinaryKind), String] {
  match json_value {
    Array(_) =>
      match parse_json_string_array(json_value, label) {
        Ok(flags) => Ok((flags, BinaryKind::Auto))
        Err(msg) => Err(msg)
      }
    Object(object) => {
      let mut flags : Array[String] = []
      let mut kind = BinaryKind::Auto
      match object.get("flags") {
        Some(flags_value) =>
          match parse_json_string_array(flags_value, label + ".flags") {
            Ok(parsed) => flags = parsed
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      match object.get("kind") {
        Some(String(raw_kind)) =>
          match parse_binary_kind(raw_kind) {
            Some(parsed_kind) => kind = parsed_kind
            None => return Err("invalid config " + label + ".kind: " + raw_kind)
          }
        Some(_) => return Err("config " + label + ".kind must be string")
        None => ()
      }
      Ok((flags, kind))
    }
    _ => Err("config " + label + " must be array or object")
  }
}

///|
fn parse_wite_config_json(json_value : Json) -> Result[WiteConfigFile, String] {
  match json_value {
    Object(object) => {
      let mut build_flags : Array[String] = []
      let mut analyze_flags : Array[String] = []
      let mut profile_flags : Array[String] = []
      let mut build_kind = BinaryKind::Auto
      let mut analyze_kind = BinaryKind::Auto
      let mut profile_kind = BinaryKind::Auto
      match object.get("build") {
        Some(value) =>
          match parse_wite_config_section(value, "build") {
            Ok((flags, kind)) => {
              build_flags = flags
              build_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      match object.get("analyze") {
        Some(value) =>
          match parse_wite_config_section(value, "analyze") {
            Ok((flags, kind)) => {
              analyze_flags = flags
              analyze_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      match object.get("profile") {
        Some(value) =>
          match parse_wite_config_section(value, "profile") {
            Ok((flags, kind)) => {
              profile_flags = flags
              profile_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      Ok({
        build_flags,
        analyze_flags,
        profile_flags,
        build_kind,
        analyze_kind,
        profile_kind,
      })
    }
    _ => Err("config root must be object")
  }
}

///|
fn parse_wite_config_text(text : String) -> Result[WiteConfigFile, String] {
  let json_value = @json5.parse(text) catch {
    parse_error => return Err(parse_error.to_string())
  }
  parse_wite_config_json(json_value)
}

///|
pub struct ConfigSelectionFlags {
  config_path : String
  explicit_config_path : Bool
  use_config : Bool
  remaining_flags : Array[String]
}

///|
pub fn parse_config_selection_flags(
  flags : Array[String],
) -> ConfigSelectionFlags {
  let mut config_path = "wite.config.jsonc"
  let mut explicit_config_path = false
  let mut use_config = true
  let remaining_flags : Array[String] = []
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    if flag == "--no-config" {
      use_config = false
      i += 1
      continue
    }
    if flag == "--config" {
      if i + 1 >= flags.length() {
        println("missing config path after --config")
        @sys.exit(1)
      }
      let path = flags[i + 1]
      if path.is_empty() {
        println("config path must not be empty")
        @sys.exit(1)
      }
      config_path = path
      explicit_config_path = true
      use_config = true
      i += 2
      continue
    }
    match flag.strip_prefix("--config=") {
      Some(path) => {
        if path.is_empty() {
          println("config path must not be empty")
          @sys.exit(1)
        }
        config_path = path.to_string()
        explicit_config_path = true
        use_config = true
        i += 1
        continue
      }
      None => ()
    }
    remaining_flags.push(flag)
    i += 1
  }
  { config_path, explicit_config_path, use_config, remaining_flags }
}

///|
pub fn merge_command_flags(
  defaults : Array[String],
  cli_flags : Array[String],
) -> Array[String] {
  let merged = defaults.copy()
  merged.append(cli_flags[:])
  merged
}

///|
pub fn should_auto_sync_deps(use_config : Bool, config_exists : Bool) -> Bool {
  use_config && config_exists
}

///|
pub fn build_auto_sync_deps_command_args(config_path : String) -> Array[String] {
  ["wite", "deps", "sync", "--config=" + config_path, "--fail-fast"]
}

///|
pub fn config_has_dep_entries_or_exit(config_path : String) -> Bool {
  let config_json = load_config_json_for_add(config_path)
  let entries = match collect_dep_entries_from_config_json(config_json) {
    Ok(value) => value
    Err(msg) => {
      println("failed to read deps: " + msg)
      @sys.exit(1)
      []
    }
  }
  entries.length() > 0
}

///|
async fn auto_sync_deps_from_config_if_needed(
  selection : @wite_config.ConfigSelectionFlags,
) -> Unit {
  let config_exists = @fs.path_exists(selection.config_path)
  if not(
      @wite_config.should_auto_sync_deps(selection.use_config, config_exists),
    ) {
    return
  }
  if not(@wite_deps.config_has_dep_entries_or_exit(selection.config_path)) {
    return
  }
  let sync_args = @wite_config.build_auto_sync_deps_command_args(
    selection.config_path,
  )
  println("auto deps sync: " + selection.config_path + " -> deps/")
  @wite_deps.run_deps_sync_command(sync_args, @wite_deps.noop_usage_printer)
}

///|
fn load_wite_config_or_exit(path : String) -> WiteConfigFile {
  let text = @fs.read_file_to_string(path) catch {
    e => {
      println(
        "failed to read config file: " + path + " (" + e.to_string() + ")",
      )
      @sys.exit(1)
      ""
    }
  }
  match parse_wite_config_text(text) {
    Ok(config) => config
    Err(msg) => {
      println("failed to parse config file: " + path + " (" + msg + ")")
      @sys.exit(1)
      empty_wite_config_file()
    }
  }
}

///|
pub fn resolve_wite_config_or_default(
  selection : ConfigSelectionFlags,
) -> WiteConfigFile {
  if not(selection.use_config) {
    return empty_wite_config_file()
  }
  if not(@fs.path_exists(selection.config_path)) {
    if selection.explicit_config_path {
      println("config file not found: " + selection.config_path)
      @sys.exit(1)
    }
    return empty_wite_config_file()
  }
  load_wite_config_or_exit(selection.config_path)
}

///|
fn read_bytes_or_exit(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    e => {
      println("failed to read file: " + path + " (" + e.to_string() + ")")
      @sys.exit(1)
      b""
    }
  }
}

///|
fn print_section_sizes(sections : Array[@wite.SectionSize]) -> Unit {
  for section in sections {
    println(
      "  " + section.key + ": " + section.total_bytes.to_string() + " bytes",
    )
  }
}

///|
fn pad_two_digits_u64(value : UInt64) -> String {
  if value < 10UL {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn format_percent(numerator : UInt, denominator : UInt) -> String {
  if denominator == 0U {
    return "0.00%"
  }
  let scaled = numerator.to_uint64() * 10000UL / denominator.to_uint64()
  let whole = scaled / 100UL
  let frac = scaled % 100UL
  whole.to_string() + "." + pad_two_digits_u64(frac) + "%"
}

///|
fn print_section_sizes_with_share(
  sections : Array[@wite.SectionSize],
  total_bytes : UInt,
) -> Unit {
  for section in sections {
    println(
      "    " +
      section.key +
      ": " +
      section.total_bytes.to_string() +
      " bytes (" +
      format_percent(section.total_bytes, total_bytes) +
      ")",
    )
  }
}

///|
fn print_custom_section_breakdown(
  sections : Array[@wite.CustomSectionBreakdown],
  total_bytes : UInt,
  limit : UInt,
) -> Unit {
  if sections.length() == 0 {
    println("  custom sections: (none)")
    return
  }
  println("  custom sections:")
  let mut printed = 0U
  for section in sections {
    if printed >= limit {
      break
    }
    println(
      "    " +
      section.name +
      " count=" +
      section.count.to_string() +
      " total=" +
      section.total_bytes.to_string() +
      " bytes (" +
      format_percent(section.total_bytes, total_bytes) +
      ") payload=" +
      section.payload_bytes.to_string() +
      " content=" +
      section.content_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
fn print_opcode_stats(
  stats : Array[@wite.OpcodeStat],
  total_instruction_bytes : UInt,
  limit : UInt,
) -> Unit {
  if stats.length() == 0 {
    println("  opcode mix: (none)")
    return
  }
  println("  opcode mix:")
  let mut printed = 0U
  for stat in stats {
    if printed >= limit {
      break
    }
    println(
      "    " +
      stat.mnemonic +
      " [" +
      stat.key +
      "] count=" +
      stat.count.to_string() +
      " bytes=" +
      stat.total_bytes.to_string() +
      " (" +
      format_percent(stat.total_bytes, total_instruction_bytes) +
      ")",
    )
    printed += 1U
  }
}

///|
fn format_root_preview(roots : Array[UInt], limit : UInt) -> String {
  if roots.length() == 0 {
    return "(none)"
  }
  let items : Array[String] = []
  let mut printed = 0U
  for index in roots {
    if printed >= limit {
      break
    }
    items.push(index.to_string())
    printed += 1U
  }
  if roots.length().reinterpret_as_uint() > limit {
    items.join(", ") +
    " ... (+" +
    (roots.length().reinterpret_as_uint() - limit).to_string() +
    ")"
  } else {
    items.join(", ")
  }
}

///|
fn print_call_graph_summary(summary : @wite.CallGraphSummary) -> Unit {
  println("call graph summary:")
  println(
    "  functions: imported=" +
    summary.imported_function_count.to_string() +
    " local=" +
    summary.local_function_count.to_string() +
    " reachable=" +
    summary.reachable_function_count.to_string() +
    " dead=" +
    summary.dead_function_count.to_string(),
  )
  println("  roots: " + format_root_preview(summary.roots, 8U))
  println("  has_indirect_calls: " + summary.has_indirect_calls.to_string())
  println("  partial: " + summary.partial.to_string())
  let total_local_body_bytes = summary.reachable_body_bytes +
    summary.dead_body_bytes
  println(
    "  reachable_body_bytes: " +
    summary.reachable_body_bytes.to_string() +
    " (" +
    format_percent(summary.reachable_body_bytes, total_local_body_bytes) +
    ")",
  )
  println(
    "  dead_body_bytes: " +
    summary.dead_body_bytes.to_string() +
    " (" +
    format_percent(summary.dead_body_bytes, total_local_body_bytes) +
    ")",
  )
}

///|
fn print_host_code_hints(
  hints : Array[@wite.HostCodeHint],
  limit : UInt,
) -> Unit {
  if hints.length() == 0 {
    println("  hints: (none)")
    return
  }
  println("  hints:")
  let mut printed = 0U
  for hint in hints {
    if printed >= limit {
      break
    }
    let label = match hint.function_name {
      Some(name) => name
      None => "#\{hint.function_index.to_string()}"
    }
    let target_label = match hint.target_function_name {
      Some(name) => name
      None => "#\{hint.target_function_index.to_string()}"
    }
    let export_part = if hint.export_names.length() == 0 {
      ""
    } else {
      " exports=" + hint.export_names.join(",")
    }
    println(
      "    " +
      hint.kind +
      " " +
      label +
      " -> " +
      target_label +
      " consts=" +
      hint.appended_i32_const_count.to_string() +
      " drops=" +
      hint.dropped_param_count.to_string() +
      export_part,
    )
    printed += 1U
  }
}

///|
pub fn run_analyze_host(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_host_generated_code(bytes) {
    Ok(report) => {
      println("host/generated code analysis:")
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println(
        "  forwarding_thunks: param=" +
        report.param_forwarding_thunk_count.to_string() +
        " const=" +
        report.const_forwarding_thunk_count.to_string() +
        " signature-refine=" +
        report.signature_refinable_thunk_count.to_string(),
      )
      println(
        "  directize_candidate_calls: " +
        report.directize_candidate_call_count.to_string(),
      )
      println(
        "  dce_removable: functions=" +
        report.dce_removable_function_count.to_string() +
        " bytes=" +
        report.dce_removable_body_bytes.to_string() +
        " partial=" +
        report.dce_partial.to_string(),
      )
      print_host_code_hints(report.hints, limit)
    }
    Err(e) => {
      println("analyze-host failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_optimize_metadata_stage(stage : @wite.OptimizeStageMetadata) -> Unit {
  println(
    "    " +
    stage.stage +
    ": " +
    stage.before_size.to_string() +
    " -> " +
    stage.after_size.to_string() +
    " gain=" +
    stage.gain_bytes.to_string() +
    " regression=" +
    stage.regression_bytes.to_string(),
  )
  if stage.removed_sections.length() > 0 {
    println("      pass markers: " + stage.removed_sections.join(", "))
  }
  if stage.no_change_reasons.length() > 0 {
    println("      no-change: " + stage.no_change_reasons.join(", "))
  }
  println(
    "      function-delta: gain=" +
    stage.function_gain_bytes.to_string() +
    " regression=" +
    stage.function_regression_bytes.to_string(),
  )
  if stage.function_diffs.length() > 0 {
    println("      top-function-diffs:")
    let mut printed = 0U
    for diff in stage.function_diffs {
      if printed >= 5U {
        break
      }
      let label = match diff.before_name {
        Some(v) => v
        None =>
          match diff.after_name {
            Some(v) => v
            None => "#\{diff.function_index.to_string()}"
          }
      }
      let exports = if diff.export_names.length() == 0 {
        ""
      } else {
        " exports=" + diff.export_names.join(",")
      }
      println(
        "        " +
        label +
        " idx=" +
        diff.function_index.to_string() +
        " before=" +
        diff.before_body_bytes.to_string() +
        " after=" +
        diff.after_body_bytes.to_string() +
        " gain=" +
        diff.gain_bytes.to_string() +
        " regression=" +
        diff.regression_bytes.to_string() +
        exports,
      )
      printed += 1U
    }
  }
}

///|
pub fn run_analyze_opt(
  path : String,
  config : @wite.OptimizeConfig,
  function_diff_limit : UInt,
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_optimize_metadata(bytes, config~, function_diff_limit~) {
    Ok(report) => {
      println("optimize metadata analysis:")
      println(
        "  total: " +
        report.before_size.to_string() +
        " -> " +
        report.after_size.to_string() +
        " gain=" +
        report.total_gain_bytes.to_string() +
        " regression=" +
        report.total_regression_bytes.to_string(),
      )
      println("  stages:")
      for stage in report.stages {
        print_optimize_metadata_stage(stage)
      }
    }
    Err(e) => {
      println("analyze-opt failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_analyze(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes_with_share(
        sections,
        bytes.length().reinterpret_as_uint(),
      )
      match @wite.analyze_call_graph_summary(bytes) {
        Ok(summary) => print_call_graph_summary(summary)
        Err(e) => {
          println("analyze failed: " + @wite.error_to_string(e))
          @sys.exit(1)
        }
      }
    }
    Err(e) => {
      println("analyze failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_deep_analyze(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_wasm_breakdown(bytes, top_limit=limit) {
    Ok(report) => {
      println("wasm deep analysis:")
      println("  total_bytes: " + report.total_bytes.to_string())
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println("  instruction_count: " + report.instruction_count.to_string())
      println("  instruction_bytes: " + report.instruction_bytes.to_string())
      println("  opcode_partial: " + report.opcode_partial.to_string())
      println("  callgraph_partial: " + report.callgraph_partial.to_string())
      println("  has_indirect_calls: " + report.has_indirect_calls.to_string())
      let total_local_body_bytes = report.reachable_body_bytes +
        report.dead_body_bytes
      println(
        "  reachable_body_bytes: " +
        report.reachable_body_bytes.to_string() +
        " (" +
        format_percent(report.reachable_body_bytes, total_local_body_bytes) +
        ")",
      )
      println(
        "  dead_body_bytes: " +
        report.dead_body_bytes.to_string() +
        " (" +
        format_percent(report.dead_body_bytes, total_local_body_bytes) +
        ")",
      )
      println("  sections:")
      print_section_sizes_with_share(report.sections, report.total_bytes)
      print_custom_section_breakdown(
        report.custom_sections,
        report.total_bytes,
        limit,
      )
      println("  top functions:")
      print_function_sizes(report.top_functions, limit)
      println("  top blocks:")
      print_code_block_sizes(report.top_blocks, limit)
      print_opcode_stats(report.opcodes, report.instruction_bytes, limit)
    }
    Err(e) => {
      println("deep-analyze failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.profile_module(bytes) {
    Ok(profile) => {
      println("core wasm profile:")
      println("  total_bytes: " + profile.total_bytes.to_string())
      println("  function_count: " + profile.function_count.to_string())
      println("  import_count: " + profile.import_count.to_string())
      println("  export_count: " + profile.export_count.to_string())
      println("  code_body_count: " + profile.code_body_count.to_string())
      println("  code_body_bytes: " + profile.code_body_bytes.to_string())
      println("  sections:")
      print_section_sizes(profile.sections)
    }
    Err(e) => {
      println("profile failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_profile_with_kind(path : String, kind : BinaryKind) -> Unit {
  match kind {
    BinaryKind::Auto | BinaryKind::Core => run_profile(path)
    BinaryKind::Component => @wite_component.run_component_profile(path)
  }
}

///|
async fn run_profile_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  auto_sync_deps_from_config_if_needed(config_selection)
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  let merged_flags = @wite_config.merge_command_flags(
    config_file.profile_flags,
    config_selection.remaining_flags,
  )
  let mut kind = from_config_binary_kind(config_file.profile_kind)
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "profile kind")
      i += 2
      continue
    }
    match arg.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), "profile kind")
        i += 1
        continue
      }
      None => ()
    }
    println("unknown profile option: " + arg)
    @sys.exit(1)
  }
  run_profile_with_kind(path, kind)
}

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

///|
fn parse_wasm_opt_level_or_exit(token : String) -> String {
  let normalized = normalize_opt_level_token(token)
  match normalized {
    "-O" | "-O0" | "-O1" | "-O2" | "-O3" | "-O4" | "-Os" | "-Oz" => normalized
    _ => {
      println("invalid baseline-opt-level: " + token)
      @sys.exit(1)
      "-Oz"
    }
  }
}

///|
fn resolve_wasm_opt_bin(cli_value : String?) -> String {
  match cli_value {
    Some(path) => path
    None =>
      match @sys.get_env_var("WASM_OPT_BIN") {
        Some(path) => path
        None => "wasm-opt"
      }
  }
}

///|
fn run_wasm_opt_baseline_or_exit(
  input_path : String,
  output_path : String,
  wasm_opt_bin : String,
  baseline_opt_level : String,
  extra_args : Array[String],
) -> Unit {
  let args = [
    baseline_opt_level, "--all-features", "--strip-debug", "--strip-dwarf", "--strip-target-features",
  ]
  args.append(extra_args[:])
  let result = js_run_wasm_opt_cli(
    wasm_opt_bin,
    args.join("\t"),
    input_path,
    output_path,
  )
  let parts = split_string(result, "\t")
  if parts.length() == 0 || parts[0] != "ok" {
    let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
    let detail = if parts.length() >= 3 { parts[2] } else { result }
    println("wasm-opt baseline failed (" + stage + "): " + detail)
    @sys.exit(1)
  }
}

///|
fn parse_keep_custom(args : Array[String], start : Int) -> Array[String] {
  let keep : Array[String] = []
  for i in start..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--keep-custom=") {
      Some(name) => keep.push(name.to_string())
      None => ()
    }
  }
  keep
}

///|
fn parse_closed_world_roots(args : Array[String], start : Int) -> Array[String] {
  let roots : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--closed-world-root=") {
      Some(name) => if not(name.is_empty()) { roots.push(name.to_string()) }
      None => ()
    }
  }
  roots
}

///|
fn parse_excluded_roots(args : Array[String], start : Int) -> Array[String] {
  let excludes : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--exclude=") {
      Some(name) => if not(name.is_empty()) { excludes.push(name.to_string()) }
      None => ()
    }
  }
  excludes
}

///|
fn parse_uint_or_exit(text : String, name : String) -> UInt {
  if text.is_empty() {
    println("invalid " + name + ": empty string")
    @sys.exit(1)
    return 0U
  }
  let mut value = 0U
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      println("invalid " + name + ": " + text)
      @sys.exit(1)
      return 0U
    }
    value = value * 10U + (code - 48).reinterpret_as_uint()
  }
  value
}

///|
fn split_string(s : String, delim : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split(delim) {
    out.push(part.to_string())
  }
  out
}

///|
fn parse_int_or_exit(text : String, name : String) -> Int {
  if text.is_empty() {
    println("invalid " + name + ": empty string")
    @sys.exit(1)
    return 0
  }
  let mut negative = false
  let mut has_digit = false
  let mut value = 0
  let mut index = 0
  for ch in text {
    let code = ch.to_int()
    if index == 0 && code == 45 {
      negative = true
      index += 1
      continue
    }
    if code < 48 || code > 57 {
      println("invalid " + name + ": " + text)
      @sys.exit(1)
      return 0
    }
    value = value * 10 + (code - 48)
    has_digit = true
    index += 1
  }
  if not(has_digit) {
    println("invalid " + name + ": " + text)
    @sys.exit(1)
    return 0
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn parse_runtime_profile_scenarios(
  args : Array[String],
  start : Int,
) -> Array[@wite.RuntimeProfileScenario] {
  let scenarios : Array[@wite.RuntimeProfileScenario] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--scenario=") {
      Some(spec_text) => {
        let spec = spec_text.to_string()
        if spec.is_empty() {
          println("invalid scenario: empty spec")
          @sys.exit(1)
        }
        let parts = split_string(spec, ":")
        if parts.length() == 0 || parts[0].is_empty() {
          println("invalid scenario: " + spec)
          @sys.exit(1)
        }
        if parts.length() > 2 {
          println("invalid scenario format: " + spec)
          @sys.exit(1)
        }
        let export_name = parts[0]
        let scenario_args : Array[Int] = []
        if parts.length() == 2 && not(parts[1].is_empty()) {
          for raw_arg in split_string(parts[1], ",") {
            if raw_arg.is_empty() {
              continue
            }
            scenario_args.push(parse_int_or_exit(raw_arg, "scenario-arg"))
          }
        }
        scenarios.push(
          @wite.make_runtime_profile_scenario(export_name, args=scenario_args),
        )
      }
      None => ()
    }
  }
  scenarios
}

///|
priv struct OptimizeCliOptions {
  config : @wite.OptimizeConfig
  excluded_roots : Array[String]
  verbose : Bool
}

///|
fn parse_wasm_opt_optimize_level_or_exit(text : String) -> UInt {
  let value = parse_uint_or_exit(text, "optimize-level")
  if value > 4U {
    println("invalid optimize-level: " + text + " (expected 0..4)")
    @sys.exit(1)
  }
  value
}

///|
fn parse_wasm_opt_shrink_level_or_exit(text : String) -> UInt {
  let value = parse_uint_or_exit(text, "shrink-level")
  if value > 2U {
    println("invalid shrink-level: " + text + " (expected 0..2)")
    @sys.exit(1)
  }
  value
}

///|
fn wasm_opt_preset_from_optimize_level(level : UInt) -> @wite.OptimizeConfig {
  match level {
    0U => @wite.OptimizeConfig::o0()
    1U => @wite.OptimizeConfig::o1()
    2U => @wite.OptimizeConfig::o2()
    3U => @wite.OptimizeConfig::o3()
    _ => @wite.OptimizeConfig::aggressive()
  }
}

///|
fn derive_preset_from_wasm_opt_levels(
  optimize_level : UInt?,
  shrink_level : UInt?,
) -> @wite.OptimizeConfig? {
  match shrink_level {
    Some(level) =>
      if level >= 2U {
        Some(@wite.OptimizeConfig::oz())
      } else if level == 1U {
        Some(@wite.OptimizeConfig::os())
      } else {
        match optimize_level {
          Some(v) => Some(wasm_opt_preset_from_optimize_level(v))
          None => None
        }
      }
    None =>
      match optimize_level {
        Some(v) => Some(wasm_opt_preset_from_optimize_level(v))
        None => None
      }
  }
}

///|
fn parse_optimize_cli_options(flags : Array[String]) -> OptimizeCliOptions {
  let mut strip_all_custom = false
  let mut strip_name_section = true
  let mut strip_producers_section = true
  let mut strip_debug_sections = false
  let mut strip_dwarf_sections = false
  let mut strip_target_features_section = false
  let mut enable_peephole = true
  let mut enable_vacuum = true
  let mut enable_merge_blocks = true
  let mut enable_remove_unused_brs = true
  let mut pass_rounds = 1U
  let mut enable_dce = false
  let mut enable_dfe = false
  let mut enable_merge_similar_functions = false
  let mut enable_remove_unused_module_elements = false
  let mut closed_world = false
  let mut safe_mode = false
  let mut verbose = false
  let mut wasm_opt_optimize_level : UInt? = None
  let mut wasm_opt_shrink_level : UInt? = None
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    match
      @wite.optimize_config_from_opt_level(normalize_opt_level_token(flag)) {
      Some(preset) => {
        strip_all_custom = preset.strip_all_custom
        strip_name_section = preset.strip_name_section
        strip_producers_section = preset.strip_producers_section
        strip_debug_sections = preset.strip_debug_sections
        strip_dwarf_sections = preset.strip_dwarf_sections
        strip_target_features_section = preset.strip_target_features_section
        pass_rounds = preset.pass_rounds
        enable_peephole = preset.enable_peephole
        enable_vacuum = preset.enable_vacuum
        enable_merge_blocks = preset.enable_merge_blocks
        enable_remove_unused_brs = preset.enable_remove_unused_brs
        enable_dce = preset.enable_dce
        enable_dfe = preset.enable_dfe
        enable_merge_similar_functions = preset.enable_merge_similar_functions
        enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
        closed_world = preset.closed_world
        safe_mode = preset.safe_mode
      }
      None => ()
    }
    if flag == "--optimize-level" || flag == "-ol" {
      if i + 1 >= flags.length() {
        println("missing value after " + flag)
        @sys.exit(1)
      }
      wasm_opt_optimize_level = Some(
        parse_wasm_opt_optimize_level_or_exit(flags[i + 1]),
      )
      match
        derive_preset_from_wasm_opt_levels(
          wasm_opt_optimize_level, wasm_opt_shrink_level,
        ) {
        Some(preset) => {
          strip_all_custom = preset.strip_all_custom
          strip_name_section = preset.strip_name_section
          strip_producers_section = preset.strip_producers_section
          strip_debug_sections = preset.strip_debug_sections
          strip_dwarf_sections = preset.strip_dwarf_sections
          strip_target_features_section = preset.strip_target_features_section
          pass_rounds = preset.pass_rounds
          enable_peephole = preset.enable_peephole
          enable_vacuum = preset.enable_vacuum
          enable_merge_blocks = preset.enable_merge_blocks
          enable_remove_unused_brs = preset.enable_remove_unused_brs
          enable_dce = preset.enable_dce
          enable_dfe = preset.enable_dfe
          enable_merge_similar_functions = preset.enable_merge_similar_functions
          enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
          closed_world = preset.closed_world
          safe_mode = preset.safe_mode
        }
        None => ()
      }
      i += 2
      continue
    }
    match flag.strip_prefix("--optimize-level=") {
      Some(value) => {
        wasm_opt_optimize_level = Some(
          parse_wasm_opt_optimize_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    match flag.strip_prefix("-ol=") {
      Some(value) => {
        wasm_opt_optimize_level = Some(
          parse_wasm_opt_optimize_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    if flag == "--shrink-level" || flag == "-s" {
      if i + 1 >= flags.length() {
        println("missing value after " + flag)
        @sys.exit(1)
      }
      wasm_opt_shrink_level = Some(
        parse_wasm_opt_shrink_level_or_exit(flags[i + 1]),
      )
      match
        derive_preset_from_wasm_opt_levels(
          wasm_opt_optimize_level, wasm_opt_shrink_level,
        ) {
        Some(preset) => {
          strip_all_custom = preset.strip_all_custom
          strip_name_section = preset.strip_name_section
          strip_producers_section = preset.strip_producers_section
          strip_debug_sections = preset.strip_debug_sections
          strip_dwarf_sections = preset.strip_dwarf_sections
          strip_target_features_section = preset.strip_target_features_section
          pass_rounds = preset.pass_rounds
          enable_peephole = preset.enable_peephole
          enable_vacuum = preset.enable_vacuum
          enable_merge_blocks = preset.enable_merge_blocks
          enable_remove_unused_brs = preset.enable_remove_unused_brs
          enable_dce = preset.enable_dce
          enable_dfe = preset.enable_dfe
          enable_merge_similar_functions = preset.enable_merge_similar_functions
          enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
          closed_world = preset.closed_world
          safe_mode = preset.safe_mode
        }
        None => ()
      }
      i += 2
      continue
    }
    match flag.strip_prefix("--shrink-level=") {
      Some(value) => {
        wasm_opt_shrink_level = Some(
          parse_wasm_opt_shrink_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    match flag.strip_prefix("-s=") {
      Some(value) => {
        wasm_opt_shrink_level = Some(
          parse_wasm_opt_shrink_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    if flag == "--strip" {
      strip_debug_sections = true
      strip_name_section = true
    }
    if flag == "--strip-all-custom" {
      strip_all_custom = true
    }
    if flag == "--strip-producers" {
      strip_producers_section = true
    }
    if flag == "--strip-debug" {
      strip_debug_sections = true
    }
    if flag == "--strip-dwarf" {
      strip_dwarf_sections = true
    }
    if flag == "--strip-target-features" {
      strip_target_features_section = true
    }
    if flag == "--no-peephole" {
      enable_peephole = false
    }
    if flag == "--peephole" {
      enable_peephole = true
    }
    if flag == "--no-vacuum" {
      enable_vacuum = false
    }
    if flag == "--vacuum" {
      enable_vacuum = true
    }
    if flag == "--no-merge-blocks" {
      enable_merge_blocks = false
    }
    if flag == "--merge-blocks" {
      enable_merge_blocks = true
    }
    if flag == "--no-remove-unused-brs" {
      enable_remove_unused_brs = false
    }
    if flag == "--remove-unused-brs" {
      enable_remove_unused_brs = true
    }
    if flag == "--debuginfo" || flag == "-g" {
      strip_name_section = false
      strip_debug_sections = false
    }
    if flag == "--converge" {
      pass_rounds = 8U
    }
    if flag == "-c" {
      pass_rounds = 8U
    }
    if flag == "--rounds" {
      if i + 1 >= flags.length() {
        println("missing value after --rounds")
        @sys.exit(1)
      }
      pass_rounds = parse_uint_or_exit(flags[i + 1], "rounds")
      i += 2
      continue
    }
    match flag.strip_prefix("--rounds=") {
      Some(value) =>
        pass_rounds = parse_uint_or_exit(value.to_string(), "rounds")
      None => ()
    }
    if flag == "--dce" || flag == "--dce-apply" {
      enable_dce = true
    }
    if flag == "--duplicate-function-elimination" || flag == "--dfe-apply" {
      enable_dfe = true
    }
    if flag == "--merge-similar-functions" || flag == "--msf-apply" {
      enable_merge_similar_functions = true
    }
    if flag == "--remove-unused-module-elements" || flag == "--rume-apply" {
      enable_remove_unused_module_elements = true
    }
    if flag == "-cw" {
      closed_world = true
    }
    if flag == "--all-features" || flag == "-all" {
      i += 1
      continue
    }
    if flag.has_prefix("--enable-") || flag.has_prefix("--disable-") {
      i += 1
      continue
    }
    if flag == "--mvp-features" || flag == "-mvp" || flag == "--detect-features" {
      i += 1
      continue
    }
    if flag == "--closed-world" {
      closed_world = true
    }
    if flag == "--safe-mode" {
      safe_mode = true
    }
    if flag == "--verbose" {
      verbose = true
    }
    i += 1
  }
  let keep_custom_sections = parse_keep_custom(flags, 0)
  let closed_world_root_exports = parse_closed_world_roots(flags, 0)
  let excluded_roots = parse_excluded_roots(flags, 0)
  let config = @wite.make_optimize_config(
    strip_all_custom~,
    strip_name_section~,
    strip_producers_section~,
    strip_debug_sections~,
    strip_dwarf_sections~,
    strip_target_features_section~,
    keep_custom_sections~,
    pass_rounds~,
    enable_peephole~,
    enable_vacuum~,
    enable_merge_blocks~,
    enable_remove_unused_brs~,
    enable_dce~,
    enable_dfe~,
    enable_merge_similar_functions~,
    enable_remove_unused_module_elements~,
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  { config, excluded_roots, verbose }
}

///|
fn write_output_or_exit(output_path : String, bytes : Bytes) -> Unit {
  @fs.write_bytes_to_file(output_path, bytes) catch {
    e => {
      println(
        "failed to write file: " + output_path + " (" + e.to_string() + ")",
      )
      @sys.exit(1)
    }
  }
}

///|
fn run_optimize(args : Array[String]) -> Unit {
  if args.length() < 4 {
    print_usage()
    @sys.exit(1)
  }
  let input_path = args[2]
  let output_path = args[3]
  let flags : Array[String] = []
  for i in 4..<args.length() {
    flags.push(args[i])
  }
  let kind_flags = extract_binary_kind_flags(
    flags,
    BinaryKind::Auto,
    "optimize kind",
  )
  let options = parse_optimize_cli_options(kind_flags.flags)
  let bytes = read_bytes_or_exit(input_path)
  match
    optimize_with_kind(
      bytes,
      kind_flags.kind,
      options.config,
      options.excluded_roots,
    ) {
    Ok(result) => {
      write_output_or_exit(output_path, result.bytes)
      println(
        "optimized: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      if result.removed_sections.length() > 0 {
        println("removed sections: " + result.removed_sections.join(", "))
      }
      if options.verbose && result.no_change_reasons.length() > 0 {
        println("no-change reasons: " + result.no_change_reasons.join(", "))
      }
      println("kind: " + binary_kind_name(kind_flags.kind))
    }
    Err(msg) => {
      println("optimize failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn to_optimize_kind(kind : BinaryKind) -> @wite_optimize.OptimizeKind {
  match kind {
    BinaryKind::Auto => @wite_optimize.optimize_kind_auto()
    BinaryKind::Core => @wite_optimize.optimize_kind_core()
    BinaryKind::Component => @wite_optimize.optimize_kind_component()
  }
}

///|
fn optimize_with_kind(
  bytes : Bytes,
  kind : BinaryKind,
  config : @wite.OptimizeConfig,
  excluded_roots : Array[String],
) -> Result[@wite.OptimizeResult, String] {
  @wite_optimize.optimize_with_kind(
    bytes,
    to_optimize_kind(kind),
    config,
    exclude=excluded_roots,
  )
}

///|
async fn run_build(args : Array[String]) -> Unit {
  let default_input = pick_default_build_input_path(
    @fs.path_exists("main.wac"),
    @fs.path_exists("main.wasm"),
  )
  let resolved = match resolve_build_input_from_args(args, default_input) {
    Ok(value) => value
    Err(msg) => {
      println(msg)
      print_usage()
      @sys.exit(1)
      { input_path: "", raw_flags: [], explicit_input: false }
    }
  }
  let input_path = resolved.input_path
  let is_wac_input = input_path.has_suffix(".wac")
  let raw_flags = resolved.raw_flags
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  if not(is_wac_input) {
    auto_sync_deps_from_config_if_needed(config_selection)
  }
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  let merged_flags = @wite_config.merge_command_flags(
    config_file.build_flags,
    config_selection.remaining_flags,
  )
  let mut output_path : String? = None
  let mut best_effort = false
  let mut compose_dce = true
  let mut kind = from_config_binary_kind(config_file.build_kind)
  let optimize_flags : Array[String] = []
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "-o" || arg == "--out" {
      if i + 1 >= merged_flags.length() {
        println("missing output path after " + arg)
        @sys.exit(1)
      }
      output_path = Some(merged_flags[i + 1])
      i += 2
      continue
    }
    match arg.strip_prefix("--out=") {
      Some(path) => {
        output_path = Some(path.to_string())
        i += 1
        continue
      }
      None => ()
    }
    if arg == "--best-effort" {
      best_effort = true
      i += 1
      continue
    }
    if arg == "--no-compose-dce" {
      compose_dce = false
      i += 1
      continue
    }
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "build kind")
      i += 2
      continue
    }
    match arg.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), "build kind")
        i += 1
        continue
      }
      None => ()
    }
    optimize_flags.push(arg)
    i += 1
  }
  let out = match output_path {
    Some(path) => path
    None =>
      if resolved.explicit_input {
        derive_build_output_path(input_path)
      } else {
        derive_implicit_build_output_path(input_path)
      }
  }
  if is_wac_input &&
    config_selection.use_config &&
    @fs.path_exists(config_selection.config_path) {
    match
      @wite_deps.materialize_wac_dependencies_from_config(
        config_selection.config_path,
        input_path,
        best_effort,
      ) {
      Ok(synced) =>
        if synced > 0U {
          println("materialized wac deps: " + synced.to_string() + " entries")
        }
      Err(msg) => {
        println("build failed: " + msg)
        @sys.exit(1)
      }
    }
  }
  let built = if is_wac_input {
    match
      @wite_bundle.compose_wac_file(input_path, best_effort~, dce=compose_dce) {
      Ok(bytes) => bytes
      Err(msg) => {
        println("build failed: " + msg)
        @sys.exit(1)
        b""
      }
    }
  } else {
    read_bytes_or_exit(input_path)
  }
  let options = parse_optimize_cli_options(optimize_flags)
  match
    optimize_with_kind(built, kind, options.config, options.excluded_roots) {
    Ok(result) => {
      write_output_or_exit(out, result.bytes)
      println(
        "built: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      if result.removed_sections.length() > 0 {
        println("removed sections: " + result.removed_sections.join(", "))
      }
      if options.verbose && result.no_change_reasons.length() > 0 {
        println("no-change reasons: " + result.no_change_reasons.join(", "))
      }
      println("kind: " + binary_kind_name(kind))
      println("output: " + out)
    }
    Err(msg) => {
      println("build failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
pub fn run_dce_report(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_dce_report(bytes) {
    Ok(report) => {
      println("dce report:")
      println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      println("  partial: " + report.partial.to_string())
      println(
        "  removable_function_count: " +
        report.removable_function_count.to_string(),
      )
      println(
        "  removable_body_bytes: " + report.removable_body_bytes.to_string(),
      )
      if report.removable_functions.length() > 0 {
        println("  removable_functions:")
        print_function_sizes(report.removable_functions, limit)
      }
    }
    Err(e) => {
      println("dce-report failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_runtime_profile(
  path : String,
  iterations : UInt,
  scenarios : Array[@wite.RuntimeProfileScenario],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.profile_runtime_exports(bytes, iterations~, scenarios~) {
    Ok(profile) => {
      println("runtime profile:")
      println("  instantiate_ns: " + profile.instantiate_ns.to_string())
      println("  iterations: " + profile.iterations.to_string())
      if scenarios.length() > 0 {
        println("  scenarios: " + scenarios.length().to_string())
      }
      if profile.functions.length() == 0 {
        if scenarios.length() > 0 {
          println("  functions: (no runnable scenarios)")
        } else {
          println("  functions: (no zero-arg exports)")
        }
      } else {
        println("  functions:")
        for fn_profile in profile.functions {
          println(
            "    " +
            fn_profile.name +
            " calls=" +
            fn_profile.calls.to_string() +
            " total_ns=" +
            fn_profile.total_ns.to_string() +
            " avg_ns=" +
            fn_profile.average_ns.to_string(),
          )
        }
      }
      if profile.skipped_exports.length() > 0 {
        println("  skipped_exports: " + profile.skipped_exports.join(", "))
      }
      if profile.unresolved_exports.length() > 0 {
        println("  unresolved_exports:")
        for unresolved in profile.unresolved_exports {
          let detail = if unresolved.detail.is_empty() {
            ""
          } else {
            " detail=" + unresolved.detail
          }
          println(
            "    " +
            unresolved.export_name +
            " reason=" +
            unresolved.reason +
            detail,
          )
        }
      }
    }
    Err(msg) => {
      println("runtime profile failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn print_hotness_size_entries(
  entries : Array[@wite.HotnessSizeEntry],
  limit : UInt,
) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let index_text = match entry.function_index {
      Some(v) => v.to_string()
      None => "-"
    }
    let function_name = match entry.function_name {
      Some(v) => v
      None => "-"
    }
    let unresolved_reason = match entry.unresolved_reason {
      Some(v) => " reason=" + v
      None => ""
    }
    let unresolved_detail = match entry.unresolved_detail {
      Some(v) => if v.is_empty() { "" } else { " detail=" + v }
      None => ""
    }
    println(
      "    " +
      entry.export_name +
      " idx=" +
      index_text +
      " fn=" +
      function_name +
      " body=" +
      entry.body_bytes.to_string() +
      " calls=" +
      entry.calls.to_string() +
      " total_ns=" +
      entry.total_ns.to_string() +
      " avg_ns=" +
      entry.average_ns.to_string() +
      " bucket=" +
      entry.bucket +
      unresolved_reason +
      unresolved_detail,
    )
    printed += 1U
  }
}

///|
fn print_hotness_size_buckets(buckets : Array[@wite.HotnessSizeBucket]) -> Unit {
  println("  buckets:")
  for bucket in buckets {
    println(
      "    " +
      bucket.bucket +
      " count=" +
      bucket.count.to_string() +
      " body_bytes=" +
      bucket.body_bytes.to_string() +
      " total_ns=" +
      bucket.total_ns.to_string(),
    )
  }
}

///|
fn print_hotness_unresolved_reason_counts(
  counts : Array[@wite.HotnessUnresolvedReasonCount],
) -> Unit {
  if counts.length() == 0 {
    return
  }
  println("  unresolved_reasons:")
  for count in counts {
    println("    " + count.reason + " count=" + count.count.to_string())
  }
}

///|
pub fn run_hot_size(
  path : String,
  iterations : UInt,
  limit : UInt,
  scenarios : Array[@wite.RuntimeProfileScenario],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_hotness_size_matrix(bytes, iterations~, scenarios~) {
    Ok(report) => {
      println("hot-size matrix:")
      println("  instantiate_ns: " + report.instantiate_ns.to_string())
      println("  iterations: " + report.iterations.to_string())
      if scenarios.length() > 0 {
        println("  scenarios: " + scenarios.length().to_string())
      }
      println(
        "  thresholds: hot_ns>=" +
        report.hot_threshold_ns.to_string() +
        " large_bytes>=" +
        report.large_threshold_bytes.to_string(),
      )
      if report.unresolved_exports.length() > 0 {
        println("  unresolved_exports: " + report.unresolved_exports.join(", "))
      }
      print_hotness_unresolved_reason_counts(report.unresolved_reason_counts)
      print_hotness_size_buckets(report.buckets)
      print_hotness_size_entries(report.entries, limit)
    }
    Err(msg) => {
      println("hot-size failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn print_function_sizes(
  functions : Array[@wite.FunctionSize],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for fn_size in functions {
    if printed >= limit {
      break
    }
    let label = match fn_size.name {
      Some(name) => name
      None => "#\{fn_size.function_index.to_string()}"
    }
    let exports = if fn_size.export_names.length() == 0 {
      ""
    } else {
      " exports=" + fn_size.export_names.join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      fn_size.function_index.to_string() +
      " body=" +
      fn_size.body_bytes.to_string() +
      exports,
    )
    printed += 1U
  }
}

///|
fn format_opt_uint(value : UInt?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "-"
  }
}

///|
fn format_opt_name(value : String?) -> String {
  match value {
    Some(v) => if v.is_empty() { "-" } else { v }
    None => "-"
  }
}

///|
fn print_function_gap_entries(entries : Array[@wite.FunctionGapEntry]) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  for entry in entries {
    let left_exports = if entry.left_export_names.length() == 0 {
      "-"
    } else {
      entry.left_export_names.join(",")
    }
    let right_exports = if entry.right_export_names.length() == 0 {
      "-"
    } else {
      entry.right_export_names.join(",")
    }
    println(
      "    kind=" +
      entry.match_kind +
      " key=" +
      entry.match_key +
      " left_idx=" +
      format_opt_uint(entry.left_function_index) +
      " right_idx=" +
      format_opt_uint(entry.right_function_index) +
      " left_name=" +
      format_opt_name(entry.left_name) +
      " right_name=" +
      format_opt_name(entry.right_name) +
      " left_body=" +
      entry.left_body_bytes.to_string() +
      " right_body=" +
      entry.right_body_bytes.to_string() +
      " delta=" +
      entry.left_minus_right_bytes.to_string() +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string() +
      " left_exports=" +
      left_exports +
      " right_exports=" +
      right_exports,
    )
    println(
      "    tsv\t" +
      entry.match_kind +
      "\t" +
      entry.match_key +
      "\t" +
      format_opt_uint(entry.left_function_index) +
      "\t" +
      format_opt_uint(entry.right_function_index) +
      "\t" +
      entry.left_body_bytes.to_string() +
      "\t" +
      entry.right_body_bytes.to_string() +
      "\t" +
      entry.left_minus_right_bytes.to_string() +
      "\t" +
      entry.abs_gap_bytes.to_string() +
      "\t" +
      left_exports +
      "\t" +
      right_exports,
    )
  }
}

///|
fn print_code_block_sizes(
  blocks : Array[@wite.CodeBlockSize],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for block in blocks {
    if printed >= limit {
      break
    }
    let label = match block.function_name {
      Some(name) => name
      None => "#\{block.function_index.to_string()}"
    }
    let exports = if block.export_names.length() == 0 {
      ""
    } else {
      " exports=" + block.export_names.join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      block.function_index.to_string() +
      " block=" +
      block.block_index.to_string() +
      " kind=" +
      block.kind +
      " depth=" +
      block.depth.to_string() +
      " bytes=" +
      block.total_bytes.to_string() +
      " instrs=" +
      block.instruction_count.to_string() +
      " span=" +
      block.start_offset.to_string() +
      ".." +
      block.end_offset.to_string() +
      exports,
    )
    printed += 1U
  }
}

///|
pub fn run_block_sizes(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_code_block_sizes(bytes) {
    Ok(report) => {
      println("code block size analysis:")
      println("  partial: " + report.partial.to_string())
      println("  function_count: " + report.function_count.to_string())
      println("  block_count: " + report.block_count.to_string())
      println("  total_body_bytes: " + report.total_body_bytes.to_string())
      println(
        "  total_instruction_bytes: " +
        report.total_instruction_bytes.to_string(),
      )
      println("  blocks:")
      print_code_block_sizes(report.blocks, limit)
    }
    Err(e) => {
      println("block-sizes failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_top_functions(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_function_sizes(bytes) {
    Ok(functions) => {
      println("top functions:")
      println("  count: " + functions.length().to_string())
      print_function_sizes(functions, limit)
    }
    Err(e) => {
      println("top-functions failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_function_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  match
    @wite.analyze_function_size_gap(left_bytes, right_bytes, top_limit=limit) {
    Ok(report) => {
      println("function-gap:")
      println(
        "  left_total_body_bytes: " + report.left_total_body_bytes.to_string(),
      )
      println(
        "  right_total_body_bytes: " + report.right_total_body_bytes.to_string(),
      )
      println(
        "  left_minus_right_total_bytes: " +
        report.left_minus_right_total_bytes.to_string(),
      )
      println(
        "  unmatched_left_count: " + report.unmatched_left_count.to_string(),
      )
      println(
        "  unmatched_right_count: " + report.unmatched_right_count.to_string(),
      )
      println("  entries_count: " + report.entries.length().to_string())
      println(
        "  tsv_header\tkind\tkey\tleft_idx\tright_idx\tleft_body\tright_body\tdelta\tabs_gap\tleft_exports\tright_exports",
      )
      print_function_gap_entries(report.entries)
    }
    Err(e) => {
      println("function-gap failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn format_signed_int(value : Int) -> String {
  if value > 0 {
    "+" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn abs_int_to_uint(value : Int) -> UInt {
  if value < 0 {
    (-value).reinterpret_as_uint()
  } else {
    value.reinterpret_as_uint()
  }
}

///|
fn diff_uint(left : UInt, right : UInt) -> Int {
  if left >= right {
    (left - right).reinterpret_as_int()
  } else {
    -(right - left).reinterpret_as_int()
  }
}

///|
priv struct SectionGapEntry {
  key : String
  left_bytes : UInt
  right_bytes : UInt
  delta_bytes : Int
  abs_gap_bytes : UInt
}

///|
fn compare_section_gap_entry(a : SectionGapEntry, b : SectionGapEntry) -> Int {
  if a.abs_gap_bytes > b.abs_gap_bytes {
    -1
  } else if a.abs_gap_bytes < b.abs_gap_bytes {
    1
  } else {
    a.key.compare(b.key)
  }
}

///|
fn collect_section_gap_entries(
  left_sections : Array[@wite.SectionSize],
  right_sections : Array[@wite.SectionSize],
) -> Array[SectionGapEntry] {
  let left_map : Map[String, UInt] = {}
  for section in left_sections {
    left_map.set(section.key, section.total_bytes)
  }
  let right_map : Map[String, UInt] = {}
  for section in right_sections {
    right_map.set(section.key, section.total_bytes)
  }
  let seen : Map[String, Bool] = {}
  let entries : Array[SectionGapEntry] = []
  let add_entry = fn(key : String) {
    if seen.contains(key) {
      return
    }
    seen.set(key, true)
    let left_bytes = match left_map.get(key) {
      Some(v) => v
      None => 0U
    }
    let right_bytes = match right_map.get(key) {
      Some(v) => v
      None => 0U
    }
    let delta_bytes = diff_uint(left_bytes, right_bytes)
    entries.push({
      key,
      left_bytes,
      right_bytes,
      delta_bytes,
      abs_gap_bytes: abs_int_to_uint(delta_bytes),
    })
  }
  left_map.each((key, _) => add_entry(key))
  right_map.each((key, _) => add_entry(key))
  entries.sort_by(compare_section_gap_entry)
  entries
}

///|
pub fn run_section_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  let left_sections = match @wite.analyze_section_sizes(left_bytes) {
    Ok(v) => v
    Err(e) => {
      println("section diff failed (left): " + @wite.error_to_string(e))
      @sys.exit(1)
      []
    }
  }
  let right_sections = match @wite.analyze_section_sizes(right_bytes) {
    Ok(v) => v
    Err(e) => {
      println("section diff failed (right): " + @wite.error_to_string(e))
      @sys.exit(1)
      []
    }
  }
  let entries = collect_section_gap_entries(left_sections, right_sections)
  println("section-gap:")
  println("  left_total_bytes: " + left_bytes.length().to_string())
  println("  right_total_bytes: " + right_bytes.length().to_string())
  println(
    "  left_minus_right_total_bytes: " +
    diff_uint(
      left_bytes.length().reinterpret_as_uint(),
      right_bytes.length().reinterpret_as_uint(),
    ).to_string(),
  )
  println("  entries_count: " + entries.length().to_string())
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    println(
      "    " +
      entry.key +
      " left=" +
      entry.left_bytes.to_string() +
      " right=" +
      entry.right_bytes.to_string() +
      " delta=" +
      format_signed_int(entry.delta_bytes) +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
priv struct BlockGapEntry {
  key : String
  function_index : UInt
  function_name : String?
  kind : String
  depth : UInt
  left_bytes : UInt
  right_bytes : UInt
  delta_bytes : Int
  abs_gap_bytes : UInt
}

///|
fn compare_block_gap_entry(a : BlockGapEntry, b : BlockGapEntry) -> Int {
  if a.abs_gap_bytes > b.abs_gap_bytes {
    -1
  } else if a.abs_gap_bytes < b.abs_gap_bytes {
    1
  } else {
    a.key.compare(b.key)
  }
}

///|
fn block_gap_key(block : @wite.CodeBlockSize) -> String {
  block.function_index.to_string() +
  ":" +
  block.block_index.to_string() +
  ":" +
  block.kind +
  ":" +
  block.depth.to_string()
}

///|
fn collect_block_gap_entries(
  left_blocks : Array[@wite.CodeBlockSize],
  right_blocks : Array[@wite.CodeBlockSize],
) -> Array[BlockGapEntry] {
  let left_map : Map[String, @wite.CodeBlockSize] = {}
  for block in left_blocks {
    left_map.set(block_gap_key(block), block)
  }
  let right_map : Map[String, @wite.CodeBlockSize] = {}
  for block in right_blocks {
    right_map.set(block_gap_key(block), block)
  }
  let seen : Map[String, Bool] = {}
  let entries : Array[BlockGapEntry] = []
  let add_entry = fn(key : String) {
    if seen.contains(key) {
      return
    }
    seen.set(key, true)
    let left_block = left_map.get(key)
    let right_block = right_map.get(key)
    let left_bytes = match left_block {
      Some(v) => v.total_bytes
      None => 0U
    }
    let right_bytes = match right_block {
      Some(v) => v.total_bytes
      None => 0U
    }
    let delta_bytes = diff_uint(left_bytes, right_bytes)
    let reference = match left_block {
      Some(v) => v
      None =>
        match right_block {
          Some(v) => v
          None => return
        }
    }
    entries.push({
      key,
      function_index: reference.function_index,
      function_name: reference.function_name,
      kind: reference.kind,
      depth: reference.depth,
      left_bytes,
      right_bytes,
      delta_bytes,
      abs_gap_bytes: abs_int_to_uint(delta_bytes),
    })
  }
  left_map.each((key, _) => add_entry(key))
  right_map.each((key, _) => add_entry(key))
  entries.sort_by(compare_block_gap_entry)
  entries
}

///|
pub fn run_block_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  let left_report = match @wite.analyze_code_block_sizes(left_bytes) {
    Ok(v) => v
    Err(e) => {
      println("block diff failed (left): " + @wite.error_to_string(e))
      @sys.exit(1)
      panic()
    }
  }
  let right_report = match @wite.analyze_code_block_sizes(right_bytes) {
    Ok(v) => v
    Err(e) => {
      println("block diff failed (right): " + @wite.error_to_string(e))
      @sys.exit(1)
      panic()
    }
  }
  let entries = collect_block_gap_entries(
    left_report.blocks,
    right_report.blocks,
  )
  println("block-gap:")
  println(
    "  left_total_instruction_bytes: " +
    left_report.total_instruction_bytes.to_string(),
  )
  println(
    "  right_total_instruction_bytes: " +
    right_report.total_instruction_bytes.to_string(),
  )
  println(
    "  left_minus_right_total_instruction_bytes: " +
    diff_uint(
      left_report.total_instruction_bytes,
      right_report.total_instruction_bytes,
    ).to_string(),
  )
  println("  entries_count: " + entries.length().to_string())
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let label = match entry.function_name {
      Some(v) => v
      None => "#\{entry.function_index.to_string()}"
    }
    println(
      "    " +
      label +
      " key=" +
      entry.key +
      " kind=" +
      entry.kind +
      " depth=" +
      entry.depth.to_string() +
      " left=" +
      entry.left_bytes.to_string() +
      " right=" +
      entry.right_bytes.to_string() +
      " delta=" +
      format_signed_int(entry.delta_bytes) +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
fn print_call_graph_nodes(
  nodes : Array[@wite.CallGraphNode],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for node in nodes {
    if printed >= limit {
      break
    }
    let label = match node.name {
      Some(name) => name
      None => "#\{node.function_index.to_string()}"
    }
    let status = if node.reachable_from_roots { "reachable" } else { "dead" }
    let export_part = if node.export_names.length() == 0 {
      ""
    } else {
      " exports=" + node.export_names.join(",")
    }
    let callee_part = if node.direct_callees.length() == 0 {
      ""
    } else {
      " callees=" + node.direct_callees.map(i => i.to_string()).join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      node.function_index.to_string() +
      " body=" +
      node.body_bytes.to_string() +
      " " +
      status +
      export_part +
      callee_part,
    )
    printed += 1U
  }
}

///|
pub fn run_callgraph(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_call_graph(bytes) {
    Ok(report) => {
      println("call graph:")
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      println("  has_indirect_calls: " + report.has_indirect_calls.to_string())
      println("  partial: " + report.partial.to_string())
      println(
        "  reachable_body_bytes: " + report.reachable_body_bytes.to_string(),
      )
      println("  dead_body_bytes: " + report.dead_body_bytes.to_string())
      println("  nodes:")
      print_call_graph_nodes(report.nodes, limit)
    }
    Err(e) => {
      println("callgraph failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_keep_reasons_with_options(
  path : String,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = @wite.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @wite.analyze_keep_reasons(bytes, config~) {
    Ok(report) => {
      println("keep reasons:")
      println("  partial: " + report.partial.to_string())
      if report.entries.length() == 0 {
        println("  entries: (none)")
      } else {
        println("  entries:")
        for entry in report.entries {
          let label = match entry.name {
            Some(v) => v
            None => "#\{entry.function_index.to_string()}"
          }
          let exports = if entry.export_names.length() == 0 {
            ""
          } else {
            " exports=" + entry.export_names.join(",")
          }
          println(
            "    " +
            label +
            " idx=" +
            entry.function_index.to_string() +
            exports +
            " reasons=" +
            entry.reasons.join(","),
          )
        }
      }
    }
    Err(e) => {
      println("keep-reasons failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_keep_reasons(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let mut closed_world = false
  let mut safe_mode = false
  for i in 3..<args.length() {
    if args[i] == "--closed-world" {
      closed_world = true
    }
    if args[i] == "--safe-mode" {
      safe_mode = true
    }
  }
  let closed_world_root_exports = parse_closed_world_roots(args, 3)
  run_keep_reasons_with_options(
    path, closed_world, safe_mode, closed_world_root_exports,
  )
}

///|
fn print_retain_path_entries(
  entries : Array[@wite.RetainPathEntry],
  limit : UInt,
) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let label = match entry.name {
      Some(v) => v
      None => "#\{entry.function_index.to_string()}"
    }
    let exports = if entry.export_names.length() == 0 {
      ""
    } else {
      " exports=" + entry.export_names.join(",")
    }
    let root_reasons = if entry.root_reasons.length() == 0 {
      "reachable"
    } else {
      entry.root_reasons.join(",")
    }
    let path = if entry.path.length() == 0 {
      "(none)"
    } else {
      entry.path.map(i => i.to_string()).join(" -> ")
    }
    println(
      "    " +
      label +
      " idx=" +
      entry.function_index.to_string() +
      " body=" +
      entry.body_bytes.to_string() +
      exports +
      " root=" +
      root_reasons +
      " path=" +
      path,
    )
    printed += 1U
  }
}

///|
fn run_retain_path_with_options(
  path : String,
  limit : UInt,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = @wite.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @wite.analyze_retain_paths(bytes, config~) {
    Ok(report) => {
      println("retain-path analysis:")
      println("  partial: " + report.partial.to_string())
      if report.roots.length() == 0 {
        println("  roots: (none)")
      } else {
        println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      }
      print_retain_path_entries(report.entries, limit)
    }
    Err(e) => {
      println("retain-path failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_retain_path(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let mut limit = 20U
  let mut closed_world = false
  let mut safe_mode = false
  for i in 3..<args.length() {
    let arg = args[i]
    if arg == "--closed-world" {
      closed_world = true
    } else if arg == "--safe-mode" {
      safe_mode = true
    } else if arg.has_prefix("--closed-world-root=") {
      ()
    } else if arg.has_prefix("--") {
      println("unknown retain-path option: " + arg)
      @sys.exit(1)
    } else {
      limit = parse_uint_or_exit(arg, "limit")
    }
  }
  let closed_world_root_exports = parse_closed_world_roots(args, 3)
  run_retain_path_with_options(
    path, limit, closed_world, safe_mode, closed_world_root_exports,
  )
}

///|
pub fn run_component_profile(path : String) -> Unit {
  @wite_component.run_component_profile(path)
}

///|
pub fn run_component_top_functions(path : String, limit : UInt) -> Unit {
  @wite_component.run_component_top_functions(path, limit)
}

///|
pub fn run_component_callgraph(path : String, limit : UInt) -> Unit {
  @wite_component.run_component_callgraph(path, limit)
}

///|
fn run_component_dce_kpi(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
  let excludes = parse_excluded_roots(args, 3)
  let mut wit_path : String? = None
  let mut safe_mode = false
  let mut verbose = false
  for i in 3..<args.length() {
    if args[i] == "--safe-mode" {
      safe_mode = true
    } else if args[i] == "--verbose" {
      verbose = true
    } else if not(args[i].has_prefix("--")) && wit_path is None {
      wit_path = Some(args[i])
    }
  }
  @wite_component.run_component_dce_kpi_with_options(
    component_path,
    wit_path,
    excludes,
    parse_closed_world_roots(args, 3),
    safe_mode,
    verbose,
  )
}

///|
fn run_contract(component_path : String, wit_path : String) -> Unit {
  @wite_component.run_contract(component_path, wit_path)
}

///|
fn run_root_policy(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
  let excludes = parse_excluded_roots(args, 3)
  let mut wit_path : String? = None
  for i in 3..<args.length() {
    if not(args[i].has_prefix("--")) && wit_path is None {
      wit_path = Some(args[i])
    }
  }
  @wite_component.run_root_policy_with_options(
    component_path, wit_path, excludes,
  )
}

///|
fn run_diff_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let left_path = args[2]
  let mut view = DiffView::Function
  let mut limit = 20U
  let mut baseline : DiffBaseline? = None
  let mut baseline_opt_level = "-Oz"
  let mut wasm_opt_bin_override : String? = None
  let wasm_opt_extra_args : Array[String] = []
  let positional : Array[String] = []
  for i in 3..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--view=") {
      Some(name) =>
        match parse_diff_view(name.to_string()) {
          Some(v) => view = v
          None => {
            println("unknown diff view: " + name.to_string())
            @sys.exit(1)
          }
        }
      None =>
        match arg.strip_prefix("--limit=") {
          Some(value) => limit = parse_uint_or_exit(value.to_string(), "limit")
          None =>
            match arg.strip_prefix("--baseline=") {
              Some(name) =>
                match parse_diff_baseline(name.to_string()) {
                  Some(v) => baseline = Some(v)
                  None => {
                    println("unknown diff baseline: " + name.to_string())
                    @sys.exit(1)
                  }
                }
              None =>
                match arg.strip_prefix("--wasm-opt-bin=") {
                  Some(path) => {
                    if path.is_empty() {
                      println("wasm-opt-bin must not be empty")
                      @sys.exit(1)
                    }
                    wasm_opt_bin_override = Some(path.to_string())
                  }
                  None =>
                    match arg.strip_prefix("--baseline-opt-level=") {
                      Some(level) =>
                        baseline_opt_level = parse_wasm_opt_level_or_exit(
                          level.to_string(),
                        )
                      None =>
                        match arg.strip_prefix("--baseline-arg=") {
                          Some(v) =>
                            if not(v.is_empty()) {
                              wasm_opt_extra_args.push(v.to_string())
                            }
                          None =>
                            if arg.has_prefix("--") {
                              println("unknown diff option: " + arg)
                              @sys.exit(1)
                            } else {
                              positional.push(arg)
                            }
                        }
                    }
                }
            }
        }
    }
  }
  if positional.length() > 1 {
    println("unexpected diff argument: " + positional[1])
    @sys.exit(1)
  }
  if positional.length() == 1 && baseline is Some(_) {
    println("cannot combine explicit right.wasm with --baseline")
    @sys.exit(1)
  }
  let mut generated_baseline_path : String? = None
  let right_path = if positional.length() == 1 {
    positional[0]
  } else {
    match baseline {
      Some(DiffBaseline::WasmOpt) => {
        let wasm_opt_bin = resolve_wasm_opt_bin(wasm_opt_bin_override)
        let output_path = js_make_temp_wasm_path("wite-diff-wasm-opt")
        run_wasm_opt_baseline_or_exit(
          left_path, output_path, wasm_opt_bin, baseline_opt_level, wasm_opt_extra_args,
        )
        generated_baseline_path = Some(output_path)
        output_path
      }
      None => {
        println("diff requires <right.wasm> or --baseline=wasm-opt")
        @sys.exit(1)
        ""
      }
    }
  }
  match view {
    DiffView::Function =>
      @wite_analyze.run_function_gap(left_path, right_path, limit)
    DiffView::Section =>
      @wite_analyze.run_section_gap(left_path, right_path, limit)
    DiffView::Block => @wite_analyze.run_block_gap(left_path, right_path, limit)
  }
  match generated_baseline_path {
    Some(path) => @fs.remove_file(path) catch { _ => () }
    None => ()
  }
}

///|
fn analyze_view_name(view : AnalyzeView) -> String {
  match view {
    AnalyzeView::Summary => "summary"
    AnalyzeView::Deep => "deep"
    AnalyzeView::Functions => "functions"
    AnalyzeView::Blocks => "blocks"
    AnalyzeView::Callgraph => "callgraph"
    AnalyzeView::Host => "host"
    AnalyzeView::Pipeline => "pipeline"
    AnalyzeView::Dce => "dce"
    AnalyzeView::Keep => "keep"
    AnalyzeView::Retain => "retain"
  }
}

///|
async fn run_analyze_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  auto_sync_deps_from_config_if_needed(config_selection)
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  let merged_flags = @wite_config.merge_command_flags(
    config_file.analyze_flags,
    config_selection.remaining_flags,
  )
  let mut view = AnalyzeView::Summary
  let mut kind = from_config_binary_kind(config_file.analyze_kind)
  let mut limit = 20U
  let mut diff_limit = 20U
  let mut config = @wite.OptimizeConfig::o1()
  let mut closed_world = false
  let mut safe_mode = false
  let closed_world_root_exports : Array[String] = []
  let positional : Array[String] = []
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "analyze kind")
      i += 2
      continue
    }
    match arg.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), "analyze kind")
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--view=") {
      Some(name) =>
        match parse_analyze_view(name.to_string()) {
          Some(v) => view = v
          None => {
            println("unknown analyze view: " + name.to_string())
            @sys.exit(1)
          }
        }
      None =>
        match arg.strip_prefix("--limit=") {
          Some(v) => limit = parse_uint_or_exit(v.to_string(), "limit")
          None =>
            match arg.strip_prefix("--diff-limit=") {
              Some(v) =>
                diff_limit = parse_uint_or_exit(v.to_string(), "diff-limit")
              None =>
                match arg.strip_prefix("--opt-level=") {
                  Some(v) => config = parse_opt_level_or_exit(v.to_string())
                  None =>
                    match arg.strip_prefix("--closed-world-root=") {
                      Some(root_name) =>
                        if not(root_name.is_empty()) {
                          closed_world_root_exports.push(root_name.to_string())
                        }
                      None =>
                        if arg == "--closed-world" {
                          closed_world = true
                        } else if arg == "--safe-mode" {
                          safe_mode = true
                        } else if arg.has_prefix("--") {
                          println("unknown analyze option: " + arg)
                          @sys.exit(1)
                        } else {
                          positional.push(arg)
                        }
                    }
                }
            }
        }
    }
    i += 1
  }
  if not(analyze_view_supports_kind(view, kind)) {
    println(
      "analyze view '" +
      analyze_view_name(view) +
      "' is not supported for kind=" +
      binary_kind_name(kind),
    )
    if kind is BinaryKind::Component {
      println("supported component analyze views: summary|functions|callgraph")
    }
    @sys.exit(1)
  }
  match view {
    AnalyzeView::Summary =>
      if positional.length() > 0 {
        println("unexpected analyze argument: " + positional[0])
        @sys.exit(1)
      }
    AnalyzeView::Deep
    | AnalyzeView::Functions
    | AnalyzeView::Blocks
    | AnalyzeView::Callgraph
    | AnalyzeView::Host
    | AnalyzeView::Dce => {
      if positional.length() > 1 {
        println("unexpected analyze argument: " + positional[1])
        @sys.exit(1)
      }
      if positional.length() == 1 {
        limit = parse_uint_or_exit(positional[0], "limit")
      }
    }
    AnalyzeView::Pipeline => {
      if positional.length() > 2 {
        println("unexpected analyze argument: " + positional[2])
        @sys.exit(1)
      }
      if positional.length() >= 1 {
        match
          @wite.optimize_config_from_opt_level(
            normalize_opt_level_token(positional[0]),
          ) {
          Some(v) => {
            config = v
            if positional.length() == 2 {
              diff_limit = parse_uint_or_exit(positional[1], "diff-limit")
            }
          }
          None => {
            diff_limit = parse_uint_or_exit(positional[0], "diff-limit")
            if positional.length() == 2 {
              println("unexpected analyze argument: " + positional[1])
              @sys.exit(1)
            }
          }
        }
      }
    }
    AnalyzeView::Keep =>
      if positional.length() > 0 {
        println("unexpected analyze argument: " + positional[0])
        @sys.exit(1)
      }
    AnalyzeView::Retain => {
      if positional.length() > 1 {
        println("unexpected analyze argument: " + positional[1])
        @sys.exit(1)
      }
      if positional.length() == 1 {
        limit = parse_uint_or_exit(positional[0], "limit")
      }
    }
  }
  match kind {
    BinaryKind::Component =>
      match view {
        AnalyzeView::Summary => @wite_component.run_component_profile(path)
        AnalyzeView::Functions =>
          @wite_component.run_component_top_functions(path, limit)
        AnalyzeView::Callgraph =>
          @wite_component.run_component_callgraph(path, limit)
        _ => {
          println(
            "analyze view '" +
            analyze_view_name(view) +
            "' is not supported for kind=component",
          )
          @sys.exit(1)
        }
      }
    BinaryKind::Auto | BinaryKind::Core =>
      match view {
        AnalyzeView::Summary => @wite_analyze.run_analyze(path)
        AnalyzeView::Deep => @wite_analyze.run_deep_analyze(path, limit)
        AnalyzeView::Functions => @wite_analyze.run_top_functions(path, limit)
        AnalyzeView::Blocks => @wite_analyze.run_block_sizes(path, limit)
        AnalyzeView::Callgraph => @wite_analyze.run_callgraph(path, limit)
        AnalyzeView::Host => @wite_analyze.run_analyze_host(path, limit)
        AnalyzeView::Pipeline =>
          @wite_analyze.run_analyze_opt(path, config, diff_limit)
        AnalyzeView::Dce => @wite_analyze.run_dce_report(path, limit)
        AnalyzeView::Keep =>
          @wite_analyze.run_keep_reasons_with_options(
            path, closed_world, safe_mode, closed_world_root_exports,
          )
        AnalyzeView::Retain =>
          @wite_analyze.run_retain_path_with_options(
            path, limit, closed_world, safe_mode, closed_world_root_exports,
          )
      }
  }
}

///|
async fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    @sys.exit(1)
  }
  match args[1] {
    "init" => run_init_command(args)
    "new" => run_new_command(args)
    "add" => @wite_deps.run_add_command(args, print_usage)
    "analyze" => run_analyze_command(args)
    "build" => run_build(args)
    "deps" => @wite_deps.run_deps_command(args, print_usage)
    "diff" => run_diff_command(args)
    "analyze-host" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_analyze_host(args[2], limit)
    }
    "analyze-opt" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let mut config = @wite.OptimizeConfig::o1()
      let mut diff_limit = 20U
      if args.length() >= 4 {
        match @wite.optimize_config_from_opt_level(args[3]) {
          Some(v) => {
            config = v
            if args.length() >= 5 {
              diff_limit = parse_uint_or_exit(args[4], "diff-limit")
            }
          }
          None => diff_limit = parse_uint_or_exit(args[3], "diff-limit")
        }
      }
      @wite_analyze.run_analyze_opt(args[2], config, diff_limit)
    }
    "deep-analyze" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_deep_analyze(args[2], limit)
    }
    "profile" => run_profile_command(args)
    "top-functions" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_top_functions(args[2], limit)
    }
    "function-gap" => {
      if args.length() < 4 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 5 {
        parse_uint_or_exit(args[4], "limit")
      } else {
        20U
      }
      @wite_analyze.run_function_gap(args[2], args[3], limit)
    }
    "block-sizes" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_block_sizes(args[2], limit)
    }
    "callgraph" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_callgraph(args[2], limit)
    }
    "keep-reasons" => run_keep_reasons(args)
    "retain-path" => run_retain_path(args)
    "dce-report" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_analyze.run_dce_report(args[2], limit)
    }
    "runtime-profile" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let mut iterations = 50U
      let mut has_iterations = false
      for i in 3..<args.length() {
        let arg = args[i]
        if arg.has_prefix("--scenario=") {
          ()
        } else if arg.has_prefix("--") {
          println("unknown runtime-profile option: " + arg)
          @sys.exit(1)
        } else if not(has_iterations) {
          iterations = parse_uint_or_exit(arg, "iterations")
          has_iterations = true
        } else {
          println("unexpected runtime-profile argument: " + arg)
          @sys.exit(1)
        }
      }
      let scenarios = parse_runtime_profile_scenarios(args, 3)
      @wite_analyze.run_runtime_profile(args[2], iterations, scenarios)
    }
    "hot-size" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let mut iterations = 50U
      let mut limit = 20U
      let mut has_iterations = false
      let mut has_limit = false
      for i in 3..<args.length() {
        let arg = args[i]
        if arg.has_prefix("--scenario=") {
          ()
        } else if arg.has_prefix("--") {
          println("unknown hot-size option: " + arg)
          @sys.exit(1)
        } else if not(has_iterations) {
          iterations = parse_uint_or_exit(arg, "iterations")
          has_iterations = true
        } else if not(has_limit) {
          limit = parse_uint_or_exit(arg, "limit")
          has_limit = true
        } else {
          println("unexpected hot-size argument: " + arg)
          @sys.exit(1)
        }
      }
      let scenarios = parse_runtime_profile_scenarios(args, 3)
      @wite_analyze.run_hot_size(args[2], iterations, limit, scenarios)
    }
    "optimize" => run_optimize(args)
    "component-profile" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      @wite_component.run_component_profile(args[2])
    }
    "component-top-functions" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_component.run_component_top_functions(args[2], limit)
    }
    "component-callgraph" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      @wite_component.run_component_callgraph(args[2], limit)
    }
    "component-dce-kpi" => run_component_dce_kpi(args)
    "contract" => {
      if args.length() < 4 {
        print_usage()
        @sys.exit(1)
      }
      run_contract(args[2], args[3])
    }
    "root-policy" => run_root_policy(args)
    _ => {
      print_usage()
      @sys.exit(1)
    }
  }
}
