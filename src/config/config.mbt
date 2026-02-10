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
pub fn parse_binary_kind_or_exit(value : String, label : String) -> BinaryKind {
  match parse_binary_kind(value) {
    Some(kind) => kind
    None => {
      println("invalid " + label + ": " + value)
      @sys.exit(1)
      BinaryKind::Auto
    }
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
  }
}

///|
pub fn parse_config_input(json_value : Json) -> Result[ConfigInput, String] {
  match json_value {
    String(s) => Ok(ConfigInput::Single(s))
    Object(obj) => {
      let map : Map[String, String] = {}
      for entry in obj {
        match entry.1 {
          String(v) => map[entry.0] = v
          _ => return Err("config input." + entry.0 + " must be string")
        }
      }
      Ok(ConfigInput::Named(map))
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
      match object.get("flags") {
        Some(flags_value) =>
          match parse_json_string_array(flags_value, label + ".flags") {
            Ok(parsed) => flags = parsed
            Err(msg) => return Err(msg)
          }
        None => ()
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
      match object.get("build") {
        Some(value) =>
          match parse_wite_config_section(value, "build") {
            Ok((flags, kind)) => {
              build_flags = flags
              build_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      match object.get("analyze") {
        Some(value) =>
          match parse_wite_config_section(value, "analyze") {
            Ok((flags, kind)) => {
              analyze_flags = flags
              analyze_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      match object.get("profile") {
        Some(value) =>
          match parse_wite_config_section(value, "profile") {
            Ok((flags, kind)) => {
              profile_flags = flags
              profile_kind = kind
            }
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      let mut input = ConfigInput::None
      match object.get("input") {
        Some(value) =>
          match parse_config_input(value) {
            Ok(parsed) => input = parsed
            Err(msg) => return Err(msg)
          }
        None => ()
      }
      let mut output : ConfigOutput = { dir: "dist" }
      match object.get("output") {
        Some(value) =>
          match parse_config_output(value) {
            Ok(parsed) => output = parsed
            Err(msg) => return Err(msg)
          }
        None => ()
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
) -> ConfigSelectionFlags {
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
        println("missing config path after --config")
        @sys.exit(1)
      }
      let path = flags[i + 1]
      if path.is_empty() {
        println("config path must not be empty")
        @sys.exit(1)
      }
      config_path = path
      explicit_config_path = true
      use_config = true
      i += 2
      continue
    }
    match flag.strip_prefix("--config=") {
      Some(path) => {
        if path.is_empty() {
          println("config path must not be empty")
          @sys.exit(1)
        }
        config_path = path.to_string()
        explicit_config_path = true
        use_config = true
        i += 1
        continue
      }
      None => ()
    }
    remaining_flags.push(flag)
    i += 1
  }
  { config_path, explicit_config_path, use_config, remaining_flags }
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
pub fn load_wite_config_or_exit(path : String) -> WiteConfigFile {
  let text = @fs.read_file_to_string(path) catch {
    e => {
      println(
        "failed to read config file: " + path + " (" + e.to_string() + ")",
      )
      @sys.exit(1)
      ""
    }
  }
  match parse_wite_config_text(text) {
    Ok(config) => config
    Err(msg) => {
      println("failed to parse config file: " + path + " (" + msg + ")")
      @sys.exit(1)
      empty_wite_config_file()
    }
  }
}

///|
pub fn resolve_wite_config_or_default(
  selection : ConfigSelectionFlags,
) -> WiteConfigFile {
  if not(selection.use_config) {
    return empty_wite_config_file()
  }
  if not(@fs.path_exists(selection.config_path)) {
    if selection.explicit_config_path {
      println("config file not found: " + selection.config_path)
      @sys.exit(1)
    }
    return empty_wite_config_file()
  }
  load_wite_config_or_exit(selection.config_path)
}
