///|
test "format_test_results: all pass" {
  let results : Array[TestResult] = [
    { name: "build succeeded", passed: true, message: "" },
    {
      name: "interface conforms to WIT (exports: 3, imports: 1)",
      passed: true,
      message: "",
    },
  ]
  let output = format_test_results(results)
  let expected =
    #|[wite] PASS: build succeeded
    #|[wite] PASS: interface conforms to WIT (exports: 3, imports: 1)
    #|[wite] 2 passed, 0 failed
  inspect(output, content=expected)
}

///|
test "format_test_results: mixed pass and fail" {
  let results : Array[TestResult] = [
    { name: "build succeeded", passed: true, message: "" },
    { name: "missing component exports: [process]", passed: false, message: "" },
  ]
  let output = format_test_results(results)
  let expected =
    #|[wite] PASS: build succeeded
    #|[wite] FAIL: missing component exports: [process]
    #|[wite] 1 passed, 1 failed
  inspect(output, content=expected)
}

///|
test "format_test_results: fail with message" {
  let results : Array[TestResult] = [
    {
      name: "interface conforms to WIT",
      passed: false,
      message: "wit resolve failed: file not found",
    },
  ]
  let output = format_test_results(results)
  let expected =
    #|[wite] FAIL: interface conforms to WIT
    #|[wite]   wit resolve failed: file not found
    #|[wite] 0 passed, 1 failed
  inspect(output, content=expected)
}
