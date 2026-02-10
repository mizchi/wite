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
