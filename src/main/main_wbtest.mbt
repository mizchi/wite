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
