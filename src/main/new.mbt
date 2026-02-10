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
