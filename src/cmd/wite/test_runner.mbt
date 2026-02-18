///|
priv struct TestResult {
  name : String
  passed : Bool
  message : String
}

///|
fn format_test_results(results : Array[TestResult]) -> String {
  let lines : Array[String] = []
  let mut pass_count = 0
  let mut fail_count = 0
  for result in results {
    if result.passed {
      pass_count += 1
      lines.push("[wite] PASS: " + result.name)
    } else {
      fail_count += 1
      lines.push("[wite] FAIL: " + result.name)
      if !result.message.is_empty() {
        lines.push("[wite]   " + result.message)
      }
    }
  }
  lines.push(
    "[wite] " +
    pass_count.to_string() +
    " passed, " +
    fail_count.to_string() +
    " failed",
  )
  lines.join("\n")
}

///|
async fn run_contract_tests(
  wasm_path : String,
  interface_path : String,
  world : String?,
) -> Array[TestResult] {
  let results : Array[TestResult] = []
  let data = @xfs.read_file(wasm_path) catch {
    _ => {
      results.push({
        name: "read wasm",
        passed: false,
        message: "failed to read: " + wasm_path,
      })
      return results
    }
  }
  let bytes = data.binary()
  // Test 1: verify_component_interface
  let verify_result = match world {
    Some(w) =>
      @wite_component.verify_component_interface(bytes, interface_path, world=w)
    None => @wite_component.verify_component_interface(bytes, interface_path)
  }
  match verify_result {
    Ok(_) => {
      let resolved = match world {
        Some(w) => @wit.resolve_path(interface_path, world=w)
        None => @wit.resolve_path(interface_path)
      }
      let detail = match resolved {
        Ok(r) =>
          match @wite.analyze_component_contract(bytes, r) {
            Ok(report) =>
              "exports: " +
              report.component_exports.length().to_string() +
              ", imports: " +
              report.component_imports.length().to_string()
            Err(_) => ""
          }
        Err(_) => ""
      }
      results.push({
        name: "interface conforms to WIT" +
        (if detail.is_empty() { "" } else { " (" + detail + ")" }),
        passed: true,
        message: "",
      })
    }
    Err(msg) =>
      results.push({
        name: "interface conforms to WIT",
        passed: false,
        message: msg,
      })
  }
  // Test 2: contract analysis — check for missing exports/imports
  let resolved = match world {
    Some(w) => @wit.resolve_path(interface_path, world=w)
    None => @wit.resolve_path(interface_path)
  }
  match resolved {
    Ok(r) =>
      match @wite.analyze_component_contract(bytes, r) {
        Ok(report) => {
          if report.missing_component_exports.length() > 0 {
            results.push({
              name: "missing component exports: [" +
              report.missing_component_exports.join(", ") +
              "]",
              passed: false,
              message: "",
            })
          }
          if report.missing_component_imports.length() > 0 {
            results.push({
              name: "missing component imports: [" +
              report.missing_component_imports.join(", ") +
              "]",
              passed: false,
              message: "",
            })
          }
        }
        Err(msg) =>
          results.push({
            name: "contract analysis",
            passed: false,
            message: msg,
          })
      }
    Err(e) =>
      results.push({
        name: "contract analysis",
        passed: false,
        message: "wit resolve failed: " + e.to_string(),
      })
  }
  results
}

///|
async fn run_test_command(args : Array[String]) -> Unit {
  let mut dir = "."
  let mut target = "wasm"
  let mut interface_path : String? = None
  let mut world : String? = None
  let mut watch = false
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      println(
        "wite test [dir] [--target=<t>] [--interface=<wit-dir>] [--world=<world>] [--watch]",
      )
      println("")
      println("Build and run WIT contract tests.")
      println("")
      println("Options:")
      println("  --target=<t>         Build target (default: wasm)")
      println(
        "  --interface=<wit-dir> WIT interface directory for contract tests",
      )
      println("  --world=<world>      WIT world name")
      println("  --watch              Watch for changes and re-test")
      return
    }
    if arg == "--watch" {
      watch = true
      i += 1
      continue
    }
    if arg.strip_prefix("--target=") is Some(v) {
      target = v.to_string()
      i += 1
      continue
    }
    if arg == "--target" {
      if i + 1 >= args.length() {
        println("missing value after --target")
        @sys.exit(1)
      }
      target = args[i + 1]
      i += 2
      continue
    }
    if arg.strip_prefix("--interface=") is Some(v) {
      interface_path = Some(v.to_string())
      i += 1
      continue
    }
    if arg == "--interface" {
      if i + 1 >= args.length() {
        println("missing value after --interface")
        @sys.exit(1)
      }
      interface_path = Some(args[i + 1])
      i += 2
      continue
    }
    if arg.strip_prefix("--world=") is Some(v) {
      world = Some(v.to_string())
      i += 1
      continue
    }
    if arg == "--world" {
      if i + 1 >= args.length() {
        println("missing value after --world")
        @sys.exit(1)
      }
      world = Some(args[i + 1])
      i += 2
      continue
    }
    if arg.has_prefix("-") {
      println("unknown option: " + arg)
      @sys.exit(1)
    }
    dir = arg
    i += 1
  }
  let mod_path = if dir == "." {
    "moon.mod.json"
  } else {
    dir + "/moon.mod.json"
  }
  if !@fs.path_exists(mod_path) {
    println("error: " + mod_path + " not found")
    println("not a MoonBit project directory")
    @sys.exit(1)
  }
  let cwd : StringView? = if dir == "." { None } else { Some(dir) }
  let run_once = async fn() -> Bool {
    // Step 1: Build
    println(
      "[wite] building with moon build --target " + target + " --release ...",
    )
    let build_args : Array[String] = ["build", "--target", target, "--release"]
    let (exit_code, _stdout, stderr) = @xprocess.collect_output(
      "moon",
      build_args,
      cwd?,
    )
    if exit_code != 0 {
      let err_text = stderr.text() catch { _ => "unknown error" }
      println("[wite] build failed:\n" + err_text)
      return false
    }
    println("[wite] build succeeded")
    // Step 2: Find wasm
    let wasm_path = find_wasm_in_build_dirs(dir, target, release=true)
    match wasm_path {
      None => {
        println("[wite] error: no .wasm file found in build output")
        return false
      }
      Some(abs_wasm_path) => {
        let rel_wasm = make_relative_path(dir, abs_wasm_path)
        println("[wite] found: " + rel_wasm)
        let results : Array[TestResult] = [
          { name: "build succeeded", passed: true, message: "" },
        ]
        // Step 3: Contract tests
        if interface_path is Some(iface) {
          let contract_results = run_contract_tests(abs_wasm_path, iface, world)
          results.append(contract_results[:])
        }
        // Step 4: Report
        let report = format_test_results(results)
        println(report)
        let has_failure = results.iter().any(fn(r) { !r.passed })
        !has_failure
      }
    }
  }
  if watch {
    // Watch mode: poll and rebuild on wasm change
    let mut last_hash = 0
    while true {
      let all_passed = run_once()
      // Compute hash of current wasm for change detection
      let wasm_path = find_wasm_in_build_dirs(dir, target, release=true)
      match wasm_path {
        Some(p) => {
          let data = @xfs.read_file(p) catch { _ => continue }
          last_hash = simple_bytes_hash(data.binary())
        }
        None => ()
      }
      ignore(all_passed)
      // Wait for changes
      println("[wite] watching for changes...")
      while true {
        @async.sleep(1000)
        let wasm_path2 = find_wasm_in_build_dirs(dir, target, release=true)
        match wasm_path2 {
          Some(p) => {
            let data = @xfs.read_file(p) catch { _ => continue }
            let new_hash = simple_bytes_hash(data.binary())
            if new_hash != last_hash {
              last_hash = new_hash
              println("")
              break
            }
          }
          None => ()
        }
      }
    }
  } else {
    let all_passed = run_once()
    if !all_passed {
      @sys.exit(1)
    }
  }
}
