///|
test "parse optimize kind supports auto core component" {
  assert_true(parse_optimize_kind("auto") is Some(_))
  assert_true(parse_optimize_kind("core") is Some(_))
  assert_true(parse_optimize_kind("component") is Some(_))
  assert_true(parse_optimize_kind("unknown") is None)
}

///|
test "optimize with kind supports core fixture on auto and core" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/br_to_exit.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let config = @wite_types.OptimizeConfig::o1()
  guard optimize_with_kind(bytes, optimize_kind_auto(), config)
    is Ok(auto_result) else {
    assert_true(false)
    return
  }
  assert_true(auto_result.after_size <= auto_result.before_size)
  guard optimize_with_kind(bytes, optimize_kind_core(), config)
    is Ok(core_result) else {
    assert_true(false)
    return
  }
  assert_true(core_result.after_size <= core_result.before_size)
}
