///|
pub fn profile_runtime_exports(
  _bytes : Bytes,
  iterations? : UInt = 50U,
  scenarios? : Array[RuntimeProfileScenario] = [],
) -> Result[RuntimeProfile, String] {
  let _dummy_profile : RuntimeProfile = {
    instantiate_ns: 0UL,
    iterations,
    functions: [{ name: "", calls: 0U, total_ns: 0UL, average_ns: 0UL }],
    skipped_exports: [],
    unresolved_exports: [{ export_name: "", reason: "", detail: "" }],
  }
  ignore(_dummy_profile)
  ignore(scenarios)
  Err("runtime profile is only supported on js target")
}

///|
pub fn profile_runtime_zero_arg_exports(
  _bytes : Bytes,
  iterations? : UInt = 50U,
) -> Result[RuntimeProfile, String] {
  ignore(iterations)
  Err("runtime profile is only supported on js target")
}
