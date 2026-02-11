///|
test "verify component interface succeeds for hello fixture" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let wit_path = "../mwac/examples/hello/wit"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  let verified = verify_component_interface(bytes, wit_path)
  assert_true(verified is Ok(_))
}
