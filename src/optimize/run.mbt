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
