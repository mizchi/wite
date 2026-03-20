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
  let result = @config.parse_config_selection_flags(flags).unwrap()
  inspect(result.config_path, content="wite.config.jsonc")
  inspect(result.explicit_config_path, content="false")
  inspect(result.use_config, content="true")
  inspect(result.remaining_flags.length(), content="0")
}

///|
test "parse_config_selection_flags no-config" {
  let flags : Array[String] = ["--no-config"]
  let result = @config.parse_config_selection_flags(flags).unwrap()
  inspect(result.use_config, content="false")
}

///|
test "parse_config_selection_flags remaining flags preserved" {
  let flags : Array[String] = ["--no-config", "--other", "value"]
  let result = @config.parse_config_selection_flags(flags).unwrap()
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

///|
test "parse_wite_config_text valid json5" {
  let text =
    #|{
    #|  // comment allowed in json5
    #|  "build": ["--kind", "core"],
    #|  "input": "app.wasm"
    #|}
  let result = @config.parse_wite_config_text(text)
  assert_true(result is Ok(_))
  let config = result.unwrap()
  assert_eq(config.build_flags, ["--kind", "core"])
  match config.input {
    @config.ConfigInput::Single(s) => assert_eq(s, "app.wasm")
    _ => fail("expected Single input")
  }
}

///|
test "parse_wite_config_text empty object" {
  let result = @config.parse_wite_config_text("{}")
  assert_true(result is Ok(_))
  let config = result.unwrap()
  assert_eq(config.build_flags, [])
  assert_true(config.input is @config.ConfigInput::None)
}

///|
test "parse_wite_config_text invalid json returns Err" {
  let result = @config.parse_wite_config_text("not json at all {{{")
  assert_true(result is Err(_))
}

///|
test "parse_wite_config_text non-object root returns Err" {
  let result = @config.parse_wite_config_text("[1,2,3]")
  assert_true(result is Err(_))
}

///|
test "parse_wite_config_text with server config" {
  let text =
    #|{
    #|  "server": {
    #|    "executor": "workerd",
    #|    "route": "/api/..."
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  match config.server {
    Some(s) => {
      assert_true(s.executor is @config.ServerExecutor::Workerd)
      assert_eq(s.route, "/api/...")
    }
    None => fail("expected server config")
  }
}

///|
test "parse_config_selection_flags --config with value" {
  let result = @config.parse_config_selection_flags([
    "--config", "custom.jsonc", "--other",
  ])
  let parsed = result.unwrap()
  assert_eq(parsed.config_path, "custom.jsonc")
  assert_true(parsed.explicit_config_path)
  assert_true(parsed.use_config)
  assert_eq(parsed.remaining_flags, ["--other"])
}

///|
test "parse_config_selection_flags --config= form" {
  let result = @config.parse_config_selection_flags(["--config=my.jsonc"])
  let parsed = result.unwrap()
  assert_eq(parsed.config_path, "my.jsonc")
  assert_true(parsed.explicit_config_path)
}

///|
test "parse_config_selection_flags --config missing value returns Err" {
  let result = @config.parse_config_selection_flags(["--config"])
  assert_true(result is Err(_))
}

///|
test "parse_config_selection_flags --config= empty returns Err" {
  let result = @config.parse_config_selection_flags(["--config="])
  assert_true(result is Err(_))
}

///|
test "parse_config_selection_flags --config empty value returns Err" {
  let result = @config.parse_config_selection_flags(["--config", ""])
  assert_true(result is Err(_))
}

// ---- --env flag parsing ----

///|
test "parse_config_selection_flags --env with value" {
  let result = @config.parse_config_selection_flags([
    "--env", "browser", "--other",
  ]).unwrap()
  assert_eq(result.env_name, Some("browser"))
  assert_eq(result.remaining_flags, ["--other"])
}

///|
test "parse_config_selection_flags --env= form" {
  let result = @config.parse_config_selection_flags(["--env=edge"]).unwrap()
  assert_eq(result.env_name, Some("edge"))
}

///|
test "parse_config_selection_flags no --env gives None" {
  let result = @config.parse_config_selection_flags(["-Oz", "--no-config"]).unwrap()
  assert_true(result.env_name is None)
}

///|
test "parse_config_selection_flags --env missing value returns Err" {
  let result = @config.parse_config_selection_flags(["--env"])
  assert_true(result is Err(_))
}

///|
test "parse_config_selection_flags --env= empty returns Err" {
  let result = @config.parse_config_selection_flags(["--env="])
  assert_true(result is Err(_))
}

///|
test "parse_config_selection_flags --env combined with --config" {
  let result = @config.parse_config_selection_flags([
    "--config=custom.jsonc", "--env=release", "-Oz",
  ]).unwrap()
  assert_eq(result.config_path, "custom.jsonc")
  assert_eq(result.env_name, Some("release"))
  assert_eq(result.remaining_flags, ["-Oz"])
}

// ---- environment tests ----

///|
test "parse_wite_config_text with environments" {
  let text =
    #|{
    #|  "input": "app.wac",
    #|  "environments": {
    #|    "browser": {
    #|      "output": "dist/browser",
    #|      "optimize": "-Os"
    #|    },
    #|    "edge": {
    #|      "output": "dist/edge",
    #|      "optimize": "-O1",
    #|      "server": { "executor": "workerd" }
    #|    }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  assert_eq(@config.environment_names(config).length(), 2)
  let browser = config.environments["browser"]
  assert_eq(browser.output.dir, "dist/browser")
  assert_eq(browser.optimize, Some("-Os"))
  let edge = config.environments["edge"]
  assert_eq(edge.output.dir, "dist/edge")
  assert_eq(edge.optimize, Some("-O1"))
  assert_true(edge.server is Some(_))
  match edge.server {
    Some(s) => assert_true(s.executor is @config.ServerExecutor::Workerd)
    None => fail("expected server config")
  }
}

///|
test "parse_wite_config_text environments with kind and strip" {
  let text =
    #|{
    #|  "environments": {
    #|    "release": {
    #|      "optimize": "-Oz",
    #|      "kind": "core",
    #|      "strip": true,
    #|      "closed-world": true,
    #|      "closed-world-roots": ["main", "init"]
    #|    }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let release = config.environments["release"]
  assert_true(release.strip)
  assert_true(release.closed_world)
  assert_eq(release.closed_world_root_exports, ["main", "init"])
  assert_true(release.kind is @config.BinaryKind::Core)
}

///|
test "parse_wite_config_text no environments" {
  let text =
    #|{ "input": "app.wac" }
  let config = @config.parse_wite_config_text(text).unwrap()
  assert_eq(@config.environment_names(config).length(), 0)
}

///|
test "parse_environment_config invalid kind" {
  let text =
    #|{
    #|  "environments": {
    #|    "bad": { "kind": "invalid" }
    #|  }
    #|}
  let result = @config.parse_wite_config_text(text)
  assert_true(result is Err(_))
}

///|
test "resolve_environment default when no env name" {
  let text =
    #|{ "input": "app.wac", "build": { "kind": "component" } }
  let config = @config.parse_wite_config_text(text).unwrap()
  let env = @config.resolve_environment(config, None).unwrap()
  assert_true(env.input is @config.ConfigInput::Single(_))
  assert_true(env.kind is @config.BinaryKind::Component)
}

///|
test "resolve_environment selects named environment" {
  let text =
    #|{
    #|  "input": "app.wac",
    #|  "environments": {
    #|    "edge": {
    #|      "output": "dist/edge",
    #|      "optimize": "-O1",
    #|      "kind": "component"
    #|    }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let env = @config.resolve_environment(config, Some("edge")).unwrap()
  assert_eq(env.output.dir, "dist/edge")
  assert_eq(env.optimize, Some("-O1"))
  assert_true(env.kind is @config.BinaryKind::Component)
  // input falls back to top-level
  assert_true(env.input is @config.ConfigInput::Single(_))
}

///|
test "resolve_environment inherits top-level input" {
  let text =
    #|{
    #|  "input": "main.wac",
    #|  "environments": {
    #|    "debug": { "optimize": "-O0" }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let env = @config.resolve_environment(config, Some("debug")).unwrap()
  match env.input {
    @config.ConfigInput::Single(s) => assert_eq(s, "main.wac")
    _ => fail("expected Single input inherited from top-level")
  }
  assert_eq(env.optimize, Some("-O0"))
}

///|
test "resolve_environment overrides input" {
  let text =
    #|{
    #|  "input": "app.wac",
    #|  "environments": {
    #|    "alt": { "input": "other.wac" }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let env = @config.resolve_environment(config, Some("alt")).unwrap()
  match env.input {
    @config.ConfigInput::Single(s) => assert_eq(s, "other.wac")
    _ => fail("expected overridden input")
  }
}

///|
test "resolve_environment not found returns Err" {
  let config = @config.empty_wite_config_file()
  let result = @config.resolve_environment(config, Some("missing"))
  assert_true(result is Err(_))
}

///|
test "environment_names returns sorted keys" {
  let text =
    #|{
    #|  "environments": {
    #|    "b": { "optimize": "-O1" },
    #|    "a": { "optimize": "-O0" }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let names = @config.environment_names(config)
  assert_eq(names.length(), 2)
  assert_true(names.contains("a"))
  assert_true(names.contains("b"))
}

///|
test "empty_environment_config has safe defaults" {
  let env = @config.empty_environment_config()
  assert_true(env.input is @config.ConfigInput::None)
  assert_eq(env.output.dir, "dist")
  assert_true(env.optimize is None)
  assert_true(env.kind is @config.BinaryKind::Auto)
  assert_true(env.server is None)
  assert_false(env.strip)
  assert_false(env.closed_world)
  assert_eq(env.closed_world_root_exports, [])
}

// ---- chunk tests ----

///|
test "parse_wite_config_text with chunks" {
  let text =
    #|{
    #|  "chunks": {
    #|    "guest": {
    #|      "build": "moon build --target wasm -p guest",
    #|      "output": "build/guest.core.wasm",
    #|      "wit": "wit/guest.wit"
    #|    },
    #|    "auth": {
    #|      "build": "cargo component build",
    #|      "output": "target/auth.wasm"
    #|    }
    #|  },
    #|  "input": "app.wac"
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let names = @config.chunk_names(config)
  assert_eq(names.length(), 2)
  assert_true(names.contains("guest"))
  assert_true(names.contains("auth"))
  let guest = config.chunks["guest"]
  assert_eq(guest.build, Some("moon build --target wasm -p guest"))
  assert_eq(guest.output, "build/guest.core.wasm")
  assert_eq(guest.wit, Some("wit/guest.wit"))
  let auth = config.chunks["auth"]
  assert_eq(auth.output, "target/auth.wasm")
  assert_true(auth.wit is None)
}

///|
test "parse_wite_config_text chunk string shorthand" {
  let text =
    #|{
    #|  "chunks": {
    #|    "lib": "deps/lib.wasm"
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let lib = config.chunks["lib"]
  assert_eq(lib.output, "deps/lib.wasm")
  assert_true(lib.build is None)
  assert_true(lib.wit is None)
}

///|
test "parse_wite_config_text chunk with world" {
  let text =
    #|{
    #|  "chunks": {
    #|    "api": {
    #|      "output": "api.wasm",
    #|      "wit": "wit/api.wit",
    #|      "world": "api-world"
    #|    }
    #|  }
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  let api = config.chunks["api"]
  assert_eq(api.world, Some("api-world"))
}

///|
test "parse_wite_config_text chunk missing output returns Err" {
  let text =
    #|{
    #|  "chunks": {
    #|    "bad": { "build": "make" }
    #|  }
    #|}
  let result = @config.parse_wite_config_text(text)
  assert_true(result is Err(_))
}

///|
test "parse_wite_config_text no chunks" {
  let text =
    #|{ "input": "app.wac" }
  let config = @config.parse_wite_config_text(text).unwrap()
  assert_eq(@config.chunk_names(config).length(), 0)
}

///|
test "empty_chunk_config has safe defaults" {
  let chunk = @config.empty_chunk_config()
  assert_true(chunk.build is None)
  assert_eq(chunk.output, "")
  assert_true(chunk.wit is None)
  assert_true(chunk.world is None)
}

///|
test "parse_wite_config_text chunks combined with environments" {
  let text =
    #|{
    #|  "chunks": {
    #|    "guest": { "output": "guest.wasm", "build": "moon build" }
    #|  },
    #|  "environments": {
    #|    "dev": { "optimize": "-O0" },
    #|    "release": { "optimize": "-Oz" }
    #|  },
    #|  "input": "app.wac"
    #|}
  let config = @config.parse_wite_config_text(text).unwrap()
  assert_eq(@config.chunk_names(config).length(), 1)
  assert_eq(@config.environment_names(config).length(), 2)
}
