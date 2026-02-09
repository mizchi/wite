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
