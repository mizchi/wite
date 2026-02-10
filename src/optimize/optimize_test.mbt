///|
fn read_fixture(path : String) -> Bytes? {
  try @fs.read_file_to_bytes(path) catch {
    _ => None
  } noraise {
    bytes => Some(bytes)
  }
}

///|
fn optimize_with_kind_or_none(
  bytes : Bytes,
  kind : OptimizeKind,
  config : @wite_types.OptimizeConfig,
) -> @wite_types.OptimizeResult? {
  match optimize_with_kind(bytes, kind, config) {
    Ok(result) => Some(result)
    Err(_) => None
  }
}

///|
test "parse optimize kind supports auto core component" {
  assert_true(parse_optimize_kind("auto") is Some(_))
  assert_true(parse_optimize_kind("core") is Some(_))
  assert_true(parse_optimize_kind("component") is Some(_))
  assert_true(parse_optimize_kind("unknown") is None)
}

///|
test "optimize with kind supports core fixture on auto and core" {
  guard read_fixture("bench/corpus/core/binaryen/br_to_exit.wasm")
    is Some(bytes) else {
    assert_true(false)
    return
  }
  let config = @wite_types.OptimizeConfig::o1()
  guard optimize_with_kind_or_none(bytes, optimize_kind_auto(), config)
    is Some(auto_result) else {
    assert_true(false)
    return
  }
  assert_true(auto_result.after_size <= auto_result.before_size)
  guard optimize_with_kind_or_none(bytes, optimize_kind_core(), config)
    is Some(core_result) else {
    assert_true(false)
    return
  }
  assert_true(core_result.after_size <= core_result.before_size)
}

///|
test "optimize with kind reaches zlib fixture on auto and core" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    assert_true(false)
    return
  }
  let config = @wite_types.OptimizeConfig::o1()
  guard optimize_with_kind_or_none(bytes, optimize_kind_auto(), config)
    is Some(auto_result) else {
    assert_true(false)
    return
  }
  assert_true(auto_result.after_size < auto_result.before_size)
  assert_true(auto_result.removed_sections.length() > 0)
  guard optimize_with_kind_or_none(bytes, optimize_kind_core(), config)
    is Some(core_result) else {
    assert_true(false)
    return
  }
  assert_true(core_result.after_size < core_result.before_size)
  assert_true(bytes_equal(auto_result.bytes, core_result.bytes))
}
