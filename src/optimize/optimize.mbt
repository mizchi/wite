///|
pub enum OptimizeKind {
  Auto
  Core
  Component
}

///|
pub fn optimize_kind_auto() -> OptimizeKind {
  OptimizeKind::Auto
}

///|
pub fn optimize_kind_core() -> OptimizeKind {
  OptimizeKind::Core
}

///|
pub fn optimize_kind_component() -> OptimizeKind {
  OptimizeKind::Component
}

///|
pub fn parse_optimize_kind(name : String) -> OptimizeKind? {
  match name.to_lower() {
    "auto" => Some(OptimizeKind::Auto)
    "core" => Some(OptimizeKind::Core)
    "component" => Some(OptimizeKind::Component)
    _ => None
  }
}

///|
pub fn optimize_kind_name(kind : OptimizeKind) -> String {
  match kind {
    OptimizeKind::Auto => "auto"
    OptimizeKind::Core => "core"
    OptimizeKind::Component => "component"
  }
}

///|
pub fn optimize_auto_for_size(
  bytes : Bytes,
  config : @wite.OptimizeConfig,
  exclude? : Array[String] = [],
) -> Result[@wite.OptimizeResult, String] {
  @wite.optimize_binary_for_size(bytes, config~, exclude~)
}

///|
pub fn optimize_core_for_size(
  bytes : Bytes,
  config : @wite.OptimizeConfig,
) -> Result[@wite.OptimizeResult, String] {
  match @wite.optimize_for_size(bytes, config~) {
    Ok(result) => Ok(result)
    Err(e) => Err(@wite.error_to_string(e))
  }
}

///|
pub fn optimize_component_for_size(
  bytes : Bytes,
  config : @wite.OptimizeConfig,
  exclude? : Array[String] = [],
) -> Result[@wite.OptimizeResult, String] {
  @wite.optimize_component_for_size(bytes, config~, exclude~)
}

///|
pub fn optimize_with_kind(
  bytes : Bytes,
  kind : OptimizeKind,
  config : @wite.OptimizeConfig,
  exclude? : Array[String] = [],
) -> Result[@wite.OptimizeResult, String] {
  match kind {
    OptimizeKind::Auto => optimize_auto_for_size(bytes, config, exclude~)
    OptimizeKind::Core => optimize_core_for_size(bytes, config)
    OptimizeKind::Component =>
      optimize_component_for_size(bytes, config, exclude~)
  }
}
