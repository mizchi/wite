///|
test "normalize_dependency_host removes https prefix" {
  inspect(normalize_dependency_host("https://wa.dev"), content="wa.dev")
}

///|
test "normalize_dependency_host removes http prefix" {
  inspect(normalize_dependency_host("http://wa.dev"), content="wa.dev")
}

///|
test "normalize_dependency_host removes trailing slash" {
  inspect(normalize_dependency_host("wa.dev/"), content="wa.dev")
}

///|
test "normalize_dependency_host combined" {
  inspect(normalize_dependency_host("https://wa.dev/"), content="wa.dev")
}

///|
test "normalize_dependency_host plain host" {
  inspect(normalize_dependency_host("wa.dev"), content="wa.dev")
}

///|
test "normalize_dependency_host trims whitespace" {
  inspect(normalize_dependency_host("  wa.dev  "), content="wa.dev")
}

///|
test "parse_versioned_segment with version" {
  let (base, version) = parse_versioned_segment("wasi:http@0.2.0")
  inspect(base, content="wasi:http")
  inspect(version, content="0.2.0")
}

///|
test "parse_versioned_segment without version" {
  let (base, version) = parse_versioned_segment("wasi:http")
  inspect(base, content="wasi:http")
  inspect(version, content="latest")
}

///|
test "parse_versioned_segment at position zero" {
  let (base, version) = parse_versioned_segment("@0.2.0")
  inspect(base, content="@0.2.0")
  inspect(version, content="latest")
}

///|
test "parse_versioned_segment at end" {
  let (base, version) = parse_versioned_segment("pkg@")
  inspect(base, content="pkg@")
  inspect(version, content="latest")
}

///|
test "build_dep_url latest version omitted" {
  let spec : WasmDependencySpec = {
    ns: "wasi",
    name: "http",
    version: "latest",
  }
  inspect(build_dep_url("wa.dev", spec), content="https://wa.dev/wasi:http")
}

///|
test "build_dep_url pinned version" {
  let spec : WasmDependencySpec = { ns: "wasi", name: "http", version: "0.2.0" }
  inspect(
    build_dep_url("wa.dev", spec),
    content="https://wa.dev/wasi:http@0.2.0",
  )
}

///|
test "normalize_dep_sync_output_dir empty" {
  inspect(normalize_dep_sync_output_dir(""), content="deps")
}

///|
test "normalize_dep_sync_output_dir whitespace only" {
  inspect(normalize_dep_sync_output_dir("   "), content="deps")
}

///|
test "normalize_dep_sync_output_dir trailing slash" {
  inspect(normalize_dep_sync_output_dir("my-deps/"), content="my-deps")
}

///|
test "normalize_dep_sync_output_dir normal" {
  inspect(normalize_dep_sync_output_dir("deps"), content="deps")
}

///|
test "build_verify_package_spec latest" {
  let spec : WasmDependencySpec = {
    ns: "wasi",
    name: "http",
    version: "latest",
  }
  inspect(build_verify_package_spec(spec), content="wasi:http")
}

///|
test "build_verify_package_spec pinned" {
  let spec : WasmDependencySpec = { ns: "wasi", name: "http", version: "0.2.0" }
  inspect(build_verify_package_spec(spec), content="wasi:http@0.2.0")
}

///|
test "parse_wkg_verify_cli_result ok" {
  let result = parse_wkg_verify_cli_result("ok\t0\t")
  assert_true(result is Ok(_))
}

///|
test "parse_wkg_verify_cli_result error" {
  let result = parse_wkg_verify_cli_result("error\tspawn\twkg not found")
  match result {
    Err(msg) => inspect(msg, content="spawn: wkg not found")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_wkg_verify_cli_result minimal error" {
  let result = parse_wkg_verify_cli_result("error")
  match result {
    Err(msg) => inspect(msg, content="unknown: error")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_wkg_sync_cli_result ok" {
  let result = parse_wkg_sync_cli_result("ok\tdeps/wasi_http\t")
  inspect(result, content="Ok(\"deps/wasi_http\")")
}

///|
test "parse_wkg_sync_cli_result error" {
  let result = parse_wkg_sync_cli_result("error\texit:1\tpackage not found")
  match result {
    Err(msg) => inspect(msg, content="exit:1: package not found")
    Ok(_) => fail("expected error")
  }
}

///|
test "compare_dep_config_entry sort order" {
  let a : DepConfigEntry = {
    name: "alpha/pkg",
    url: "https://wa.dev/alpha:pkg",
  }
  let b : DepConfigEntry = { name: "beta/pkg", url: "https://wa.dev/beta:pkg" }
  let cmp_ab = compare_dep_config_entry(a, b)
  let cmp_ba = compare_dep_config_entry(b, a)
  let cmp_aa = compare_dep_config_entry(a, a)
  // a < b lexicographically, so cmp_ab and cmp_ba should have opposite signs
  assert_true(cmp_ab != 0)
  assert_true(cmp_ba != 0)
  assert_true(cmp_ab == -cmp_ba)
  assert_true(cmp_aa == 0)
}

///|
test "path_dirname with slash" {
  inspect(path_dirname("foo/bar/baz.txt"), content="foo/bar")
}

///|
test "path_dirname root level" {
  inspect(path_dirname("file.txt"), content=".")
}

///|
test "path_dirname single dir" {
  inspect(path_dirname("dir/file"), content="dir")
}

///|
test "validate_dep_sync_targets no collision" {
  let entries : Array[DepConfigEntry] = [
    { name: "wasi/http", url: "https://wa.dev/wasi:http" },
    { name: "wasi/cli", url: "https://wa.dev/wasi:cli" },
  ]
  let result = validate_dep_sync_targets(entries, "deps")
  assert_true(result is Ok(_))
}

///|
test "collect_dep_entries_from_config_json normal" {
  let json : Json = { "deps": { "wasi/http": "https://wa.dev/wasi:http" } }
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Ok(entries) => {
      inspect(entries.length(), content="1")
      inspect(entries[0].name, content="wasi/http")
      inspect(entries[0].url, content="https://wa.dev/wasi:http")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "collect_dep_entries_from_config_json empty deps" {
  let json : Json = { "deps": {} }
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Ok(entries) => inspect(entries.length(), content="0")
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "collect_dep_entries_from_config_json no deps key" {
  let json : Json = {}
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Ok(entries) => inspect(entries.length(), content="0")
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "collect_dep_entries_from_config_json invalid value" {
  let json : Json = { "deps": { "bad": 42 } }
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Err(msg) => inspect(msg, content="config deps entry must be string: bad")
    Ok(_) => fail("expected error")
  }
}

///|
test "collect_dep_entries_from_config_json non-object root" {
  let json : Json = "bad"
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Err(msg) => inspect(msg, content="config root must be object")
    Ok(_) => fail("expected error")
  }
}

///|
test "collect_dep_entries_from_config_json deps not object" {
  let json : Json = { "deps": "bad" }
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Err(msg) => inspect(msg, content="config deps must be object")
    Ok(_) => fail("expected error")
  }
}

///|
test "collect_dep_entries_from_config_json sorted" {
  let json : Json = {
    "deps": {
      "zeta/pkg": "https://wa.dev/zeta:pkg",
      "alpha/pkg": "https://wa.dev/alpha:pkg",
    },
  }
  let result = collect_dep_entries_from_config_json(json)
  match result {
    Ok(entries) => {
      inspect(entries.length(), content="2")
      // sorted by compare_dep_config_entry (String.compare order)
      let first = entries[0].name
      let second = entries[1].name
      assert_true(first != second)
      assert_true(
        (first == "alpha/pkg" && second == "zeta/pkg") ||
        (first == "zeta/pkg" && second == "alpha/pkg"),
      )
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}
