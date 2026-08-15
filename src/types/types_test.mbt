///|
test "error_to_string UnexpectedEof" {
  inspect(@types.error_to_string(UnexpectedEof), content="unexpected eof")
}

///|
test "error_to_string InvalidMagic" {
  inspect(@types.error_to_string(InvalidMagic), content="invalid wasm magic")
}

///|
test "error_to_string UnsupportedVersion" {
  inspect(
    @types.error_to_string(UnsupportedVersion("42")),
    content="unsupported version: 42",
  )
}

///|
test "error_to_string InvalidFormat" {
  inspect(
    @types.error_to_string(InvalidFormat("bad section")),
    content="invalid format: bad section",
  )
}

///|
test "OptimizeConfig::o0 disables all passes" {
  let c = @types.OptimizeConfig::o0()
  assert_false(c.enable_peephole)
  assert_false(c.enable_vacuum)
  assert_false(c.enable_merge_blocks)
  assert_false(c.enable_remove_unused_brs)
  assert_false(c.enable_dce)
  assert_false(c.enable_dfe)
  assert_false(c.enable_merge_similar_functions)
  assert_false(c.strip_name_section)
  assert_false(c.strip_producers_section)
  assert_eq(c.pass_rounds, 1U)
}

///|
test "OptimizeConfig::o1 enables DCE and strips debug" {
  let c = @types.OptimizeConfig::o1()
  assert_true(c.enable_peephole)
  assert_true(c.enable_dce)
  assert_true(c.enable_dfe)
  assert_true(c.enable_merge_similar_functions)
  assert_true(c.enable_remove_unused_module_elements)
  assert_true(c.strip_debug_sections)
  assert_true(c.strip_dwarf_sections)
  assert_true(c.strip_target_features_section)
  assert_eq(c.pass_rounds, 2U)
}

///|
test "OptimizeConfig::o2 enables DCE but not DFE" {
  let c = @types.OptimizeConfig::o2()
  assert_true(c.enable_dce)
  assert_false(c.enable_dfe)
  assert_false(c.enable_merge_similar_functions)
  assert_eq(c.pass_rounds, 2U)
}

///|
test "OptimizeConfig::o3 enables all with 3 rounds" {
  let c = @types.OptimizeConfig::o3()
  assert_true(c.enable_dce)
  assert_true(c.enable_dfe)
  assert_true(c.enable_merge_similar_functions)
  assert_true(c.enable_remove_unused_module_elements)
  assert_eq(c.pass_rounds, 3U)
}

///|
test "OptimizeConfig::os enables DFE but not merge_similar" {
  let c = @types.OptimizeConfig::os()
  assert_true(c.enable_dce)
  assert_true(c.enable_dfe)
  assert_false(c.enable_merge_similar_functions)
  assert_true(c.enable_remove_unused_module_elements)
  assert_eq(c.pass_rounds, 3U)
}

///|
test "OptimizeConfig::oz uses 8 rounds" {
  let c = @types.OptimizeConfig::oz()
  assert_true(c.enable_dce)
  assert_true(c.enable_dfe)
  assert_true(c.enable_merge_similar_functions)
  assert_true(c.enable_remove_unused_module_elements)
  assert_eq(c.pass_rounds, 8U)
}

///|
test "OptimizeConfig::default enables peephole but not DCE" {
  let c = @types.OptimizeConfig::default()
  assert_true(c.enable_peephole)
  assert_true(c.enable_vacuum)
  assert_true(c.enable_merge_blocks)
  assert_true(c.enable_remove_unused_brs)
  assert_false(c.enable_dce)
  assert_false(c.enable_dfe)
  assert_true(c.strip_name_section)
  assert_true(c.strip_producers_section)
  assert_eq(c.pass_rounds, 1U)
}

///|
test "OptimizeConfig::aggressive strips all custom" {
  let c = @types.OptimizeConfig::aggressive()
  assert_true(c.strip_all_custom)
  assert_true(c.strip_name_section)
  assert_true(c.strip_producers_section)
  assert_true(c.strip_debug_sections)
  assert_true(c.strip_dwarf_sections)
  assert_true(c.strip_target_features_section)
}

///|
test "optimize_config_from_opt_level valid levels" {
  assert_true(@types.optimize_config_from_opt_level("-O0") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-O1") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-O") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-O2") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-O3") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-O4") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-Os") is Some(_))
  assert_true(@types.optimize_config_from_opt_level("-Oz") is Some(_))
}

///|
test "optimize_config_from_opt_level invalid returns None" {
  assert_true(@types.optimize_config_from_opt_level("") is None)
  assert_true(@types.optimize_config_from_opt_level("-O5") is None)
  assert_true(@types.optimize_config_from_opt_level("O1") is None)
  assert_true(@types.optimize_config_from_opt_level("fast") is None)
}

///|
test "optimize_config_from_opt_level -O aliases -O2" {
  let o = @types.optimize_config_from_opt_level("-O").unwrap()
  let o2 = @types.optimize_config_from_opt_level("-O2").unwrap()
  assert_eq(o.pass_rounds, o2.pass_rounds)
  assert_eq(o.enable_dce, o2.enable_dce)
  assert_eq(o.enable_dfe, o2.enable_dfe)
}

///|
test "optimize_config_from_opt_level -O4 aliases -O3" {
  let o4 = @types.optimize_config_from_opt_level("-O4").unwrap()
  let o3 = @types.optimize_config_from_opt_level("-O3").unwrap()
  assert_eq(o4.pass_rounds, o3.pass_rounds)
  assert_eq(o4.enable_dce, o3.enable_dce)
  assert_eq(o4.enable_dfe, o3.enable_dfe)
  assert_eq(
    o4.enable_merge_similar_functions,
    o3.enable_merge_similar_functions,
  )
}

///|
test "make_optimize_config uses defaults" {
  let c = @types.make_optimize_config()
  assert_true(c.enable_peephole)
  assert_true(c.strip_name_section)
  assert_true(c.strip_producers_section)
  assert_false(c.enable_dce)
  assert_false(c.enable_experimental_cfp_const_hints)
  assert_false(c.closed_world)
  assert_eq(c.pass_rounds, 1U)
}

///|
test "make_optimize_config overrides" {
  let c = @types.make_optimize_config(
    enable_dce=true,
    closed_world=true,
    closed_world_root_exports=["main"],
    pass_rounds=5U,
  )
  assert_true(c.enable_dce)
  assert_true(c.closed_world)
  assert_eq(c.closed_world_root_exports, ["main"])
  assert_eq(c.pass_rounds, 5U)
}

///|
test "make_runtime_profile_scenario defaults" {
  let s = @types.make_runtime_profile_scenario("run")
  assert_eq(s.export_name, "run")
  assert_eq(s.args, [])
}

///|
test "make_runtime_profile_scenario with args" {
  let s = @types.make_runtime_profile_scenario("compute", args=[1, 2, 3])
  assert_eq(s.export_name, "compute")
  assert_eq(s.args, [1, 2, 3])
}

///|
test "preset ordering: o0 < default < o1 <= o2 <= o3 <= oz by pass_rounds" {
  let o0 = @types.OptimizeConfig::o0()
  let def = @types.OptimizeConfig::default()
  let o1 = @types.OptimizeConfig::o1()
  let o3 = @types.OptimizeConfig::o3()
  let oz = @types.OptimizeConfig::oz()
  assert_true(o0.pass_rounds <= def.pass_rounds)
  assert_true(def.pass_rounds <= o1.pass_rounds)
  assert_true(o1.pass_rounds <= o3.pass_rounds)
  assert_true(o3.pass_rounds <= oz.pass_rounds)
}
