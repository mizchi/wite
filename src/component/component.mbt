///|
pub fn verify_component_interface(
  component_bytes : Bytes,
  wit_path : String,
  world? : String,
) -> Result[Unit, String] {
  let resolved = match world {
    Some(world_name) =>
      match @wit.resolve_path(wit_path, world=world_name) {
        Ok(v) => v
        Err(e) => return Err("wit resolve failed: " + e.to_string())
      }
    None =>
      match @wit.resolve_path(wit_path) {
        Ok(v) => v
        Err(e) => return Err("wit resolve failed: " + e.to_string())
      }
  }
  match @mwac_component.check_component_targets(component_bytes, resolved) {
    Ok(_) => Ok(())
    Err(msg) => Err("interface verify failed: " + msg)
  }
}
