///|
fn init_wite_config_template_text() -> String {
  let template =
    #|type WiteConfig = {
    #|  build?: { kind?: "auto" | "core" | "component"; flags?: string[] };
    #|  analyze?: { kind?: "auto" | "core" | "component"; flags?: string[] } | string[];
    #|  profile?: { kind?: "auto" | "core" | "component"; flags?: string[] } | string[];
    #|  input?: string | Record<string, string>;
    #|  output?: string | { dir?: string };
    #|  deps?: Record<string, string>;
    #|};
    #|
    #|export default {
    #|  build: { kind: "auto", flags: ["-Oz"] },
    #|  analyze: { kind: "core", flags: ["--view=summary"] },
    #|  profile: { kind: "auto", flags: [] },
    #|  deps: {},
    #|} satisfies WiteConfig;
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
fn write_init_file(path : String, content : String, force : Bool) -> Bool {
  if @fs.path_exists(path) && !force {
    return false
  }
  ensure_parent_dir(path)
  @fs.write_string_to_file(path, content) catch {
    e => {
      println(
        "failed to write file: " + path + " (" + @debug.render(Repr(e)) + ")",
      )
      @sys.exit(1)
    }
  }
  true
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
  let config_path = "wite.config.ts"
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
