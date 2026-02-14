///|
fn push_bytes(out : Array[Byte], values : Array[Int]) -> Unit {
  for v in values {
    out.push(v.to_byte())
  }
}

///|
/// Build a minimal core wasm module with an `add(i32, i32) -> i32` function.
fn make_test_add_module() -> Bytes {
  let out : Array[Byte] = []
  // wasm header
  push_bytes(out, [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section (id=1): 1 type, func(i32, i32) -> i32
  push_bytes(out, [0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f])
  // function section (id=3): 1 function, type index 0
  push_bytes(out, [0x03, 0x02, 0x01, 0x00])
  // export section (id=7): export "add" as func 0
  push_bytes(out, [0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00])
  // code section (id=10): 1 body: local.get 0 + local.get 1 + i32.add
  push_bytes(out, [
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
  ])
  Bytes::from_array(out[:])
}

///|
/// Build a minimal core wasm module with no function exports (only memory).
fn make_test_memory_only_module() -> Bytes {
  let out : Array[Byte] = []
  // wasm header
  push_bytes(out, [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section (id=1): 0 types
  push_bytes(out, [0x01, 0x01, 0x00])
  // function section (id=3): 0 functions
  push_bytes(out, [0x03, 0x01, 0x00])
  // memory section (id=5): 1 memory, min 1 page
  push_bytes(out, [0x05, 0x03, 0x01, 0x00, 0x01])
  // export section (id=7): export "memory" as memory 0
  push_bytes(out, [
    0x07, 0x0a, 0x01, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00,
  ])
  // code section (id=10): 0 bodies
  push_bytes(out, [0x0a, 0x01, 0x00])
  Bytes::from_array(out[:])
}

///|
/// Build a core wasm module with an import (to test rejection).
fn make_test_module_with_import() -> Bytes {
  let out : Array[Byte] = []
  // wasm header
  push_bytes(out, [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section (id=1): 1 type, func() -> ()
  push_bytes(out, [0x01, 0x04, 0x01, 0x60, 0x00, 0x00])
  // import section (id=2): 1 import, "env"."log" func type 0
  push_bytes(out, [
    0x02, 0x0b, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x03, 0x6c, 0x6f, 0x67, 0x00, 0x00,
  ])
  // function section (id=3): 0 local functions
  push_bytes(out, [0x03, 0x01, 0x00])
  // export section (id=7): 0 exports
  push_bytes(out, [0x07, 0x01, 0x00])
  // code section (id=10): 0 bodies
  push_bytes(out, [0x0a, 0x01, 0x00])
  Bytes::from_array(out[:])
}

///|
test "componentize add module produces valid component header" {
  let core = make_test_add_module()
  let result = componentize_core_module(core)
  assert_true(result is Ok(_))
  let component = match result {
    Ok(r) => r
    Err(_) => panic()
  }
  // Check component header bytes
  assert_eq(component.bytes[0], 0x00U.to_byte()) // \0
  assert_eq(component.bytes[1], 0x61U.to_byte()) // a
  assert_eq(component.bytes[2], 0x73U.to_byte()) // s
  assert_eq(component.bytes[3], 0x6dU.to_byte()) // m
  assert_eq(component.bytes[4], 0x0dU.to_byte()) // component version
  assert_eq(component.bytes[5], 0x00U.to_byte())
  assert_eq(component.bytes[6], 0x01U.to_byte())
  assert_eq(component.bytes[7], 0x00U.to_byte())
}

///|
test "componentize add module exports add function" {
  let core = make_test_add_module()
  let result = componentize_core_module(core)
  assert_true(result is Ok(_))
  let component = match result {
    Ok(r) => r
    Err(_) => panic()
  }
  assert_eq(component.exported_functions.length(), 1)
  assert_eq(component.exported_functions[0], "add")
}

///|
test "componentize add module can be parsed as component" {
  let core = make_test_add_module()
  let result = componentize_core_module(core)
  assert_true(result is Ok(_))
  let component = match result {
    Ok(r) => r
    Err(_) => panic()
  }
  // Verify the output can be parsed as a component
  let sections = @wite.parse_component_sections_raise(component.bytes) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  // Should have: core:module(1), core:instance(2), alias(6), type(7), canon(8), export(11)
  assert_true(sections.length() >= 5)
}

///|
test "componentize rejects module with imports" {
  let core = make_test_module_with_import()
  let result = componentize_core_module(core)
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("imports"))
    Ok(_) => assert_true(false)
  }
}

///|
test "componentize rejects module with no function exports" {
  let core = make_test_memory_only_module()
  let result = componentize_core_module(core)
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("no function exports"))
    Ok(_) => assert_true(false)
  }
}

///|
test "core valtype to component mapping" {
  // i32 -> s32
  assert_eq(
    core_valtype_to_component(Bytes::from_array([0x7fU.to_byte()])),
    Ok(0x7aU.to_byte()),
  )
  // i64 -> s64
  assert_eq(
    core_valtype_to_component(Bytes::from_array([0x7eU.to_byte()])),
    Ok(0x78U.to_byte()),
  )
  // f32 -> f32
  assert_eq(
    core_valtype_to_component(Bytes::from_array([0x7dU.to_byte()])),
    Ok(0x76U.to_byte()),
  )
  // f64 -> f64
  assert_eq(
    core_valtype_to_component(Bytes::from_array([0x7cU.to_byte()])),
    Ok(0x75U.to_byte()),
  )
  // unsupported type
  assert_true(
    core_valtype_to_component(Bytes::from_array([0x70U.to_byte()])) is Err(_),
  )
}

///|
test "string to utf8 bytes ascii" {
  let bytes = string_to_utf8_bytes("add")
  assert_eq(bytes.length(), 3)
  assert_eq(bytes[0], 0x61U.to_byte())
  assert_eq(bytes[1], 0x64U.to_byte())
  assert_eq(bytes[2], 0x64U.to_byte())
}
