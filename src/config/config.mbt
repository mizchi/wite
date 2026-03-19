///|
pub(all) enum ServerExecutor {
  Wagi
  Workerd
} derive(Show, Eq)

///|
pub(all) struct KvNamespaceBinding {
  binding : String
  id : String
} derive(Show, Eq)

///|
pub(all) struct R2BucketBinding {
  binding : String
  bucket_name : String
} derive(Show, Eq)

///|
pub(all) struct D1DatabaseBinding {
  binding : String
  database_name : String
  database_id : String
} derive(Show, Eq)

///|
pub(all) struct ServerBindings {
  kv_namespaces : Array[KvNamespaceBinding]
  r2_buckets : Array[R2BucketBinding]
  d1_databases : Array[D1DatabaseBinding]
} derive(Show, Eq)

///|
pub fn empty_server_bindings() -> ServerBindings {
  { kv_namespaces: [], r2_buckets: [], d1_databases: [] }
}

///|
pub struct ServerConfig {
  executor : ServerExecutor
  route : String
  bindings : ServerBindings
} derive(Show)

///|
pub fn parse_server_bindings(
  json_value : Json,
) -> Result[ServerBindings, String] {
  match json_value {
    Object(obj) => {
      let kv_namespaces : Array[KvNamespaceBinding] = []
      let r2_buckets : Array[R2BucketBinding] = []
      let d1_databases : Array[D1DatabaseBinding] = []
      if obj.get("kv_namespaces") is Some(Array(arr)) {
        for item in arr {
          match item {
            String(name) =>
              kv_namespaces.push({
                binding: name,
                id: "wite-dev-" + name.to_lower(),
              })
            Object(o) => {
              let binding = match o.get("binding") {
                Some(String(s)) => s
                _ => return Err("kv_namespaces[].binding must be string")
              }
              let id = match o.get("id") {
                Some(String(s)) => s
                _ => return Err("kv_namespaces[].id must be string")
              }
              kv_namespaces.push({ binding, id })
            }
            _ => return Err("kv_namespaces[] must be string or object")
          }
        }
      }
      if obj.get("r2_buckets") is Some(Array(arr)) {
        for item in arr {
          match item {
            String(name) =>
              r2_buckets.push({
                binding: name,
                bucket_name: "wite-dev-" + name.to_lower(),
              })
            Object(o) => {
              let binding = match o.get("binding") {
                Some(String(s)) => s
                _ => return Err("r2_buckets[].binding must be string")
              }
              let bucket_name = match o.get("bucket_name") {
                Some(String(s)) => s
                _ => return Err("r2_buckets[].bucket_name must be string")
              }
              r2_buckets.push({ binding, bucket_name })
            }
            _ => return Err("r2_buckets[] must be string or object")
          }
        }
      }
      if obj.get("d1_databases") is Some(Array(arr)) {
        for item in arr {
          match item {
            String(name) =>
              d1_databases.push({
                binding: name,
                database_name: "wite-dev-" + name.to_lower(),
                database_id: "wite-dev-" + name.to_lower(),
              })
            Object(o) => {
              let binding = match o.get("binding") {
                Some(String(s)) => s
                _ => return Err("d1_databases[].binding must be string")
              }
              let database_name = match o.get("database_name") {
                Some(String(s)) => s
                _ => return Err("d1_databases[].database_name must be string")
              }
              let database_id = match o.get("database_id") {
                Some(String(s)) => s
                _ => return Err("d1_databases[].database_id must be string")
              }
              d1_databases.push({ binding, database_name, database_id })
            }
            _ => return Err("d1_databases[] must be string or object")
          }
        }
      }
      Ok({ kv_namespaces, r2_buckets, d1_databases })
    }
    _ => Err("bindings must be object")
  }
}

///|
pub fn parse_server_config(json_value : Json) -> Result[ServerConfig, String] {
  match json_value {
    Object(obj) => {
      let mut executor = ServerExecutor::Wagi
      let mut route = "/..."
      let mut bindings = empty_server_bindings()
      match obj.get("executor") {
        Some(String(e)) =>
          match e.to_lower() {
            "wagi" => executor = ServerExecutor::Wagi
            "workerd" => executor = ServerExecutor::Workerd
            _ => return Err("invalid server.executor: " + e)
          }
        Some(_) => return Err("server.executor must be string")
        None => ()
      }
      match obj.get("route") {
        Some(String(r)) => route = r
        Some(_) => return Err("server.route must be string")
        None => ()
      }
      if obj.get("bindings") is Some(bindings_value) {
        match parse_server_bindings(bindings_value) {
          Ok(parsed) => bindings = parsed
          Err(msg) => return Err(msg)
        }
      }
      Ok({ executor, route, bindings })
    }
    _ => Err("server must be object")
  }
}

///|
pub enum BinaryKind {
  Auto
  Core
  Component
}

///|
pub fn parse_binary_kind(name : String) -> BinaryKind? {
  match name.to_lower() {
    "auto" => Some(BinaryKind::Auto)
    "core" => Some(BinaryKind::Core)
    "component" => Some(BinaryKind::Component)
    _ => None
  }
}

///|
pub fn binary_kind_name(kind : BinaryKind) -> String {
  match kind {
    BinaryKind::Auto => "auto"
    BinaryKind::Core => "core"
    BinaryKind::Component => "component"
  }
}


///|
pub enum ConfigInput {
  None
  Single(String)
  Named(Map[String, String])
} derive(Show)

///|
pub fn ConfigInput::new_none() -> ConfigInput {
  ConfigInput::None
}

///|
pub fn ConfigInput::new_single(s : String) -> ConfigInput {
  ConfigInput::Single(s)
}

///|
pub fn ConfigInput::new_named(map : Map[String, String]) -> ConfigInput {
  ConfigInput::Named(map)
}

///|
pub struct ConfigOutput {
  dir : String
}

///|
pub struct WiteConfigFile {
  build_flags : Array[String]
  analyze_flags : Array[String]
  profile_flags : Array[String]
  build_kind : BinaryKind
  analyze_kind : BinaryKind
  profile_kind : BinaryKind
  input : ConfigInput
  output : ConfigOutput
  server : ServerConfig?
}

///|
pub fn empty_wite_config_file() -> WiteConfigFile {
  {
    build_flags: [],
    analyze_flags: [],
    profile_flags: [],
    build_kind: BinaryKind::Auto,
    analyze_kind: BinaryKind::Auto,
    profile_kind: BinaryKind::Auto,
    input: ConfigInput::None,
    output: { dir: "dist" },
    server: None,
  }
}

///|
pub fn parse_config_input(json_value : Json) -> Result[ConfigInput, String] {
  match json_value {
    String(s) => s |> ConfigInput::Single |> Ok
    Object(obj) => {
      let map : Map[String, String] = {}
      for entry in obj {
        match entry.1 {
          String(v) => map[entry.0] = v
          _ => return Err("config input." + entry.0 + " must be string")
        }
      }
      map |> ConfigInput::Named |> Ok
    }
    _ => Err("config input must be string or object")
  }
}

///|
pub fn parse_config_output(json_value : Json) -> Result[ConfigOutput, String] {
  match json_value {
    String(s) => Ok({ dir: s })
    Object(obj) =>
      match obj.get("dir") {
        Some(String(d)) => Ok({ dir: d })
        Some(_) => Err("config output.dir must be string")
        None => Ok({ dir: "dist" })
      }
    _ => Err("config output must be string or object")
  }
}

///|
pub fn config_input_entries(input : ConfigInput) -> Array[(String, String)] {
  match input {
    ConfigInput::None => []
    ConfigInput::Single(s) => [("default", s)]
    ConfigInput::Named(map) => {
      let out : Array[(String, String)] = []
      for entry in map {
        out.push((entry.0, entry.1))
      }
      out
    }
  }
}

///|
pub fn config_input_single_path(input : ConfigInput) -> String? {
  match input {
    ConfigInput::None => None
    ConfigInput::Single(s) => Some(s)
    ConfigInput::Named(map) => {
      for entry in map {
        return Some(entry.1)
      }
      None
    }
  }
}

///|
pub fn parse_json_string_array(
  json_value : Json,
  label : String,
) -> Result[Array[String], String] {
  match json_value {
    Array(values) => {
      let out : Array[String] = []
      for i in 0..<values.length() {
        match values[i] {
          String(value) => out.push(value)
          _ =>
            return Err(
              "config " + label + "[" + i.to_string() + "] must be string",
            )
        }
      }
      Ok(out)
    }
    _ => Err("config " + label + " must be string array")
  }
}

///|
pub fn parse_wite_config_section(
  json_value : Json,
  label : String,
) -> Result[(Array[String], BinaryKind), String] {
  match json_value {
    Array(_) =>
      match parse_json_string_array(json_value, label) {
        Ok(flags) => Ok((flags, BinaryKind::Auto))
        Err(msg) => Err(msg)
      }
    Object(object) => {
      let mut flags : Array[String] = []
      let mut kind = BinaryKind::Auto
      if object.get("flags") is Some(flags_value) {
        match parse_json_string_array(flags_value, label + ".flags") {
          Ok(parsed) => flags = parsed
          Err(msg) => return Err(msg)
        }
      }
      match object.get("kind") {
        Some(String(raw_kind)) =>
          match parse_binary_kind(raw_kind) {
            Some(parsed_kind) => kind = parsed_kind
            None => return Err("invalid config " + label + ".kind: " + raw_kind)
          }
        Some(_) => return Err("config " + label + ".kind must be string")
        None => ()
      }
      Ok((flags, kind))
    }
    _ => Err("config " + label + " must be array or object")
  }
}

///|
pub fn parse_wite_config_json(
  json_value : Json,
) -> Result[WiteConfigFile, String] {
  match json_value {
    Object(object) => {
      let mut build_flags : Array[String] = []
      let mut analyze_flags : Array[String] = []
      let mut profile_flags : Array[String] = []
      let mut build_kind = BinaryKind::Auto
      let mut analyze_kind = BinaryKind::Auto
      let mut profile_kind = BinaryKind::Auto
      if object.get("build") is Some(value) {
        match parse_wite_config_section(value, "build") {
          Ok((flags, kind)) => {
            build_flags = flags
            build_kind = kind
          }
          Err(msg) => return Err(msg)
        }
      }
      if object.get("analyze") is Some(value) {
        match parse_wite_config_section(value, "analyze") {
          Ok((flags, kind)) => {
            analyze_flags = flags
            analyze_kind = kind
          }
          Err(msg) => return Err(msg)
        }
      }
      if object.get("profile") is Some(value) {
        match parse_wite_config_section(value, "profile") {
          Ok((flags, kind)) => {
            profile_flags = flags
            profile_kind = kind
          }
          Err(msg) => return Err(msg)
        }
      }
      let mut input = ConfigInput::None
      if object.get("input") is Some(value) {
        match parse_config_input(value) {
          Ok(parsed) => input = parsed
          Err(msg) => return Err(msg)
        }
      }
      let mut output : ConfigOutput = { dir: "dist" }
      if object.get("output") is Some(value) {
        match parse_config_output(value) {
          Ok(parsed) => output = parsed
          Err(msg) => return Err(msg)
        }
      }
      let mut server : ServerConfig? = None
      if object.get("server") is Some(value) {
        match parse_server_config(value) {
          Ok(parsed) => server = Some(parsed)
          Err(msg) => return Err(msg)
        }
      }
      Ok({
        build_flags,
        analyze_flags,
        profile_flags,
        build_kind,
        analyze_kind,
        profile_kind,
        input,
        output,
        server,
      })
    }
    _ => Err("config root must be object")
  }
}

///|
pub fn parse_wite_config_text(text : String) -> Result[WiteConfigFile, String] {
  let json_value = @json5.parse(text) catch {
    parse_error => return Err(parse_error.to_string())
  }
  parse_wite_config_json(json_value)
}

///|
pub struct ConfigSelectionFlags {
  config_path : String
  explicit_config_path : Bool
  use_config : Bool
  remaining_flags : Array[String]
}

///|
pub fn parse_config_selection_flags(
  flags : Array[String],
) -> Result[ConfigSelectionFlags, String] {
  let mut config_path = "wite.config.jsonc"
  let mut explicit_config_path = false
  let mut use_config = true
  let remaining_flags : Array[String] = []
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    if flag == "--no-config" {
      use_config = false
      i += 1
      continue
    }
    if flag == "--config" {
      if i + 1 >= flags.length() {
        return Err("missing config path after --config")
      }
      let path = flags[i + 1]
      if path.is_empty() {
        return Err("config path must not be empty")
      }
      config_path = path
      explicit_config_path = true
      use_config = true
      i += 2
      continue
    }
    if flag.strip_prefix("--config=") is Some(path) {
      if path.is_empty() {
        return Err("config path must not be empty")
      }
      config_path = path.to_string()
      explicit_config_path = true
      use_config = true
      i += 1
      continue
    }
    remaining_flags.push(flag)
    i += 1
  }
  Ok({ config_path, explicit_config_path, use_config, remaining_flags })
}

///|
pub fn merge_command_flags(
  defaults : Array[String],
  cli_flags : Array[String],
) -> Array[String] {
  let merged = defaults.copy()
  merged.append(cli_flags[:])
  merged
}

///|
pub fn should_auto_sync_deps(use_config : Bool, config_exists : Bool) -> Bool {
  use_config && config_exists
}

///|
pub fn build_auto_sync_deps_command_args(config_path : String) -> Array[String] {
  ["wite", "deps", "sync", "--config=" + config_path, "--fail-fast"]
}

///|
pub fn is_ts_config(path : String) -> Bool {
  path.has_suffix(".ts")
}

