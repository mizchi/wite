///|
fn read_fixture_or_fail(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    e => {
      println("failed to read fixture: " + path + " (" + e.to_string() + ")")
      panic()
      b""
    }
  }
}

///|
fn must_profile_module_total(bytes : Bytes) -> UInt {
  match profile_module(bytes) {
    Ok(profile) => profile.total_bytes
    Err(err) => {
      println("profile_module failed: " + error_to_string(err))
      panic()
      0U
    }
  }
}

///|
fn must_profile_component_total(bytes : Bytes) -> UInt {
  match profile_component(bytes) {
    Ok(profile) => profile.total_bytes
    Err(err) => {
      println("profile_component failed: " + err)
      panic()
      0U
    }
  }
}

///|
fn must_optimize_after_size(bytes : Bytes, config : OptimizeConfig) -> UInt {
  match optimize_for_size(bytes, config~) {
    Ok(result) => result.after_size
    Err(err) => {
      println("optimize_for_size failed: " + error_to_string(err))
      panic()
      0U
    }
  }
}

///|
fn must_analyze_wasm_breakdown_score(bytes : Bytes, top_limit : UInt) -> UInt {
  match analyze_wasm_breakdown(bytes, top_limit~) {
    Ok(report) => report.instruction_count + report.dead_body_bytes
    Err(err) => {
      println("analyze_wasm_breakdown failed: " + error_to_string(err))
      panic()
      0U
    }
  }
}

///|
test "bench: core profile binaryen zlib" (b : @bench.T) {
  let bytes = read_fixture_or_fail("bench/corpus/core/binaryen/zlib.wasm")
  b.bench(fn() { b.keep(must_profile_module_total(bytes)) })
}

///|
test "bench: core optimize -O2 binaryen zlib" (b : @bench.T) {
  let bytes = read_fixture_or_fail("bench/corpus/core/binaryen/zlib.wasm")
  let config = OptimizeConfig::o2()
  b.bench(fn() { b.keep(must_optimize_after_size(bytes, config)) })
}

///|
test "bench: core optimize -O1 binaryen gc_target_feature" (b : @bench.T) {
  let bytes = read_fixture_or_fail(
    "bench/corpus/core/binaryen/gc_target_feature.wasm",
  )
  let config = OptimizeConfig::o1()
  b.bench(fn() { b.keep(must_optimize_after_size(bytes, config)) })
}

///|
test "bench: component profile wac dummy_wasi_http_0.2.3" (b : @bench.T) {
  let bytes = read_fixture_or_fail(
    "bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm",
  )
  b.bench(fn() { b.keep(must_profile_component_total(bytes)) })
}

///|
test "bench: component top functions wac dummy_wasi_http_0.2.3" (b : @bench.T) {
  let bytes = read_fixture_or_fail(
    "bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm",
  )
  b.bench(fn() {
    match analyze_component_function_sizes(bytes) {
      Ok(reports) => b.keep(reports.length())
      Err(err) => {
        println("analyze_component_function_sizes failed: " + err)
        panic()
      }
    }
  })
}

///|
test "bench: core deep analyze binaryen zlib (top20)" (b : @bench.T) {
  let bytes = read_fixture_or_fail("bench/corpus/core/binaryen/zlib.wasm")
  b.bench(fn() { b.keep(must_analyze_wasm_breakdown_score(bytes, 20U)) })
}
