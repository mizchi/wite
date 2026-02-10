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
fn path_basename(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => path[index + 1:].to_string() catch { _ => path }
    None => path
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
    Some(i) =>
      if i == 0 {
        if path.has_prefix("\\") {
          "\\"
        } else {
          "/"
        }
      } else {
        path[:i].to_string() catch {
          _ => "."
        }
      }
    None => "."
  }
}

///|
fn is_absolute_path(path : String) -> Bool {
  if path.has_prefix("/") || path.has_prefix("\\") {
    return true
  }
  match path.find(":") {
    Some(i) if i == 1 && path.length() >= 3 => {
      let sep = path[2:3].to_string() catch { _ => "" }
      sep == "/" || sep == "\\"
    }
    _ => false
  }
}

///|
fn resolve_path_from_config_dir(config_dir : String, path : String) -> String {
  if config_dir == "." || config_dir.is_empty() || is_absolute_path(path) {
    return path
  }
  if config_dir == "/" || config_dir == "\\" {
    return config_dir + path
  }
  config_dir + "/" + path
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
fn new_gitignore_template_text(template : NewTemplateKind) -> String {
  let lines : Array[String] = ["deps/", "composed.wasm"]
  match template {
    NewTemplateKind::Moonbit => {
      lines.push("target/")
      lines.push(".mooncakes/")
    }
    NewTemplateKind::Rust => lines.push("target/")
  }
  lines.push("")
  lines.join("\n")
}

///|
fn collect_new_template_files(
  template : NewTemplateKind,
) -> Array[NewTemplateFile] {
  let files : Array[NewTemplateFile] = [
    { path: ".gitignore", content: new_gitignore_template_text(template) },
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
async fn run_install_command(args : Array[String]) -> Unit {
  // Rewrite args as: [bin, "deps", "sync", ...rest]
  let synth : Array[String] = [args[0], "deps", "sync"]
  for i in 2..<args.length() {
    synth.push(args[i])
  }
  @wite_deps.run_deps_sync_command(synth, print_usage)
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
