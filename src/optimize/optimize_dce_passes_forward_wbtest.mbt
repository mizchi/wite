///|
fn wb_bytes_of_ints(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for value in values {
    out.push(value.to_byte())
  }
  Bytes::from_array(out[:])
}

///|
test "cfp-const rewrite uses scratch locals for interleaved const args" {
  let alias_map : Map[UInt, CfpConstAlias] = {}
  alias_map.set(1U, {
    target: 2U,
    target_arg_instrs: [
      wb_bytes_of_ints([0x20, 0x00]),
      wb_bytes_of_ints([0x41, 0x05]),
      wb_bytes_of_ints([0x20, 0x01]),
    ],
    wrapper_param_count: 2U,
    wrapper_param_local_types: wb_bytes_of_ints([0x7f, 0x7f]).to_array(),
    uses_scratch_locals: true,
  })
  let instr_bytes = wb_bytes_of_ints([0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b])
  let spans = parse_instruction_spans_raise(instr_bytes)
  let (rewritten, rewritten_call_count, added_local_types) = rewrite_instruction_calls_for_const_call_forwarding_raise(
    instr_bytes,
    spans,
    alias_map,
    2U,
    [],
  )
  assert_eq(rewritten_call_count, 1U)
  inspect(added_local_types, content="[b'\\x7F', b'\\x7F']")
  inspect(
    rewritten,
    content="b\" \\x00 \\x01!\\x03!\\x02 \\x02A\\x05 \\x03\\x10\\x02\\x0b\"",
  )
}
