///|
test "binary_kind_name returns correct strings" {
  let auto = @config.parse_binary_kind("auto").unwrap()
  let core = @config.parse_binary_kind("core").unwrap()
  let component = @config.parse_binary_kind("component").unwrap()
  inspect(@config.binary_kind_name(auto), content="auto")
  inspect(@config.binary_kind_name(core), content="core")
  inspect(@config.binary_kind_name(component), content="component")
}

///|
test "parse_binary_kind roundtrip" {
  let kinds : Array[String] = ["auto", "core", "component"]
  for kind_name in kinds {
    let parsed = @config.parse_binary_kind(kind_name)
    assert_true(parsed is Some(_))
    let name = @config.binary_kind_name(parsed.unwrap())
    assert_eq(name, kind_name)
  }
}

///|
test "parse_binary_kind case insensitive" {
  assert_true(@config.parse_binary_kind("AUTO") is Some(_))
  assert_true(@config.parse_binary_kind("Core") is Some(_))
  assert_true(@config.parse_binary_kind("COMPONENT") is Some(_))
}

///|
test "parse_binary_kind unknown returns None" {
  assert_true(@config.parse_binary_kind("unknown") is None)
  assert_true(@config.parse_binary_kind("") is None)
}

///|
test "empty_wite_config_file defaults" {
  let config = @config.empty_wite_config_file()
  inspect(config.build_flags.length(), content="0")
  inspect(config.analyze_flags.length(), content="0")
  inspect(config.profile_flags.length(), content="0")
  inspect(@config.binary_kind_name(config.build_kind), content="auto")
  inspect(@config.binary_kind_name(config.analyze_kind), content="auto")
  inspect(@config.binary_kind_name(config.profile_kind), content="auto")
  assert_true(config.input is @config.ConfigInput::None)
  inspect(config.output.dir, content="dist")
}

///|
test "parse_json_string_array normal" {
  let json : Json = ["--flag1", "--flag2"]
  let result = @config.parse_json_string_array(json, "test")
  inspect(result, content="Ok([\"--flag1\", \"--flag2\"])")
}

///|
test "parse_json_string_array empty" {
  let json : Json = Json::array([])
  let result = @config.parse_json_string_array(json, "test")
  inspect(result, content="Ok([])")
}

///|
test "parse_json_string_array non-string element" {
  let json : Json = ["ok", 42]
  let result = @config.parse_json_string_array(json, "flags")
  inspect(result, content="Err(\"config flags[1] must be string\")")
}

///|
test "parse_json_string_array non-array" {
  let json : Json = "not-array"
  let result = @config.parse_json_string_array(json, "flags")
  inspect(result, content="Err(\"config flags must be string array\")")
}

///|
test "parse_wite_config_section array form" {
  let json : Json = ["--opt-level=3"]
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok((flags, kind)) => {
      inspect(flags, content="[\"--opt-level=3\"]")
      inspect(@config.binary_kind_name(kind), content="auto")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_section object form with flags" {
  let json : Json = { "flags": ["--opt-level=3"] }
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok((flags, kind)) => {
      inspect(flags, content="[\"--opt-level=3\"]")
      inspect(@config.binary_kind_name(kind), content="auto")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_section object form with kind" {
  let json : Json = { "kind": "core", "flags": ["--flag"] }
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok((flags, kind)) => {
      inspect(flags, content="[\"--flag\"]")
      inspect(@config.binary_kind_name(kind), content="core")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_section object form empty" {
  let json : Json = {}
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok((flags, kind)) => {
      inspect(flags.length(), content="0")
      inspect(@config.binary_kind_name(kind), content="auto")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_section invalid kind" {
  let json : Json = { "kind": "invalid" }
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok(_) => fail("expected error")
    Err(msg) => inspect(msg, content="invalid config build.kind: invalid")
  }
}

///|
test "parse_wite_config_section kind not string" {
  let json : Json = { "kind": 42 }
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok(_) => fail("expected error")
    Err(msg) => inspect(msg, content="config build.kind must be string")
  }
}

///|
test "parse_wite_config_section non-object-non-array" {
  let json : Json = "invalid"
  let result = @config.parse_wite_config_section(json, "build")
  match result {
    Ok(_) => fail("expected error")
    Err(msg) => inspect(msg, content="config build must be array or object")
  }
}

///|
test "parse_wite_config_json empty object" {
  let json : Json = {}
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => {
      inspect(config.build_flags.length(), content="0")
      inspect(config.analyze_flags.length(), content="0")
      inspect(config.profile_flags.length(), content="0")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_json invalid root" {
  let json : Json = "not-object"
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(_) => fail("expected error")
    Err(msg) => inspect(msg, content="config root must be object")
  }
}

///|
test "parse_wite_config_json with all sections" {
  let json : Json = {
    "build": { "flags": ["--b"], "kind": "core" },
    "analyze": ["--a"],
    "profile": { "kind": "component" },
  }
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => {
      inspect(config.build_flags, content="[\"--b\"]")
      inspect(@config.binary_kind_name(config.build_kind), content="core")
      inspect(config.analyze_flags, content="[\"--a\"]")
      inspect(@config.binary_kind_name(config.analyze_kind), content="auto")
      inspect(config.profile_flags.length(), content="0")
      inspect(
        @config.binary_kind_name(config.profile_kind),
        content="component",
      )
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "merge_command_flags combines arrays" {
  let defaults : Array[String] = ["--opt-level=3"]
  let cli : Array[String] = ["--debug"]
  let merged = @config.merge_command_flags(defaults, cli)
  inspect(merged, content="[\"--opt-level=3\", \"--debug\"]")
}

///|
test "merge_command_flags does not mutate defaults" {
  let defaults : Array[String] = ["--a"]
  let cli : Array[String] = ["--b"]
  let _ = @config.merge_command_flags(defaults, cli)
  inspect(defaults.length(), content="1")
}

///|
test "should_auto_sync_deps" {
  inspect(@config.should_auto_sync_deps(true, true), content="true")
  inspect(@config.should_auto_sync_deps(true, false), content="false")
  inspect(@config.should_auto_sync_deps(false, true), content="false")
  inspect(@config.should_auto_sync_deps(false, false), content="false")
}

///|
test "build_auto_sync_deps_command_args" {
  let args = @config.build_auto_sync_deps_command_args("custom.jsonc")
  inspect(
    args,
    content="[\"wite\", \"deps\", \"sync\", \"--config=custom.jsonc\", \"--fail-fast\"]",
  )
}

///|
test "parse_config_selection_flags no flags" {
  let flags : Array[String] = []
  let result = @config.parse_config_selection_flags(flags)
  inspect(result.config_path, content="wite.config.jsonc")
  inspect(result.explicit_config_path, content="false")
  inspect(result.use_config, content="true")
  inspect(result.remaining_flags.length(), content="0")
}

///|
test "parse_config_selection_flags no-config" {
  let flags : Array[String] = ["--no-config"]
  let result = @config.parse_config_selection_flags(flags)
  inspect(result.use_config, content="false")
}

///|
test "parse_config_selection_flags remaining flags preserved" {
  let flags : Array[String] = ["--no-config", "--other", "value"]
  let result = @config.parse_config_selection_flags(flags)
  inspect(result.remaining_flags, content="[\"--other\", \"value\"]")
}

///|
test "parse_config_input string form" {
  let json : Json = "app.wasm"
  let result = @config.parse_config_input(json)
  match result {
    Ok(@config.ConfigInput::Single(s)) => inspect(s, content="app.wasm")
    _ => fail("expected Single")
  }
}

///|
test "parse_config_input object form" {
  let json : Json = { "app": "a.wasm" }
  let result = @config.parse_config_input(json)
  match result {
    Ok(@config.ConfigInput::Named(map)) => inspect(map["app"], content="a.wasm")
    _ => fail("expected Named")
  }
}

///|
test "parse_config_input type error" {
  let json : Json = 42
  let result = @config.parse_config_input(json)
  match result {
    Err(msg) => inspect(msg, content="config input must be string or object")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_config_output string form" {
  let json : Json = "dist"
  let result = @config.parse_config_output(json)
  match result {
    Ok(output) => inspect(output.dir, content="dist")
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_config_output object form" {
  let json : Json = { "dir": "out" }
  let result = @config.parse_config_output(json)
  match result {
    Ok(output) => inspect(output.dir, content="out")
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_config_output empty object defaults to dist" {
  let json : Json = {}
  let result = @config.parse_config_output(json)
  match result {
    Ok(output) => inspect(output.dir, content="dist")
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_json with input and output" {
  let json : Json = { "input": "app.wasm", "output": "out" }
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => {
      match config.input {
        @config.ConfigInput::Single(s) => inspect(s, content="app.wasm")
        _ => fail("expected Single input")
      }
      inspect(config.output.dir, content="out")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_json backward compat empty object" {
  let json : Json = {}
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => {
      assert_true(config.input is @config.ConfigInput::None)
      inspect(config.output.dir, content="dist")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "is_ts_config detects typescript config files" {
  assert_true(@config.is_ts_config("wite.config.ts"))
  assert_true(@config.is_ts_config("path/to/wite.config.ts"))
  assert_true(!@config.is_ts_config("wite.config.jsonc"))
  assert_true(!@config.is_ts_config("wite.config.json"))
  assert_true(!@config.is_ts_config("config.ts.bak"))
}

///|
test "config_input_entries None" {
  let entries = @config.config_input_entries(@config.ConfigInput::new_none())
  inspect(entries.length(), content="0")
}

///|
test "config_input_entries Single" {
  let entries = @config.config_input_entries(
    @config.ConfigInput::new_single("app.wasm"),
  )
  inspect(entries.length(), content="1")
  inspect(entries[0].0, content="default")
  inspect(entries[0].1, content="app.wasm")
}

///|
test "config_input_entries Named" {
  let map : Map[String, String] = { "app": "app.wac", "worker": "worker.wac" }
  let entries = @config.config_input_entries(
    @config.ConfigInput::new_named(map),
  )
  inspect(entries.length(), content="2")
}

///|
test "config_input_entries Named preserves key-value pairs" {
  let map : Map[String, String] = {
    "app": "app.wac",
    "worker": "worker.wac",
    "admin": "admin.wac",
  }
  let entries = @config.config_input_entries(
    @config.ConfigInput::new_named(map),
  )
  inspect(entries.length(), content="3")
  // Verify each entry has correct key-value pair
  let keys : Array[String] = []
  let vals : Array[String] = []
  for entry in entries {
    keys.push(entry.0)
    vals.push(entry.1)
  }
  assert_true(keys.contains("app"))
  assert_true(keys.contains("worker"))
  assert_true(keys.contains("admin"))
  assert_true(vals.contains("app.wac"))
  assert_true(vals.contains("worker.wac"))
  assert_true(vals.contains("admin.wac"))
}

///|
test "config_input_entries Named empty map" {
  let map : Map[String, String] = {}
  let entries = @config.config_input_entries(
    @config.ConfigInput::new_named(map),
  )
  inspect(entries.length(), content="0")
}

///|
test "config_input_entries Named single entry" {
  let map : Map[String, String] = { "only": "only.wasm" }
  let entries = @config.config_input_entries(
    @config.ConfigInput::new_named(map),
  )
  inspect(entries.length(), content="1")
  inspect(entries[0].0, content="only")
  inspect(entries[0].1, content="only.wasm")
}

///|
test "parse_config_input Named multi-entry roundtrip" {
  let json : Json = { "app": "app.wac", "worker": "worker.wac" }
  let result = @config.parse_config_input(json)
  match result {
    Ok(input) => {
      let entries = @config.config_input_entries(input)
      inspect(entries.length(), content="2")
    }
    Err(_) => fail("expected Ok")
  }
}

///|
test "parse_wite_config_json with named input and output" {
  let json : Json = {
    "input": { "app": "app.wac", "worker": "worker.wac" },
    "output": { "dir": "out" },
    "build": ["-Oz"],
  }
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => {
      let entries = @config.config_input_entries(config.input)
      inspect(entries.length(), content="2")
      inspect(config.output.dir, content="out")
      inspect(config.build_flags, content="[\"-Oz\"]")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_config_input Named rejects non-string values" {
  let json : Json = { "app": "app.wac", "worker": 42 }
  let result = @config.parse_config_input(json)
  match result {
    Err(msg) => inspect(msg, content="config input.worker must be string")
    Ok(_) => fail("expected error")
  }
}

///|
test "config_input_single_path Named returns first entry" {
  let map : Map[String, String] = { "app": "app.wac", "worker": "worker.wac" }
  let path = @config.config_input_single_path(
    @config.ConfigInput::new_named(map),
  )
  assert_true(path is Some(_))
}

///|
test "parse_server_config wagi executor" {
  let json : Json = { "executor": "wagi", "route": "/api/..." }
  let result = @config.parse_server_config(json)
  match result {
    Ok(config) => {
      assert_eq(config.executor, @config.ServerExecutor::Wagi)
      inspect(config.route, content="/api/...")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_config workerd executor" {
  let json : Json = { "executor": "workerd", "route": "/api/..." }
  let result = @config.parse_server_config(json)
  match result {
    Ok(config) => {
      assert_eq(config.executor, @config.ServerExecutor::Workerd)
      inspect(config.route, content="/api/...")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_config defaults" {
  let json : Json = {}
  let result = @config.parse_server_config(json)
  match result {
    Ok(config) => {
      assert_eq(config.executor, @config.ServerExecutor::Wagi)
      inspect(config.route, content="/...")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_config invalid executor" {
  let json : Json = { "executor": "unknown" }
  let result = @config.parse_server_config(json)
  match result {
    Err(msg) => inspect(msg, content="invalid server.executor: unknown")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_server_config non-object" {
  let json : Json = "invalid"
  let result = @config.parse_server_config(json)
  match result {
    Err(msg) => inspect(msg, content="server must be object")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_wite_config_json with server section" {
  let json : Json = { "server": { "executor": "wagi", "route": "/..." } }
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) =>
      match config.server {
        Some(server) => {
          assert_eq(server.executor, @config.ServerExecutor::Wagi)
          inspect(server.route, content="/...")
        }
        None => fail("expected server config")
      }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_wite_config_json without server section" {
  let json : Json = {}
  let result = @config.parse_wite_config_json(json)
  match result {
    Ok(config) => assert_true(config.server is None)
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings simple kv format" {
  let json : Json = { "kv_namespaces": ["MY_KV", "CACHE"] }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.kv_namespaces.length(), 2)
      assert_eq(bindings.kv_namespaces[0].binding, "MY_KV")
      assert_eq(bindings.kv_namespaces[0].id, "wite-dev-my_kv")
      assert_eq(bindings.kv_namespaces[1].binding, "CACHE")
      assert_eq(bindings.kv_namespaces[1].id, "wite-dev-cache")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings explicit kv format" {
  let json : Json = {
    "kv_namespaces": [{ "binding": "MY_KV", "id": "custom-id-123" }],
  }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.kv_namespaces.length(), 1)
      assert_eq(bindings.kv_namespaces[0].binding, "MY_KV")
      assert_eq(bindings.kv_namespaces[0].id, "custom-id-123")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings simple r2 format" {
  let json : Json = { "r2_buckets": ["MY_BUCKET"] }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.r2_buckets.length(), 1)
      assert_eq(bindings.r2_buckets[0].binding, "MY_BUCKET")
      assert_eq(bindings.r2_buckets[0].bucket_name, "wite-dev-my_bucket")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings explicit r2 format" {
  let json : Json = {
    "r2_buckets": [{ "binding": "MY_R2", "bucket_name": "my-prod-bucket" }],
  }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.r2_buckets.length(), 1)
      assert_eq(bindings.r2_buckets[0].binding, "MY_R2")
      assert_eq(bindings.r2_buckets[0].bucket_name, "my-prod-bucket")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings simple d1 format" {
  let json : Json = { "d1_databases": ["MY_DB"] }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.d1_databases.length(), 1)
      assert_eq(bindings.d1_databases[0].binding, "MY_DB")
      assert_eq(bindings.d1_databases[0].database_name, "wite-dev-my_db")
      assert_eq(bindings.d1_databases[0].database_id, "wite-dev-my_db")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings explicit d1 format" {
  let json : Json = {
    "d1_databases": [
      {
        "binding": "MY_DB",
        "database_name": "prod-db",
        "database_id": "abc-123",
      },
    ],
  }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.d1_databases.length(), 1)
      assert_eq(bindings.d1_databases[0].binding, "MY_DB")
      assert_eq(bindings.d1_databases[0].database_name, "prod-db")
      assert_eq(bindings.d1_databases[0].database_id, "abc-123")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings empty object" {
  let json : Json = {}
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.kv_namespaces.length(), 0)
      assert_eq(bindings.r2_buckets.length(), 0)
      assert_eq(bindings.d1_databases.length(), 0)
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings non-object error" {
  let json : Json = "invalid"
  let result = @config.parse_server_bindings(json)
  match result {
    Err(msg) => inspect(msg, content="bindings must be object")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_server_bindings kv invalid element" {
  let json : Json = { "kv_namespaces": [42] }
  let result = @config.parse_server_bindings(json)
  match result {
    Err(msg) => inspect(msg, content="kv_namespaces[] must be string or object")
    Ok(_) => fail("expected error")
  }
}

///|
test "parse_server_config with bindings" {
  let json : Json = {
    "executor": "workerd",
    "bindings": { "kv_namespaces": ["MY_KV"] },
  }
  let result = @config.parse_server_config(json)
  match result {
    Ok(config) => {
      assert_eq(config.executor, @config.ServerExecutor::Workerd)
      assert_eq(config.bindings.kv_namespaces.length(), 1)
      assert_eq(config.bindings.kv_namespaces[0].binding, "MY_KV")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_config without bindings defaults to empty" {
  let json : Json = { "executor": "workerd" }
  let result = @config.parse_server_config(json)
  match result {
    Ok(config) => {
      assert_eq(config.bindings.kv_namespaces.length(), 0)
      assert_eq(config.bindings.r2_buckets.length(), 0)
      assert_eq(config.bindings.d1_databases.length(), 0)
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "parse_server_bindings all types combined" {
  let json : Json = {
    "kv_namespaces": ["KV1"],
    "r2_buckets": [{ "binding": "R2", "bucket_name": "my-bucket" }],
    "d1_databases": ["DB1"],
  }
  let result = @config.parse_server_bindings(json)
  match result {
    Ok(bindings) => {
      assert_eq(bindings.kv_namespaces.length(), 1)
      assert_eq(bindings.r2_buckets.length(), 1)
      assert_eq(bindings.d1_databases.length(), 1)
      assert_eq(bindings.r2_buckets[0].bucket_name, "my-bucket")
    }
    Err(msg) => fail("unexpected error: " + msg)
  }
}

///|
test "config_input_single_path" {
  inspect(
    @config.config_input_single_path(@config.ConfigInput::new_none()),
    content="None",
  )
  inspect(
    @config.config_input_single_path(@config.ConfigInput::new_single("a.wasm")),
    content="Some(\"a.wasm\")",
  )
  let map : Map[String, String] = { "app": "b.wasm" }
  inspect(
    @config.config_input_single_path(@config.ConfigInput::new_named(map)),
    content="Some(\"b.wasm\")",
  )
}
