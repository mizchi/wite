///|
fn componentize_wite_config_template_text() -> String {
  let template =
    #|{
    #|  "build": { "kind": "auto", "flags": ["-Oz"] },
    #|  "deps": {}
    #|}
    #|
  template
}

///|
fn componentize_wit_template_text(pkg_name : String) -> String {
  let ns = match pkg_name.find("/") {
    Some(i) => pkg_name[:i].to_string() catch { _ => pkg_name }
    None => pkg_name
  }
  let name = match pkg_name.find("/") {
    Some(i) => pkg_name[i + 1:].to_string() catch { _ => pkg_name }
    None => pkg_name
  }
  let lines : Array[String] = [
    "package " + ns + ":" + name + ";",
    "",
    "world app {",
    "    // export greet: func() -> string;",
    "}",
    "",
  ]
  lines.join("\n")
}

///|
fn read_package_name_from_moon_mod() -> String {
  if !@fs.path_exists("moon.mod.json") {
    return "my:component"
  }
  let text = @fs.read_file_to_string("moon.mod.json") catch {
    _ => return "my:component"
  }
  // Simple extraction of "name" field from JSON
  match text.find("\"name\"") {
    None => "my:component"
    Some(i) => {
      let rest = text[i + 6:].to_string() catch { _ => return "my:component" }
      match rest.find("\"") {
        None => "my:component"
        Some(j) => {
          let after_quote = rest[j + 1:].to_string() catch {
            _ => return "my:component"
          }
          match after_quote.find("\"") {
            None => "my:component"
            Some(k) => after_quote[:k].to_string() catch { _ => "my:component" }
          }
        }
      }
    }
  }
}

///|
fn run_componentize_scaffold(force : Bool) -> Unit {
  let pkg_name = read_package_name_from_moon_mod()

  let config_path = "wite.config.jsonc"
  let wit_path = "wit/world.wit"

  let config_written = write_init_file(
    config_path,
    componentize_wite_config_template_text(),
    force,
  )
  let wit_written = write_init_file(
    wit_path,
    componentize_wit_template_text(pkg_name),
    force,
  )

  if config_written {
    println("created: " + config_path)
  } else {
    println("kept: " + config_path)
  }
  if wit_written {
    println("created: " + wit_path)
  } else {
    println("kept: " + wit_path)
  }

  println("")
  let moon_pkg_hint =
    #|Add to moon.pkg:
    #|  options(
    #|    "link": {
    #|      "wasm": { "export-memory-name": "memory" },
    #|      "wasm-gc": { "export-memory-name": "memory" },
    #|    },
    #|  )
  println(moon_pkg_hint)
  println("")
  println("next:")
  println("  # edit wit/world.wit")
  println("  moon build --target wasm")
  println("  wite componentize <core.wasm> -o component/app.component.wasm")
}

///|
fn run_componentize_build(
  input_path : String,
  output_path : String?,
  _wit_dir : String?,
  _world_name : String?,
) -> Unit {
  let core_bytes = @wite_component.read_bytes_or_exit(input_path)

  match @wite_component.componentize_core_module(core_bytes) {
    Ok(result) => {
      let out_path = match output_path {
        Some(p) => p
        None => {
          // Derive output path from input
          let name = match input_path.rev_find("/") {
            Some(i) => input_path[i + 1:].to_string() catch { _ => input_path }
            None => input_path
          }
          let base = match name.rev_find(".") {
            Some(i) => name[:i].to_string() catch { _ => name }
            None => name
          }
          "component/" + base + ".component.wasm"
        }
      }
      js_ensure_parent_dir_for_file(out_path)
      @fs.write_bytes_to_file(out_path, result.bytes) catch {
        e => {
          println(
            "failed to write output: " + out_path + " (" + e.to_string() + ")",
          )
          @sys.exit(1)
        }
      }
      println("wrote: " + out_path)
      println(
        "exported " +
        result.exported_functions.length().to_string() +
        " functions: " +
        result.exported_functions.join(", "),
      )
    }
    Err(msg) => {
      println("componentize failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn print_componentize_usage() -> Unit {
  println("wite componentize [--force]")
  println("  Generate scaffold files (wite.config.jsonc, wit/world.wit)")
  println("")
  println("wite componentize <core.wasm> [options]")
  println("  Convert core wasm module to component wasm")
  println(
    "  -o <path>        Output path (default: component/<name>.component.wasm)",
  )
  println("  --wit <dir>      WIT directory (default: wit/)")
  println("  --world <name>   World name")
}

///|
fn run_componentize_command(args : Array[String]) -> Unit {
  let mut force = false
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut wit_dir : String? = None
  let mut world_name : String? = None

  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "--force" {
      force = true
    } else if arg == "-h" || arg == "--help" {
      print_componentize_usage()
      return
    } else if arg == "-o" {
      i += 1
      if i >= args.length() {
        println("missing value after -o")
        @sys.exit(1)
      }
      output_path = Some(args[i])
    } else if arg.strip_prefix("-o=") is Some(v) {
      output_path = Some(v.to_string())
    } else if arg == "--wit" {
      i += 1
      if i >= args.length() {
        println("missing value after --wit")
        @sys.exit(1)
      }
      wit_dir = Some(args[i])
    } else if arg.strip_prefix("--wit=") is Some(v) {
      wit_dir = Some(v.to_string())
    } else if arg == "--world" {
      i += 1
      if i >= args.length() {
        println("missing value after --world")
        @sys.exit(1)
      }
      world_name = Some(args[i])
    } else if arg.strip_prefix("--world=") is Some(v) {
      world_name = Some(v.to_string())
    } else if !arg.has_prefix("-") {
      input_path = Some(arg)
    } else {
      println("unknown componentize option: " + arg)
      print_componentize_usage()
      @sys.exit(1)
    }
    i += 1
  }

  match input_path {
    None => run_componentize_scaffold(force)
    Some(path) => run_componentize_build(path, output_path, wit_dir, world_name)
  }
}
