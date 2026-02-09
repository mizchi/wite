///|
test "build wac dep target path follows deps layout" {
  assert_eq(
    build_wac_dep_target_path("examples/compose", "example", "hello"),
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
  guard collect_wac_new_package_names(source) is Ok(packages) else {
    fail("expected valid wac package extraction")
  }
  assert_eq(packages, ["example:hello", "example:greeter"])
}

///|
test "parse wac package name accepts namespace and name" {
  guard parse_wac_package_name("example:hello") is Some((ns, name)) else {
    fail("expected valid package name")
  }
  assert_eq(ns, "example")
  assert_eq(name, "hello")
  assert_true(parse_wac_package_name("invalid") is None)
}

///|
fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
test "compose wac source matches compose wac file output" {
  let fixture_dir = "bench/corpus/component-dce/wite-build-fixture"
  let main_wac_path = fixture_dir + "/main.wac"
  assert_true(@fs.path_exists(main_wac_path))
  let source = @fs.read_file_to_string(main_wac_path)
  guard compose_wac_file(main_wac_path) is Ok(from_file) else {
    fail("expected compose_wac_file to succeed")
  }
  guard compose_wac_source(source, fixture_dir) is Ok(from_source) else {
    fail("expected compose_wac_source to succeed")
  }
  assert_true(bytes_equal(from_file, from_source))
}

///|
test "compose wac source returns parse error for invalid source" {
  let broken_source =
    #|package example:composition;
    #|let broken = new example:hello {
    #|
  guard compose_wac_source(broken_source, ".") is Err(msg) else {
    fail("expected compose_wac_source parse failure")
  }
  assert_true(not(msg.is_empty()))
}
