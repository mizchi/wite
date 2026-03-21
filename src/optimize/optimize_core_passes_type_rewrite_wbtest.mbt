///|
fn bytes_of_ints(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for value in values {
    out.push(value.to_byte())
  }
  Bytes::from_array(out[:])
}

///|
fn append_test_section(
  out : Array[Byte],
  section_id : UInt,
  payload : Bytes,
) -> Unit {
  out.push(section_id.to_byte())
  out.append(encode_u32_leb128(payload.length().reinterpret_as_uint())[:])
  out.append(payload[:].to_array())
}

///|
test "inlining temp-local candidate builds replacement for param reread body" {
  let body = bytes_of_ints([0x00, 0x20, 0x00, 0x20, 0x00, 0x6a, 0x0b])
  let type_entry : FunctionTypeEntry = {
    params: [bytes_of_ints([0x7f])],
    results: [bytes_of_ints([0x7f])],
  }
  guard extract_inlining_candidate_raise(body, type_entry) is Some(candidate) else {
    assert_true(false)
    return
  }
  assert_true(candidate.uses_temp_locals)
  let (replacement, prefix_growth) = build_temp_local_inlining_replacement_raise(
    candidate,
    1U,
    [],
    [],
  )
  inspect(replacement, content="b\"!\\x01 \\x01 \\x01j\"")
  assert_eq(prefix_growth, 2U)
}

///|
test "apply inlining optimizing rewrites param reread callee" {
  let out = bytes_of_ints([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]).to_array()
  append_test_section(
    out,
    1U,
    bytes_of_ints([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]),
  )
  append_test_section(out, 3U, bytes_of_ints([0x02, 0x00, 0x00]))
  append_test_section(
    out,
    7U,
    bytes_of_ints([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]),
  )
  append_test_section(
    out,
    10U,
    bytes_of_ints([
      0x02, 0x06, 0x00, 0x20, 0x00, 0x10, 0x01, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x20,
      0x00, 0x6a, 0x0b,
    ]),
  )
  let module_bytes = Bytes::from_array(out[:])
  let sections = parse_core_sections_raise(module_bytes)
  let function_payload = module_bytes[sections[1].payload_start:sections[1].section_end].to_bytes()
  let code_payload = module_bytes[sections[3].payload_start:sections[3].section_end].to_bytes()
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  let function_type_entry_map = parse_function_type_entry_map_for_function_indices_raise(
    module_bytes[sections[0].payload_start:sections[0].section_end].to_bytes(),
    function_type_indices,
    "wbtest-inlining",
  )
  let candidate_by_function_index : Map[UInt, InliningCandidate] = {}
  let body_bytes_by_function_index : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let function_index = i.reinterpret_as_uint()
    let type_entry = function_type_entry_map
      .get(function_type_indices[i])
      .unwrap()
    body_bytes_by_function_index.set(
      function_index,
      code_bodies[i].length().reinterpret_as_uint(),
    )
    match extract_inlining_candidate_raise(code_bodies[i], type_entry) {
      Some(candidate) =>
        candidate_by_function_index.set(function_index, candidate)
      None => ()
    }
  }
  guard candidate_by_function_index.get(1U) is Some(callee_candidate) else {
    assert_true(false)
    return
  }
  assert_true(callee_candidate.uses_temp_locals)
  let call_count_by_target = collect_call_count_by_target_raise(
    code_bodies, candidate_by_function_index,
  )
  let caller_prefix = parse_local_decl_prefix_raise(code_bodies[0])
  let caller_instr = code_bodies[0][caller_prefix.prefix_end:code_bodies[0].length()].to_bytes()
  let caller_spans = parse_instruction_spans_raise(caller_instr)
  let (_rewritten, rewritten_call_count, _added_locals) = rewrite_instruction_calls_for_inlining_raise(
    caller_instr,
    caller_spans,
    candidate_by_function_index,
    call_count_by_target,
    {},
    body_bytes_by_function_index,
    1U,
    [],
  )
  assert_eq(rewritten_call_count, 1U)
  let result = apply_inlining_optimizing_raise_with_sections(
    module_bytes, sections,
  )
  assert_eq(result.inlined_call_count, 1U)
}

///|
test "rewrite instruction calls inlines temp-local param reread candidate" {
  let body = bytes_of_ints([0x00, 0x20, 0x00, 0x20, 0x00, 0x6a, 0x0b])
  let type_entry : FunctionTypeEntry = {
    params: [bytes_of_ints([0x7f])],
    results: [bytes_of_ints([0x7f])],
  }
  guard extract_inlining_candidate_raise(body, type_entry) is Some(candidate) else {
    assert_true(false)
    return
  }
  let candidate_by_function_index : Map[UInt, InliningCandidate] = {}
  candidate_by_function_index.set(1U, candidate)
  let call_count_by_target : Map[UInt, UInt] = { 1U: 1U }
  let root_function_indices : Map[UInt, Bool] = {}
  let body_bytes_by_function_index : Map[UInt, UInt] = { 1U: 7U }
  let instr_bytes = bytes_of_ints([0x20, 0x00, 0x10, 0x01, 0x0b])
  let spans = parse_instruction_spans_raise(instr_bytes)
  let (_rewritten, rewritten_call_count, added_local_types) = rewrite_instruction_calls_for_inlining_raise(
    instr_bytes,
    spans,
    candidate_by_function_index,
    call_count_by_target,
    root_function_indices,
    body_bytes_by_function_index,
    1U,
    [],
  )
  assert_eq(rewritten_call_count, 1U)
  inspect(added_local_types.length(), content="1")
}

///|
test "inlining temp-local candidate remaps callee local access" {
  let body = bytes_of_ints([
    0x01, 0x01, 0x7f, 0x20, 0x00, 0x22, 0x01, 0x20, 0x01, 0x6a, 0x0b,
  ])
  let type_entry : FunctionTypeEntry = {
    params: [bytes_of_ints([0x7f])],
    results: [bytes_of_ints([0x7f])],
  }
  guard extract_inlining_candidate_raise(body, type_entry) is Some(candidate) else {
    assert_true(false)
    return
  }
  assert_true(candidate.uses_temp_locals)
  assert_eq(candidate.temp_param_count, 1U)
  inspect(candidate.temp_local_types.length(), content="2")
  let (replacement, prefix_growth) = build_temp_local_inlining_replacement_raise(
    candidate,
    1U,
    [],
    [],
  )
  inspect(replacement, content="b\"!\\x01 \\x01\\x22\\x02 \\x02j\"")
  assert_eq(prefix_growth, 2U)
}

///|
test "inlining candidate extracts if-return const wrapper" {
  let body = bytes_of_ints([
    0x00, 0x20, 0x00, 0x04, 0x40, 0x41, 0x00, 0x0f, 0x0b, 0x20, 0x00, 0x20, 0x01,
    0x6a, 0x0b,
  ])
  let type_entry : FunctionTypeEntry = {
    params: [bytes_of_ints([0x7f]), bytes_of_ints([0x7f])],
    results: [bytes_of_ints([0x7f])],
  }
  guard extract_inlining_candidate_raise(body, type_entry) is Some(candidate) else {
    assert_true(false)
    return
  }
  assert_true(candidate.uses_temp_locals)
  assert_eq(candidate.temp_param_count, 2U)
  inspect(
    candidate.replacement_instr,
    content="b\" \\x00\\x04\\x7fA\\x00\\x05 \\x00 \\x01j\\x0b\"",
  )
}
