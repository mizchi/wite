///|
priv struct DceApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct DfeApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct CfpApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct CfpConstApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct SignatureRefineApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct DuplicateImportElimApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_function_import_count : UInt
  removed_table_import_count : UInt
  removed_memory_import_count : UInt
  removed_global_import_count : UInt
  dropped_name_section : Bool
}

///|
priv struct MsfApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct RumeApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_table_count : UInt
  removed_memory_count : UInt
  removed_global_count : UInt
  removed_element_count : UInt
  removed_data_count : UInt
  removed_export_count : UInt
}

///|
priv struct TypeRefineApplyResult {
  bytes : Bytes
  refined_type_count : UInt
}

///|
priv struct RemoveUnusedTypesApplyResult {
  bytes : Bytes
  removed_type_count : UInt
}

///|
priv struct SignaturePruneApplyResult {
  bytes : Bytes
  pruned_function_count : UInt
  pruned_param_count : UInt
}

