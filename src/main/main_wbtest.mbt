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
