///|
test "format percent handles large values without overflow" {
  assert_eq(format_percent(28900415U, 39362651U), "73.42%")
}

///|
test "format percent handles full ratio" {
  assert_eq(format_percent(171100U, 171100U), "100.00%")
}

///|
test "format percent handles zero denominator" {
  assert_eq(format_percent(1U, 0U), "0.00%")
}

///|
test "parse analyze view supports canonical and alias names" {
  assert_true(parse_analyze_view("summary") is Some(AnalyzeView::Summary))
  assert_true(parse_analyze_view("deep") is Some(AnalyzeView::Deep))
  assert_true(parse_analyze_view("functions") is Some(AnalyzeView::Functions))
  assert_true(
    parse_analyze_view("top-functions") is Some(AnalyzeView::Functions),
  )
  assert_true(parse_analyze_view("blocks") is Some(AnalyzeView::Blocks))
  assert_true(parse_analyze_view("block-sizes") is Some(AnalyzeView::Blocks))
  assert_true(parse_analyze_view("callgraph") is Some(AnalyzeView::Callgraph))
  assert_true(parse_analyze_view("host") is Some(AnalyzeView::Host))
  assert_true(parse_analyze_view("pipeline") is Some(AnalyzeView::Pipeline))
  assert_true(parse_analyze_view("dce") is Some(AnalyzeView::Dce))
  assert_true(parse_analyze_view("keep") is Some(AnalyzeView::Keep))
  assert_true(parse_analyze_view("retain") is Some(AnalyzeView::Retain))
  assert_true(parse_analyze_view("unknown") is None)
}

///|
test "parse binary kind supports auto core component" {
  assert_true(parse_binary_kind("auto") is Some(BinaryKind::Auto))
  assert_true(parse_binary_kind("core") is Some(BinaryKind::Core))
  assert_true(parse_binary_kind("component") is Some(BinaryKind::Component))
  assert_true(parse_binary_kind("unknown") is None)
}

///|
test "extract binary kind flag keeps non-kind flags and default kind" {
  let parsed = extract_binary_kind_flags(
    ["-Oz", "--strip-debug"],
    BinaryKind::Auto,
    "optimize kind",
  )
  assert_true(parsed.kind is BinaryKind::Auto)
  assert_eq(parsed.flags, ["-Oz", "--strip-debug"])
}

///|
test "extract binary kind flag supports equals and separate forms" {
  let parsed1 = extract_binary_kind_flags(
    ["--kind=component", "-Oz", "--closed-world"],
    BinaryKind::Auto,
    "optimize kind",
  )
  assert_true(parsed1.kind is BinaryKind::Component)
  assert_eq(parsed1.flags, ["-Oz", "--closed-world"])
  let parsed2 = extract_binary_kind_flags(
    ["--kind", "core", "--strip-debug"],
    BinaryKind::Auto,
    "optimize kind",
  )
  assert_true(parsed2.kind is BinaryKind::Core)
  assert_eq(parsed2.flags, ["--strip-debug"])
}

///|
test "derive preset from wasm-opt levels prioritizes shrink level" {
  assert_true(derive_preset_from_wasm_opt_levels(None, None) is None)
  guard derive_preset_from_wasm_opt_levels(Some(1U), Some(2U))
    is Some(oz_preset) else {
    fail("expected oz preset from shrink-level=2")
  }
  let expected_oz = @wite.OptimizeConfig::oz()
  assert_eq(oz_preset.pass_rounds, expected_oz.pass_rounds)
  assert_eq(oz_preset.enable_dce, expected_oz.enable_dce)
  guard derive_preset_from_wasm_opt_levels(Some(3U), Some(0U))
    is Some(o3_preset) else {
    fail("expected o3 preset from optimize-level=3")
  }
  let expected_o3 = @wite.OptimizeConfig::o3()
  assert_eq(o3_preset.pass_rounds, expected_o3.pass_rounds)
  assert_eq(o3_preset.enable_dce, expected_o3.enable_dce)
}

///|
test "parse optimize cli options accepts wasm-opt style aliases" {
  let parsed = parse_optimize_cli_options([
    "--optimize-level=2", "--shrink-level=2", "--dce", "--duplicate-function-elimination",
    "--merge-similar-functions", "--remove-unused-module-elements", "--all-features",
    "--enable-gc", "-c", "--rounds", "3", "-cw", "--verbose",
  ])
  assert_eq(parsed.config.pass_rounds, 3U)
  assert_true(parsed.config.enable_dce)
  assert_true(parsed.config.enable_dfe)
  assert_true(parsed.config.enable_merge_similar_functions)
  assert_true(parsed.config.enable_remove_unused_module_elements)
  assert_true(parsed.config.closed_world)
  assert_true(parsed.verbose)
  let parsed_short = parse_optimize_cli_options(["-ol", "1", "-s", "0"])
  let expected_o1 = @wite.OptimizeConfig::o1()
  assert_eq(parsed_short.config.pass_rounds, expected_o1.pass_rounds)
  assert_eq(parsed_short.config.enable_dce, expected_o1.enable_dce)
}

///|
test "parse optimize cli options supports debuginfo alias override" {
  let parsed = parse_optimize_cli_options(["--strip", "-g"])
  assert_true(not(parsed.config.strip_debug_sections))
  assert_true(not(parsed.config.strip_name_section))
}

///|
test "analyze view support matrix distinguishes component compatible views" {
  assert_true(
    analyze_view_supports_kind(AnalyzeView::Summary, BinaryKind::Component),
  )
  assert_true(
    analyze_view_supports_kind(AnalyzeView::Functions, BinaryKind::Component),
  )
  assert_true(
    analyze_view_supports_kind(AnalyzeView::Callgraph, BinaryKind::Component),
  )
  assert_true(
    not(analyze_view_supports_kind(AnalyzeView::Deep, BinaryKind::Component)),
  )
  assert_true(analyze_view_supports_kind(AnalyzeView::Deep, BinaryKind::Core))
}

///|
test "derive build output path from input extension" {
  assert_eq(derive_build_output_path("foo.wac"), "foo.wasm")
  assert_eq(derive_build_output_path("foo.wasm"), "foo.min.wasm")
  assert_eq(derive_build_output_path("foo.bar"), "foo.bar.wasm")
}

///|
test "derive implicit build output path prefers composed.wasm for main.wac" {
  assert_eq(derive_implicit_build_output_path("main.wac"), "composed.wasm")
  assert_eq(derive_implicit_build_output_path("main.wasm"), "main.min.wasm")
}

///|
test "pick default build input prefers main.wac then main.wasm" {
  assert_eq(pick_default_build_input_path(true, true), Some("main.wac"))
  assert_eq(pick_default_build_input_path(false, true), Some("main.wasm"))
  assert_eq(pick_default_build_input_path(false, false), None)
}

///|
test "resolve build input accepts omitted entry with default" {
  guard resolve_build_input_from_args(["wite", "build"], Some("main.wac"))
    is Ok(resolved) else {
    fail("expected default build input resolution")
  }
  assert_eq(resolved.input_path, "main.wac")
  assert_eq(resolved.raw_flags, [])
  assert_true(not(resolved.explicit_input))
}

///|
test "resolve build input accepts flags-only invocation with default" {
  guard resolve_build_input_from_args(
      ["wite", "build", "-Oz"],
      Some("main.wac"),
    )
    is Ok(resolved) else {
    fail("expected flags-only build input resolution")
  }
  assert_eq(resolved.input_path, "main.wac")
  assert_eq(resolved.raw_flags, ["-Oz"])
  assert_true(not(resolved.explicit_input))
}

///|
test "resolve build input keeps explicit entry and trailing flags" {
  guard resolve_build_input_from_args(
      ["wite", "build", "app.wac", "-Oz", "--best-effort"],
      Some("main.wac"),
    )
    is Ok(resolved) else {
    fail("expected explicit build input resolution")
  }
  assert_eq(resolved.input_path, "app.wac")
  assert_eq(resolved.raw_flags, ["-Oz", "--best-effort"])
  assert_true(resolved.explicit_input)
}

///|
test "resolve build input fails without explicit entry or default" {
  assert_true(resolve_build_input_from_args(["wite", "build"], None) is Err(_))
  assert_true(
    resolve_build_input_from_args(["wite", "build", "-Oz"], None) is Err(_),
  )
}

///|
test "path dirname handles root and relative paths" {
  assert_eq(path_dirname("foo.wac"), ".")
  assert_eq(path_dirname("examples/compose/app.wac"), "examples/compose")
  assert_eq(path_dirname("/tmp/app.wac"), "/tmp")
  assert_eq(path_dirname("C:\\tmp\\app.wac"), "C:\\tmp")
}

///|
test "resolve config path keeps absolute paths and joins relative paths" {
  assert_eq(resolve_path_from_config_dir(".", "app.wasm"), "app.wasm")
  assert_eq(
    resolve_path_from_config_dir("examples/compose", "app.wasm"),
    "examples/compose/app.wasm",
  )
  assert_eq(
    resolve_path_from_config_dir("examples/compose", "/tmp/app.wasm"),
    "/tmp/app.wasm",
  )
  assert_eq(
    resolve_path_from_config_dir("examples/compose", "C:/tmp/app.wasm"),
    "C:/tmp/app.wasm",
  )
  assert_eq(
    resolve_path_from_config_dir("examples/compose", "C:\\tmp\\app.wasm"),
    "C:\\tmp\\app.wasm",
  )
  assert_eq(
    resolve_path_from_config_dir(
      "examples/compose", "\\\\server\\share\\app.wasm",
    ),
    "\\\\server\\share\\app.wasm",
  )
}

///|
test "build wac dep target path follows mwac deps layout" {
  assert_eq(
    @wite_bundle.build_wac_dep_target_path(
      "examples/compose", "example", "hello",
    ),
    "examples/compose/deps/example/hello.wasm",
  )
}

///|
test "collect wac new package names extracts instantiated packages" {
  let source =
    #|package example:composition;
    #|let hello = new example:hello {};
    #|let greeter = new example:greeter { hello: hello.hello };
    #|export greeter.greet;
    #|
  guard @wite_bundle.collect_wac_new_package_names(source) is Ok(packages) else {
    fail("expected valid wac package extraction")
  }
  assert_eq(packages, ["example:hello", "example:greeter"])
}

///|
test "init templates include quickstart defaults" {
  let config = init_wite_config_template_text()
  assert_true(config.contains("\"build\""))
  assert_true(config.contains("\"deps\""))
  let wac = init_main_wac_template_text()
  assert_true(wac.contains("wite add dep:a"))
  assert_true(wac.contains("let a = new dep:a {}"))
}

///|
test "parse new command options supports moonbit rust and force" {
  guard parse_new_command_options(["wite", "new"]) is Ok(default_opts) else {
    fail("expected default new command options")
  }
  assert_true(default_opts.template is NewTemplateKind::Moonbit)
  assert_true(not(default_opts.force))
  guard parse_new_command_options(["wite", "new", "--rust", "--force"])
    is Ok(rust_opts) else {
    fail("expected rust template options")
  }
  assert_true(rust_opts.template is NewTemplateKind::Rust)
  assert_true(rust_opts.force)
  assert_true(
    parse_new_command_options(["wite", "new", "--moonbit", "--rust"]) is Err(_),
  )
  assert_true(parse_new_command_options(["wite", "new", "--unknown"]) is Err(_))
}

///|
test "new templates include build commands for each toolchain" {
  let moonbit = new_moonbit_guest_mbt_template_text()
  assert_true(moonbit.contains("pub fn greet"))
  let rust_toml = new_rust_cargo_toml_template_text()
  assert_true(rust_toml.contains("[package.metadata.component]"))
  let rust_main = new_rust_main_template_text()
  assert_true(rust_main.contains("fn main()"))
}

///|
extern "js" fn js_make_temp_dir(prefix : String) -> String =
  #| (prefix) => {
  #|   const os = require('node:os');
  #|   const fs = require('node:fs');
  #|   const path = require('node:path');
  #|   const safe = String(prefix || 'wite-test').replace(/[^a-zA-Z0-9._-]/g, '-');
  #|   return fs.mkdtempSync(path.join(os.tmpdir(), safe));
  #| }

///|
extern "js" fn js_run_command_in_dir(
  command : String,
  args_spec : String,
  cwd : String,
) -> String =
  #| (command, argsSpec, cwd) => {
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 8192);
  #|   try {
  #|     const { spawnSync } = require('node:child_process');
  #|     const args = String(argsSpec || '').length > 0 ? String(argsSpec).split('\t') : [];
  #|     const result = spawnSync(String(command), args, {
  #|       cwd: String(cwd),
  #|       encoding: 'utf8',
  #|     });
  #|     if (result.error) {
  #|       return 'err\tspawn\t' + sanitize(result.error.message || result.error);
  #|     }
  #|     const status = (result.status == null) ? 255 : result.status;
  #|     return [
  #|       'ok',
  #|       String(status),
  #|       sanitize(result.stdout || ''),
  #|       sanitize(result.stderr || ''),
  #|     ].join('\t');
  #|   } catch (e) {
  #|     const detail = (e && (e.stack || e.message)) ? (e.stack || e.message) : e;
  #|     return 'err\texception\t' + sanitize(detail);
  #|   }
  #| }

///|
priv struct CommandRunResult {
  status : Int
  stdout : String
  stderr : String
}

///|
fn parse_command_run_result(raw : String) -> Result[CommandRunResult, String] {
  let parts : Array[String] = []
  for part in raw.split("\t") {
    parts.push(part.to_string())
  }
  if parts.length() == 0 {
    return Err("empty command result")
  }
  if parts[0] != "ok" {
    let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
    let detail = if parts.length() >= 3 { parts[2] } else { raw }
    return Err(stage + ": " + detail)
  }
  if parts.length() < 4 {
    return Err("invalid command result format: " + raw)
  }
  let status = parse_uint_or_exit(parts[1], "command status").reinterpret_as_int()
  Ok({ status, stdout: parts[2], stderr: parts[3] })
}

///|
test "new --moonbit generates buildable moonbit guest template" {
  let temp_dir = js_make_temp_dir("wite-new-moonbit-")
  let original_cwd = js_get_process_cwd()
  let cd_error = js_set_process_cwd(temp_dir)
  if not(cd_error.is_empty()) {
    js_remove_dir_recursive(temp_dir)
    fail("failed to chdir to moonbit template workspace: " + cd_error)
  }
  run_new_command(["wite", "new", "--moonbit"])
  let restore_error = js_set_process_cwd(original_cwd)
  if not(restore_error.is_empty()) {
    js_remove_dir_recursive(temp_dir)
    fail(
      "failed to restore cwd after moonbit template generation: " +
      restore_error,
    )
  }
  assert_true(@fs.path_exists(temp_dir + "/wite.config.jsonc"))
  assert_true(@fs.path_exists(temp_dir + "/main.wac"))
  assert_true(@fs.path_exists(temp_dir + "/guest/moonbit/moon.mod.json"))
  let raw = js_run_command_in_dir(
    "moon",
    "build\t--target\tjs",
    temp_dir + "/guest/moonbit",
  )
  let result = match parse_command_run_result(raw) {
    Ok(v) => v
    Err(msg) => {
      js_remove_dir_recursive(temp_dir)
      fail("failed to run moon build in moonbit template: " + msg)
      { status: -1, stdout: "", stderr: "" }
    }
  }
  js_remove_dir_recursive(temp_dir)
  if result.status != 0 {
    fail(
      "moonbit template build failed (status=" +
      result.status.to_string() +
      "): " +
      result.stderr +
      " stdout=" +
      result.stdout,
    )
  }
}

///|
test "new --rust generates cargo-component template and build command works" {
  let temp_dir = js_make_temp_dir("wite-new-rust-")
  let original_cwd = js_get_process_cwd()
  let cd_error = js_set_process_cwd(temp_dir)
  if not(cd_error.is_empty()) {
    js_remove_dir_recursive(temp_dir)
    fail("failed to chdir to rust template workspace: " + cd_error)
  }
  run_new_command(["wite", "new", "--rust"])
  let restore_error = js_set_process_cwd(original_cwd)
  if not(restore_error.is_empty()) {
    js_remove_dir_recursive(temp_dir)
    fail(
      "failed to restore cwd after rust template generation: " + restore_error,
    )
  }
  let rust_dir = temp_dir + "/guest/rust"
  assert_true(@fs.path_exists(rust_dir + "/Cargo.toml"))
  assert_true(@fs.path_exists(rust_dir + "/src/main.rs"))
  let raw = js_run_command_in_dir(
    "cargo", "component\tbuild\t--quiet", rust_dir,
  )
  let result = match parse_command_run_result(raw) {
    Ok(v) => v
    Err(msg) => {
      js_remove_dir_recursive(temp_dir)
      fail("failed to run cargo component build: " + msg)
      { status: -1, stdout: "", stderr: "" }
    }
  }
  if result.status != 0 {
    let known_env_issue = result.stderr.contains("wasm32-wasip1") ||
      result.stderr.contains("wasm32-wasip2") ||
      result.stderr.contains("rustup is not available") ||
      result.stderr.contains("no such command")
    if known_env_issue {
      let fallback_raw = js_run_command_in_dir(
        "cargo", "build\t--quiet", rust_dir,
      )
      let fallback = match parse_command_run_result(fallback_raw) {
        Ok(v) => v
        Err(msg) => {
          js_remove_dir_recursive(temp_dir)
          fail("failed to run fallback cargo build: " + msg)
          { status: -1, stdout: "", stderr: "" }
        }
      }
      js_remove_dir_recursive(temp_dir)
      if fallback.status != 0 {
        fail(
          "rust template fallback build failed (status=" +
          fallback.status.to_string() +
          "): " +
          fallback.stderr +
          " stdout=" +
          fallback.stdout,
        )
      }
      return
    }
    js_remove_dir_recursive(temp_dir)
    fail(
      "cargo component build failed (status=" +
      result.status.to_string() +
      "): " +
      result.stderr +
      " stdout=" +
      result.stdout,
    )
  }
  js_remove_dir_recursive(temp_dir)
}

///|
extern "js" fn js_prepare_build_bundle_fixture_workspace() -> String =
  #| () => {
  #|   const fs = require('node:fs');
  #|   const os = require('node:os');
  #|   const path = require('node:path');
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   const findRepoRoot = () => {
  #|     let dir = process.cwd();
  #|     while (true) {
  #|       if (fs.existsSync(path.join(dir, 'moon.mod.json')) &&
  #|           fs.existsSync(path.join(dir, 'src', 'main', 'main.mbt'))) {
  #|         return dir;
  #|       }
  #|       const parent = path.dirname(dir);
  #|       if (parent === dir) {
  #|         throw new Error('failed to locate repository root from cwd=' + process.cwd());
  #|       }
  #|       dir = parent;
  #|     }
  #|   };
  #|   try {
  #|     const repoRoot = findRepoRoot();
  #|     const fixtureDir = path.join(
  #|       repoRoot,
  #|       'bench',
  #|       'corpus',
  #|       'component-dce',
  #|       'wite-build-fixture',
  #|     );
  #|     if (!fs.existsSync(fixtureDir)) {
  #|       throw new Error('missing bundle fixture directory: ' + fixtureDir);
  #|     }
  #|     const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wite-build-fixture-'));
  #|     fs.cpSync(fixtureDir, tmpDir, { recursive: true });
  #|     const mainWacPath = path.join(tmpDir, 'main.wac');
  #|     if (!fs.existsSync(mainWacPath)) {
  #|       throw new Error('missing main.wac in fixture directory: ' + fixtureDir);
  #|     }
  #|     const explicitPath = path.join(tmpDir, 'explicit.wasm');
  #|     const composedPath = path.join(tmpDir, 'composed.wasm');
  #|     return [
  #|       'ok',
  #|       sanitize(tmpDir),
  #|       sanitize(mainWacPath),
  #|       sanitize(explicitPath),
  #|       sanitize(composedPath),
  #|     ].join('\t');
  #|   } catch (e) {
  #|     const message = e && (e.stack || e.message) ? (e.stack || e.message) : String(e);
  #|     return 'err\texception\t' + sanitize(message);
  #|   }
  #| }

///|
extern "js" fn js_prepare_example_sample_app_workspace() -> String =
  #| () => {
  #|   const fs = require('node:fs');
  #|   const os = require('node:os');
  #|   const path = require('node:path');
  #|   const sanitize = (value) => String(value ?? '')
  #|     .replace(/\r?\n/g, ' ')
  #|     .replace(/\t/g, ' ')
  #|     .slice(0, 4096);
  #|   const findRepoRoot = () => {
  #|     let dir = process.cwd();
  #|     while (true) {
  #|       if (fs.existsSync(path.join(dir, 'moon.mod.json')) &&
  #|           fs.existsSync(path.join(dir, 'src', 'main', 'main.mbt'))) {
  #|         return dir;
  #|       }
  #|       const parent = path.dirname(dir);
  #|       if (parent === dir) {
  #|         throw new Error('failed to locate repository root from cwd=' + process.cwd());
  #|       }
  #|       dir = parent;
  #|     }
  #|   };
  #|   try {
  #|     const repoRoot = findRepoRoot();
  #|     const sampleDir = path.join(repoRoot, 'examples', 'sample_app');
  #|     if (!fs.existsSync(sampleDir)) {
  #|       throw new Error('missing sample_app directory: ' + sampleDir);
  #|     }
  #|     const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wite-sample-app-'));
  #|     fs.cpSync(sampleDir, tmpDir, { recursive: true });
  #|     const mainWacPath = path.join(tmpDir, 'main.wac');
  #|     if (!fs.existsSync(mainWacPath)) {
  #|       throw new Error('missing main.wac in sample_app directory: ' + sampleDir);
  #|     }
  #|     const outputPath = path.join(tmpDir, 'sample.composed.wasm');
  #|     return [
  #|       'ok',
  #|       sanitize(tmpDir),
  #|       sanitize(mainWacPath),
  #|       sanitize(outputPath),
  #|     ].join('\t');
  #|   } catch (e) {
  #|     const message = e && (e.stack || e.message) ? (e.stack || e.message) : String(e);
  #|     return 'err\texception\t' + sanitize(message);
  #|   }
  #| }

///|
extern "js" fn js_get_process_cwd() -> String =
  #| () => process.cwd()

///|
extern "js" fn js_set_process_cwd(path : String) -> String =
  #| (path) => {
  #|   try {
  #|     process.chdir(String(path));
  #|     return '';
  #|   } catch (e) {
  #|     return String(e && (e.stack || e.message) ? (e.stack || e.message) : e);
  #|   }
  #| }

///|
extern "js" fn js_remove_dir_recursive(path : String) -> Unit =
  #| (path) => {
  #|   try {
  #|     const fs = require('node:fs');
  #|     fs.rmSync(String(path), { recursive: true, force: true });
  #|   } catch (_) {}
  #| }

///|
extern "js" fn js_remove_file(path : String) -> Unit =
  #| (path) => {
  #|   try {
  #|     const fs = require('node:fs');
  #|     fs.rmSync(String(path), { force: true });
  #|   } catch (_) {}
  #| }

///|
priv struct BuildBundleFixtureWorkspace {
  temp_dir : String
  main_wac_path : String
  explicit_path : String
  composed_path : String
}

///|
priv struct ExampleSampleAppWorkspace {
  temp_dir : String
  main_wac_path : String
  output_path : String
}

///|
fn parse_build_bundle_fixture_workspace(
  raw : String,
) -> Result[BuildBundleFixtureWorkspace, String] {
  let parts : Array[String] = []
  for part in raw.split("\t") {
    parts.push(part.to_string())
  }
  if parts.length() == 0 {
    return Err("empty smoke result")
  }
  if parts[0] != "ok" {
    let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
    let detail = if parts.length() >= 3 { parts[2] } else { raw }
    return Err(stage + ": " + detail)
  }
  if parts.length() < 5 {
    return Err("invalid fixture workspace format: " + raw)
  }
  Ok({
    temp_dir: parts[1],
    main_wac_path: parts[2],
    explicit_path: parts[3],
    composed_path: parts[4],
  })
}

///|
fn parse_example_sample_app_workspace(
  raw : String,
) -> Result[ExampleSampleAppWorkspace, String] {
  let parts : Array[String] = []
  for part in raw.split("\t") {
    parts.push(part.to_string())
  }
  if parts.length() == 0 {
    return Err("empty sample app result")
  }
  if parts[0] != "ok" {
    let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
    let detail = if parts.length() >= 3 { parts[2] } else { raw }
    return Err(stage + ": " + detail)
  }
  if parts.length() < 4 {
    return Err("invalid sample app workspace format: " + raw)
  }
  Ok({ temp_dir: parts[1], main_wac_path: parts[2], output_path: parts[3] })
}

///|
fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let left_array = left.to_array()
  let right_array = right.to_array()
  for i in 0..<left_array.length() {
    if left_array[i] != right_array[i] {
      return false
    }
  }
  true
}

///|
async test "build command composes local fixture deps and keeps implicit output equivalent" {
  let raw = js_prepare_build_bundle_fixture_workspace()
  let parsed = match parse_build_bundle_fixture_workspace(raw) {
    Ok(value) => value
    Err(msg) => fail("bundle fixture setup failed: " + msg)
  }
  run_build([
    "wite",
    "build",
    parsed.main_wac_path,
    "--no-config",
    "-o",
    parsed.explicit_path,
  ])
  let original_cwd = js_get_process_cwd()
  let cd_error = js_set_process_cwd(parsed.temp_dir)
  if not(cd_error.is_empty()) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to chdir to fixture workspace: " + cd_error)
  }
  run_build(["wite", "build", "--no-config"])
  let restore_error = js_set_process_cwd(original_cwd)
  if not(restore_error.is_empty()) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to restore cwd after implicit build: " + restore_error)
  }
  if not(parsed.composed_path.has_suffix("/composed.wasm")) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("implicit build output path should end with composed.wasm")
  }
  if not(parsed.explicit_path.has_suffix("/explicit.wasm")) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("explicit build output path should end with explicit.wasm")
  }
  let composed = @fs.read_file_to_bytes(parsed.composed_path) catch {
    e => {
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to read composed output: " + e.to_string())
      b""
    }
  }
  let explicit = @fs.read_file_to_bytes(parsed.explicit_path) catch {
    e => {
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to read explicit output: " + e.to_string())
      b""
    }
  }
  if not(bytes_equal(composed, explicit)) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("implicit and explicit build outputs diverged")
  }
  guard @wite.profile_component(composed) is Ok(profile) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("composed output is not parseable component wasm")
  }
  if profile.export_count == 0U {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("composed component has no exports")
  }
  guard @wite.analyze_component_root_policy(composed) is Ok(policy) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to inspect composed component root policy")
  }
  let mut has_greet_export = false
  for export_name in policy.component_exports {
    if export_name == "greet" || export_name.contains("greet") {
      has_greet_export = true
      break
    }
  }
  if not(has_greet_export) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("composed component does not expose expected greet export")
  }
  js_remove_dir_recursive(parsed.temp_dir)
}

///|
async test "new --moonbit workspace can bundle sample app fixture" {
  let raw = js_prepare_example_sample_app_workspace()
  let parsed = match parse_example_sample_app_workspace(raw) {
    Ok(value) => value
    Err(msg) => fail("sample app setup failed: " + msg)
  }
  let sample_main_wac = @fs.read_file_to_string(parsed.main_wac_path) catch {
    e => {
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to read sample main.wac: " + e.to_string())
      ""
    }
  }
  let original_cwd = js_get_process_cwd()
  let cd_error = js_set_process_cwd(parsed.temp_dir)
  if not(cd_error.is_empty()) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to chdir to sample app workspace: " + cd_error)
  }
  run_new_command(["wite", "new", "--moonbit", "--force"])
  @fs.write_string_to_file(parsed.main_wac_path, sample_main_wac) catch {
    e => {
      let _ = js_set_process_cwd(original_cwd)
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to restore sample main.wac after wite new: " + e.to_string())
    }
  }
  run_build([
    "wite", "build", "main.wac", "--no-config", "-o", "sample.composed.wasm",
  ])
  let restore_error = js_set_process_cwd(original_cwd)
  if not(restore_error.is_empty()) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to restore cwd after sample app build: " + restore_error)
  }
  let output = @fs.read_file_to_bytes(parsed.output_path) catch {
    e => {
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to read sample app output: " + e.to_string())
      b""
    }
  }
  guard @wite.profile_component(output) is Ok(profile) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("sample app output is not parseable component wasm")
  }
  if profile.export_count == 0U {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("sample app component has no exports")
  }
  guard @wite.analyze_component_root_policy(output) is Ok(policy) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("failed to inspect sample app root policy")
  }
  let mut has_hello_export = false
  for export_name in policy.component_exports {
    if export_name == "hello" || export_name.contains("hello") {
      has_hello_export = true
      break
    }
  }
  if not(has_hello_export) {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("sample app output does not expose expected hello export")
  }
  js_remove_dir_recursive(parsed.temp_dir)
}

///|
test "build fixture fails when dependency wasm is missing" {
  let raw = js_prepare_build_bundle_fixture_workspace()
  let parsed = match parse_build_bundle_fixture_workspace(raw) {
    Ok(value) => value
    Err(msg) => fail("bundle fixture setup failed: " + msg)
  }
  let missing_dep_path = parsed.temp_dir + "/deps/example/greeter.wasm"
  js_remove_file(missing_dep_path)
  guard @wite_bundle.compose_wac_file(parsed.main_wac_path) is Err(msg) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("expected compose failure for missing dependency wasm")
  }
  js_remove_dir_recursive(parsed.temp_dir)
  assert_true(
    msg.contains("greeter") || msg.contains("deps") || msg.contains("read"),
  )
}

///|
test "build fixture fails when main wac source is invalid" {
  let raw = js_prepare_build_bundle_fixture_workspace()
  let parsed = match parse_build_bundle_fixture_workspace(raw) {
    Ok(value) => value
    Err(msg) => fail("bundle fixture setup failed: " + msg)
  }
  @fs.write_string_to_file(
    parsed.main_wac_path,
    "package example:composition;\nlet broken = new example:hello {\n",
  ) catch {
    e => {
      js_remove_dir_recursive(parsed.temp_dir)
      fail("failed to write invalid main.wac fixture: " + e.to_string())
    }
  }
  guard @wite_bundle.compose_wac_file(parsed.main_wac_path) is Err(msg) else {
    js_remove_dir_recursive(parsed.temp_dir)
    fail("expected compose failure for invalid main.wac")
  }
  js_remove_dir_recursive(parsed.temp_dir)
  assert_true(not(msg.is_empty()))
}

///|
test "normalize opt level token accepts short forms" {
  assert_eq(normalize_opt_level_token("O2"), "-O2")
  assert_eq(normalize_opt_level_token("Oz"), "-Oz")
  assert_eq(normalize_opt_level_token("-O3"), "-O3")
  assert_eq(normalize_opt_level_token("-Oz"), "-Oz")
}

///|
test "parse wite config text supports jsonc style sections" {
  let config_text =
    #|{
    #|  // defaults
    #|  "build": { "flags": ["-Oz", "--strip-debug"] },
    #|  "analyze": ["--view=deep", "--limit=5"],
    #|  "profile": { "flags": ["--view=runtime", "--iterations=120"] },
    #|}
  guard @wite_config.parse_wite_config_text(config_text) is Ok(config) else {
    fail("expected valid config")
  }
  assert_eq(config.build_flags, ["-Oz", "--strip-debug"])
  assert_eq(config.analyze_flags, ["--view=deep", "--limit=5"])
  assert_eq(config.profile_flags, ["--view=runtime", "--iterations=120"])
  assert_true(config.build_kind is @wite_config.BinaryKind::Auto)
  assert_true(config.analyze_kind is @wite_config.BinaryKind::Auto)
  assert_true(config.profile_kind is @wite_config.BinaryKind::Auto)
}

///|
test "parse wite config text rejects invalid command section type" {
  let config_text =
    #|{
    #|  "build": true
    #|}
  assert_true(@wite_config.parse_wite_config_text(config_text) is Err(_))
}

///|
test "parse wite config text supports command kind override" {
  let config_text =
    #|{
    #|  "build": { "kind": "component", "flags": ["-Oz"] },
    #|  "analyze": { "kind": "core" },
    #|  "profile": { "kind": "component", "flags": [] }
    #|}
  guard @wite_config.parse_wite_config_text(config_text) is Ok(config) else {
    fail("expected valid config with kind")
  }
  assert_true(config.build_kind is @wite_config.BinaryKind::Component)
  assert_true(config.analyze_kind is @wite_config.BinaryKind::Core)
  assert_true(config.profile_kind is @wite_config.BinaryKind::Component)
}

///|
test "parse wite config text rejects unknown command kind" {
  let config_text =
    #|{
    #|  "build": { "kind": "unknown" }
    #|}
  assert_true(@wite_config.parse_wite_config_text(config_text) is Err(_))
}

///|
test "parse wite config text allows dependency section for add command" {
  let config_text =
    #|{
    #|  "build": ["-Oz"],
    #|  "deps": {
    #|    "wasi/http": "https://wa.dev/wasi:http@0.2.0"
    #|  }
    #|}
  guard @wite_config.parse_wite_config_text(config_text) is Ok(config) else {
    fail("expected valid config with deps")
  }
  assert_eq(config.build_flags, ["-Oz"])
  assert_eq(config.analyze_flags, [])
  assert_eq(config.profile_flags, [])
}

///|
test "parse config selection strips config flags and preserves command flags" {
  let parsed = @wite_config.parse_config_selection_flags([
    "--config=./custom.jsonc", "-Oz", "--no-config", "--closed-world",
  ])
  assert_eq(parsed.config_path, "./custom.jsonc")
  assert_true(parsed.explicit_config_path)
  assert_true(not(parsed.use_config))
  assert_eq(parsed.remaining_flags, ["-Oz", "--closed-world"])
}

///|
test "parse config selection uses default path when unspecified" {
  let parsed = @wite_config.parse_config_selection_flags(["--view=summary"])
  assert_eq(parsed.config_path, "wite.config.jsonc")
  assert_true(not(parsed.explicit_config_path))
  assert_true(parsed.use_config)
  assert_eq(parsed.remaining_flags, ["--view=summary"])
}

///|
test "merge command flags applies config defaults before cli flags" {
  let merged = @wite_config.merge_command_flags(["--view=deep", "--limit=5"], [
    "--view=summary", "--limit=20",
  ])
  assert_eq(merged, ["--view=deep", "--limit=5", "--view=summary", "--limit=20"])
}

///|
test "should auto sync deps requires config enabled and existing" {
  assert_true(@wite_config.should_auto_sync_deps(false, false) == false)
  assert_true(@wite_config.should_auto_sync_deps(false, true) == false)
  assert_true(@wite_config.should_auto_sync_deps(true, false) == false)
  assert_true(@wite_config.should_auto_sync_deps(true, true))
}

///|
test "build auto sync deps command args pins config and fail-fast" {
  assert_eq(
    @wite_config.build_auto_sync_deps_command_args("./wite.config.jsonc"),
    ["wite", "deps", "sync", "--config=./wite.config.jsonc", "--fail-fast"],
  )
}

///|
test "parse diff view supports canonical names" {
  assert_true(parse_diff_view("function") is Some(DiffView::Function))
  assert_true(parse_diff_view("section") is Some(DiffView::Section))
  assert_true(parse_diff_view("block") is Some(DiffView::Block))
  assert_true(parse_diff_view("unknown") is None)
}

///|
test "parse diff baseline supports wasm-opt" {
  assert_true(parse_diff_baseline("wasm-opt") is Some(DiffBaseline::WasmOpt))
  assert_true(parse_diff_baseline("unknown") is None)
}
