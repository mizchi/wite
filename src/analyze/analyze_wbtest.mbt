///|
test "format_percent normal" {
  inspect(format_percent(50U, 100U), content="50.00%")
  inspect(format_percent(1U, 3U), content="33.33%")
  inspect(format_percent(2U, 3U), content="66.66%")
}

///|
test "format_percent 100 percent" {
  inspect(format_percent(100U, 100U), content="100.00%")
}

///|
test "format_percent zero denominator" {
  inspect(format_percent(42U, 0U), content="0.00%")
}

///|
test "format_percent zero numerator" {
  inspect(format_percent(0U, 100U), content="0.00%")
}

///|
test "format_percent large values" {
  inspect(format_percent(999999U, 1000000U), content="99.99%")
}

///|
test "pad_two_digits_u64 single digit" {
  inspect(pad_two_digits_u64(0UL), content="00")
  inspect(pad_two_digits_u64(5UL), content="05")
  inspect(pad_two_digits_u64(9UL), content="09")
}

///|
test "pad_two_digits_u64 double digit" {
  inspect(pad_two_digits_u64(10UL), content="10")
  inspect(pad_two_digits_u64(42UL), content="42")
  inspect(pad_two_digits_u64(99UL), content="99")
}

///|
test "format_root_preview empty" {
  let roots : Array[UInt] = []
  inspect(format_root_preview(roots, 5U), content="(none)")
}

///|
test "format_root_preview within limit" {
  let roots : Array[UInt] = [0U, 1U, 2U]
  inspect(format_root_preview(roots, 5U), content="0, 1, 2")
}

///|
test "format_root_preview exceeds limit" {
  let roots : Array[UInt] = [0U, 1U, 2U, 3U, 4U]
  inspect(format_root_preview(roots, 3U), content="0, 1, 2 ... (+2)")
}

///|
test "format_root_preview exact limit" {
  let roots : Array[UInt] = [10U, 20U]
  inspect(format_root_preview(roots, 2U), content="10, 20")
}
