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
test "derive build output path from input extension" {
  assert_eq(derive_build_output_path("foo.wac"), "foo.wasm")
  assert_eq(derive_build_output_path("foo.wasm"), "foo.min.wasm")
  assert_eq(derive_build_output_path("foo.bar"), "foo.bar.wasm")
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
  guard parse_wite_config_text(config_text) is Ok(config) else {
    fail("expected valid config")
  }
  assert_eq(config.build_flags, ["-Oz", "--strip-debug"])
  assert_eq(config.analyze_flags, ["--view=deep", "--limit=5"])
  assert_eq(config.profile_flags, ["--view=runtime", "--iterations=120"])
}

///|
test "parse wite config text rejects invalid command section type" {
  let config_text =
    #|{
    #|  "build": true
    #|}
  assert_true(parse_wite_config_text(config_text) is Err(_))
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
  guard parse_wite_config_text(config_text) is Ok(config) else {
    fail("expected valid config with deps")
  }
  assert_eq(config.build_flags, ["-Oz"])
  assert_eq(config.analyze_flags, [])
  assert_eq(config.profile_flags, [])
}

///|
test "parse config selection strips config flags and preserves command flags" {
  let parsed = parse_config_selection_flags([
    "--config=./custom.jsonc", "-Oz", "--no-config", "--closed-world",
  ])
  assert_eq(parsed.config_path, "./custom.jsonc")
  assert_true(parsed.explicit_config_path)
  assert_true(not(parsed.use_config))
  assert_eq(parsed.remaining_flags, ["-Oz", "--closed-world"])
}

///|
test "parse config selection uses default path when unspecified" {
  let parsed = parse_config_selection_flags(["--view=summary"])
  assert_eq(parsed.config_path, "wite.config.jsonc")
  assert_true(not(parsed.explicit_config_path))
  assert_true(parsed.use_config)
  assert_eq(parsed.remaining_flags, ["--view=summary"])
}

///|
test "merge command flags applies config defaults before cli flags" {
  let merged = merge_command_flags(["--view=deep", "--limit=5"], [
    "--view=summary", "--limit=20",
  ])
  assert_eq(merged, ["--view=deep", "--limit=5", "--view=summary", "--limit=20"])
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

///|
test "parse wasm dependency spec supports slash and colon forms" {
  guard parse_wasm_dependency_spec("mizchi/markdown@0.1.0") is Some(spec1) else {
    fail("expected valid slash-form dependency spec")
  }
  assert_eq(spec1.ns, "mizchi")
  assert_eq(spec1.name, "markdown")
  assert_eq(spec1.version, "0.1.0")
  guard parse_wasm_dependency_spec("wasi:http") is Some(spec2) else {
    fail("expected valid colon-form dependency spec")
  }
  assert_eq(spec2.ns, "wasi")
  assert_eq(spec2.name, "http")
  assert_eq(spec2.version, "latest")
  assert_true(parse_wasm_dependency_spec("wkg:mizchi/markdown") is None)
}

///|
test "parse dependency protocol supports wkg warg and oci" {
  assert_true(parse_dependency_protocol("wkg") is Some(DependencyProtocol::Wkg))
  assert_true(parse_dependency_protocol("warg") is Some(DependencyProtocol::Warg))
  assert_true(parse_dependency_protocol("oci") is Some(DependencyProtocol::Oci))
  assert_true(parse_dependency_protocol("unknown") is None)
}

///|
test "parse dependency input supports jsr-like wkg prefix" {
  guard
    parse_dependency_input("wkg:mizchi/markdown@0.1.0", DependencyProtocol::Wkg)
    is Some(parsed)
  else {
    fail("expected valid prefixed dep input")
  }
  assert_true(parsed.protocol is DependencyProtocol::Wkg)
  assert_eq(parsed.spec.ns, "mizchi")
  assert_eq(parsed.spec.name, "markdown")
  assert_eq(parsed.spec.version, "0.1.0")
  assert_true(parsed.host is None)
}

///|
test "parse https dependency url supports wa.dev canonical path" {
  guard
    parse_https_dependency_url("https://wa.dev/mizchi:tmgrammar@0.1.1")
    is Some((host, spec))
  else {
    fail("expected valid https dep url")
  }
  assert_eq(host, "wa.dev")
  assert_eq(spec.ns, "mizchi")
  assert_eq(spec.name, "tmgrammar")
  assert_eq(spec.version, "0.1.1")
}

///|
test "upsert dependency config keeps existing sections and writes deps url" {
  let base = Json::object(
    Map::of([("build", Json::array([Json::string("-Oz")]))]),
  )
  guard upsert_wasm_dependency_config_json(
      base,
      "mizchi/markdown",
      "https://wa.dev/mizchi:markdown",
    )
    is Ok(updated) else {
    fail("expected config update success")
  }
  guard updated is Json::Object(updated_obj) else {
    fail("expected object config")
  }
  guard updated_obj.get("build") is Some(build_section) else {
    fail("missing build section")
  }
  assert_eq(build_section, Json::array([Json::string("-Oz")]))
  guard updated_obj.get("deps") is Some(Json::Object(deps)) else {
    fail("missing deps section")
  }
  assert_eq(
    deps.get("mizchi/markdown"),
    Some(Json::string("https://wa.dev/mizchi:markdown")),
  )
}

///|
test "upsert dependency config overwrites existing deps entry" {
  let base = Json::object(
    Map::of([(
      "deps",
      Json::object(
        Map::of([("http", Json::string("https://wa.dev/wasi:http@0.2.0"))]),
      ),
    )]),
  )
  guard upsert_wasm_dependency_config_json(
      base,
      "http",
      "https://wa.dev/wasi:http@0.2.3",
    )
    is Ok(updated) else {
    fail("expected config update success")
  }
  guard updated is Json::Object(updated_obj) else {
    fail("expected object config")
  }
  guard updated_obj.get("deps") is Some(Json::Object(deps)) else {
    fail("missing deps section")
  }
  assert_eq(deps.get("http"), Some(Json::string("https://wa.dev/wasi:http@0.2.3")))
}

///|
test "parse add command options resolves wkg prefix to https url" {
  guard parse_add_command_options(["wite", "add", "wkg:mizchi/markdown"])
    is Ok(opts) else {
    fail("expected valid add options")
  }
  assert_eq(opts.config_path, "wite.config.jsonc")
  assert_eq(opts.dependency_name, "mizchi/markdown")
  assert_true(opts.parsed.protocol is DependencyProtocol::Wkg)
  assert_eq(opts.resolved_url, "https://wa.dev/mizchi:markdown")
}

///|
test "parse add command options accepts https spec directly" {
  guard parse_add_command_options([
      "wite", "add", "https://wa.dev/mizchi:tmgrammar@0.1.1", "--name=tmg",
      "--config=./custom.config.jsonc",
    ])
    is Ok(opts) else {
    fail("expected valid add options")
  }
  assert_eq(opts.config_path, "./custom.config.jsonc")
  assert_eq(opts.dependency_name, "tmg")
  assert_eq(opts.resolved_url, "https://wa.dev/mizchi:tmgrammar@0.1.1")
}

///|
test "parse add command options supports registry override" {
  guard parse_add_command_options([
      "wite", "add", "wkg:mizchi/markdown@0.1.0", "--registry=wasi.dev",
      "--name=md",
    ])
    is Ok(opts) else {
    fail("expected valid add options")
  }
  assert_eq(opts.dependency_name, "md")
  assert_eq(opts.resolved_url, "https://wasi.dev/mizchi:markdown@0.1.0")
}

///|
test "parse add command options supports verify flag" {
  guard parse_add_command_options([
      "wite", "add", "wasi:http@0.2.10", "--verify",
    ])
    is Ok(opts) else {
    fail("expected valid add options with verify")
  }
  assert_true(opts.verify)
}

///|
fn parse_registry_config(text : String) -> @oci_types.RegistryConfig? {
  let json = @json5.parse(text) catch { _ => return None }
  @oci_types.RegistryConfig::from_json(json)
}

///|
test "resolve verify backend prefers oci for wkg" {
  let config_text =
    #|{
    #|  "preferredProtocol": "oci",
    #|  "oci": {
    #|    "registry": "ghcr.io",
    #|    "namespacePrefix": "webassembly/"
    #|  },
    #|  "warg": {
    #|    "url": "https://warg.wa.dev"
    #|  }
    #|}
  guard parse_registry_config(config_text) is Some(config) else {
    fail("expected valid registry config")
  }
  guard resolve_verify_backend(DependencyProtocol::Wkg, config)
    is Ok(VerifyBackend::Oci(oci)) else {
    fail("expected oci backend for wkg")
  }
  assert_eq(oci.registry, "ghcr.io")
}

///|
test "resolve verify backend falls back to warg for wkg" {
  let config_text =
    #|{
    #|  "preferredProtocol": "warg",
    #|  "warg": {
    #|    "url": "https://warg.wa.dev"
    #|  }
    #|}
  guard parse_registry_config(config_text) is Some(config) else {
    fail("expected valid registry config")
  }
  guard resolve_verify_backend(DependencyProtocol::Wkg, config)
    is Ok(VerifyBackend::Warg(warg)) else {
    fail("expected warg backend for wkg")
  }
  assert_eq(warg.url, "https://warg.wa.dev")
}

///|
test "resolve verify backend requires explicit oci availability" {
  let config_text =
    #|{
    #|  "preferredProtocol": "warg",
    #|  "warg": {
    #|    "url": "https://warg.wa.dev"
    #|  }
    #|}
  guard parse_registry_config(config_text) is Some(config) else {
    fail("expected valid registry config")
  }
  guard resolve_verify_backend(DependencyProtocol::Oci, config) is Err(msg) else {
    fail("expected backend resolution error")
  }
  assert_true(msg.contains("oci"))
}

///|
test "build verify package spec omits latest version suffix" {
  let latest_spec : WasmDependencySpec = {
    ns: "wasi",
    name: "http",
    version: "latest",
  }
  let pinned_spec : WasmDependencySpec = {
    ns: "wasi",
    name: "http",
    version: "0.2.10",
  }
  assert_eq(build_verify_package_spec(latest_spec), "wasi:http")
  assert_eq(build_verify_package_spec(pinned_spec), "wasi:http@0.2.10")
}

///|
test "parse wkg verify cli result handles ok and error records" {
  guard parse_wkg_verify_cli_result("ok\t0\t") is Ok(_) else {
    fail("expected ok cli result")
  }
  guard parse_wkg_verify_cli_result("error\texit:1\tnot found") is Err(msg) else {
    fail("expected error cli result")
  }
  assert_true(msg.contains("exit:1"))
  assert_true(msg.contains("not found"))
}
