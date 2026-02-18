///|
test "generate_worker_entry_mjs contains import and fetch handler" {
  let result = generate_worker_entry_mjs("../build/main.js")
  assert_true(result.contains("import './../build/main.js'"))
  assert_true(result.contains("globalThis.__wite_fetch_handler"))
  assert_true(result.contains("export default"))
  assert_true(result.contains("async fetch(request"))
}

///|
test "generate_worker_entry_mjs passes env to handler" {
  let result = generate_worker_entry_mjs("main.js")
  assert_true(result.contains("__wite_fetch_handler(request, env, ctx)"))
}

///|
test "generate_wrangler_toml produces valid toml" {
  let result = generate_wrangler_toml("my-worker", "worker-entry.mjs")
  assert_true(result.contains("name = \"my-worker\""))
  assert_true(result.contains("main = \"worker-entry.mjs\""))
  assert_true(result.contains("compatibility_date"))
}

///|
test "generate_wrangler_toml without bindings has no binding sections" {
  let result = generate_wrangler_toml("test", "entry.mjs")
  assert_true(!result.contains("[[kv_namespaces]]"))
  assert_true(!result.contains("[[r2_buckets]]"))
  assert_true(!result.contains("[[d1_databases]]"))
}

///|
test "generate_wrangler_toml with kv binding" {
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [{ binding: "MY_KV", id: "kv-id-123" }],
    r2_buckets: [],
    d1_databases: [],
  }
  let result = generate_wrangler_toml("test", "entry.mjs", bindings~)
  assert_true(result.contains("[[kv_namespaces]]"))
  assert_true(result.contains("binding = \"MY_KV\""))
  assert_true(result.contains("id = \"kv-id-123\""))
}

///|
test "generate_wrangler_toml with r2 binding" {
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [],
    r2_buckets: [{ binding: "MY_R2", bucket_name: "my-bucket" }],
    d1_databases: [],
  }
  let result = generate_wrangler_toml("test", "entry.mjs", bindings~)
  assert_true(result.contains("[[r2_buckets]]"))
  assert_true(result.contains("binding = \"MY_R2\""))
  assert_true(result.contains("bucket_name = \"my-bucket\""))
}

///|
test "generate_wrangler_toml with d1 binding" {
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [],
    r2_buckets: [],
    d1_databases: [
      {
        binding: "MY_DB",
        database_name: "my-database",
        database_id: "db-id-456",
      },
    ],
  }
  let result = generate_wrangler_toml("test", "entry.mjs", bindings~)
  assert_true(result.contains("[[d1_databases]]"))
  assert_true(result.contains("binding = \"MY_DB\""))
  assert_true(result.contains("database_name = \"my-database\""))
  assert_true(result.contains("database_id = \"db-id-456\""))
}

///|
test "generate_wrangler_toml with all binding types" {
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [{ binding: "KV1", id: "kv-1" }],
    r2_buckets: [{ binding: "R2", bucket_name: "bucket-1" }],
    d1_databases: [
      { binding: "DB", database_name: "db-1", database_id: "did-1" },
    ],
  }
  let result = generate_wrangler_toml("test", "entry.mjs", bindings~)
  assert_true(result.contains("[[kv_namespaces]]"))
  assert_true(result.contains("[[r2_buckets]]"))
  assert_true(result.contains("[[d1_databases]]"))
}

///|
test "generate_wrangler_toml with multiple kv bindings" {
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [
      { binding: "KV1", id: "id-1" },
      { binding: "KV2", id: "id-2" },
    ],
    r2_buckets: [],
    d1_databases: [],
  }
  let result = generate_wrangler_toml("test", "entry.mjs", bindings~)
  assert_true(result.contains("binding = \"KV1\""))
  assert_true(result.contains("id = \"id-1\""))
  assert_true(result.contains("binding = \"KV2\""))
  assert_true(result.contains("id = \"id-2\""))
}
