///|
fn split_string(s : String, delim : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split(delim) {
    out.push(part.to_string())
  }
  out
}

///|
fn split_non_empty(s : String, delim : String) -> Array[String] {
  if s.is_empty() {
    return []
  }
  let out : Array[String] = []
  for part in s.split(delim) {
    let item = part.to_string()
    if not(item.is_empty()) {
      out.push(item)
    }
  }
  out
}

///|
fn parse_uint_decimal(text : String) -> UInt? {
  if text.is_empty() {
    return None
  }
  let mut value = 0U
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10U + (code - 48).reinterpret_as_uint()
  }
  Some(value)
}

///|
fn parse_u64_decimal(text : String) -> UInt64? {
  if text.is_empty() {
    return None
  }
  let mut value = 0UL
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10UL + (code - 48).to_uint64()
  }
  Some(value)
}

///|
fn compare_runtime_unresolved_export(
  a : RuntimeUnresolvedExport,
  b : RuntimeUnresolvedExport,
) -> Int {
  let by_name = a.export_name.compare(b.export_name)
  if by_name != 0 {
    by_name
  } else {
    let by_reason = a.reason.compare(b.reason)
    if by_reason != 0 {
      by_reason
    } else {
      a.detail.compare(b.detail)
    }
  }
}

///|
fn parse_runtime_unresolved_exports(
  serialized : String,
) -> Array[RuntimeUnresolvedExport] {
  let out : Array[RuntimeUnresolvedExport] = []
  for entry in split_non_empty(serialized, ";;") {
    let fields = split_string(entry, "\t")
    if fields.length() == 0 {
      continue
    }
    let export_name = fields[0]
    let reason = if fields.length() >= 2 { fields[1] } else { "unknown" }
    let detail = if fields.length() >= 3 { fields[2] } else { "" }
    out.push({ export_name, reason, detail })
  }
  out.sort_by(compare_runtime_unresolved_export)
  out
}

///|
fn serialize_runtime_profile_scenarios(
  scenarios : Array[RuntimeProfileScenario],
) -> String {
  if scenarios.length() == 0 {
    return ""
  }
  let entries : Array[String] = []
  for scenario in scenarios {
    let args_text = if scenario.args.length() == 0 {
      ""
    } else {
      scenario.args.map(v => v.to_string()).join(",")
    }
    entries.push(scenario.export_name + "\t" + args_text)
  }
  entries.join(";;")
}

///|
extern "js" fn js_profile_runtime_exports(
  bytes : Bytes,
  iterations : Int,
  scenario_spec : String,
) -> String =
  #| (bytes, iterations, scenarioSpec) => {
  #|   try {
  #|     const raw = bytes instanceof Uint8Array
  #|       ? bytes
  #|       : (Array.isArray(bytes) ? Uint8Array.from(bytes) : new Uint8Array(bytes));
  #|     const rounds = Math.max(1, iterations | 0);
  #|     const sanitize = (value) => String(value)
  #|       .replace(/\|/g, '/')
  #|       .replace(/\t/g, ' ')
  #|       .replace(/\r?\n/g, ' ')
  #|       .replace(/;;/g, ';');
  #|     const encodeUnresolved = (name, reason, detail) =>
  #|       sanitize(name) + '\t' + sanitize(reason) + '\t' + sanitize(detail);
  #|     const encodeProfile = (name, calls, totalNs) =>
  #|       sanitize(name) + ',' + String(calls) + ',' + String(totalNs);
  #|     const parseScenarioSpec = (rawSpec) => {
  #|       const out = { hasSpec: false, scenarios: [], invalid: [] };
  #|       if (!rawSpec || rawSpec.length === 0) return out;
  #|       out.hasSpec = true;
  #|       for (const rawEntry of rawSpec.split(';;')) {
  #|         if (!rawEntry) continue;
  #|         const fields = rawEntry.split('\t');
  #|         const exportName = (fields[0] || '').trim();
  #|         const argsField = fields.length >= 2 ? (fields[1] || '').trim() : '';
  #|         if (!exportName) continue;
  #|         const args = [];
  #|         let valid = true;
  #|         if (argsField.length > 0) {
  #|           for (const rawArg of argsField.split(',')) {
  #|             const arg = rawArg.trim();
  #|             if (!arg) continue;
  #|             if (!/^[-]?\d+$/.test(arg)) {
  #|               valid = false;
  #|               break;
  #|             }
  #|             args.push(Number(arg));
  #|           }
  #|         }
  #|         const displayName = argsField.length === 0
  #|           ? exportName
  #|           : exportName + '(' + argsField.replace(/,/g, '_') + ')';
  #|         if (!valid) {
  #|           out.invalid.push({
  #|             displayName,
  #|             detail: 'invalid-integer-arg',
  #|           });
  #|           continue;
  #|         }
  #|         out.scenarios.push({
  #|           exportName,
  #|           args,
  #|           displayName: args.length === 0
  #|             ? exportName
  #|             : exportName + '(' + args.join('_') + ')',
  #|         });
  #|       }
  #|       return out;
  #|     };
  #|     const scenario = parseScenarioSpec(scenarioSpec);
  #|     const module = new WebAssembly.Module(raw);
  #|     const exportNames = WebAssembly.Module.exports(module)
  #|       .filter((item) => item.kind === 'function')
  #|       .map((item) => item.name);
  #|     const importDescs = WebAssembly.Module.imports(module);
  #|     const imports = {};
  #|     const ensureBucket = (name) => {
  #|       if (!imports[name]) imports[name] = {};
  #|       return imports[name];
  #|     };
  #|     let envMemory = null;
  #|     let sbrkPtr = 1024;
  #|     const ensureSbrk = () => {
  #|       if (!envMemory) return;
  #|       if (envMemory.buffer.byteLength < sbrkPtr + 4) return;
  #|       new DataView(envMemory.buffer).setInt32(sbrkPtr, 8192, true);
  #|     };
  #|     for (const imp of importDescs) {
  #|       const bucket = ensureBucket(imp.module);
  #|       if (imp.kind === 'memory') {
  #|         const fallbackMin = (imp.module === 'env' && imp.name === 'memory') ? 256 : 1;
  #|         const minimum = Math.max(1, Number(imp.minimum ?? fallbackMin));
  #|         const maximum = imp.maximum == null ? minimum : Math.max(minimum, Number(imp.maximum));
  #|         const memory = new WebAssembly.Memory({ initial: minimum, maximum });
  #|         bucket[imp.name] = memory;
  #|         if (imp.module === 'env' && imp.name === 'memory') {
  #|           envMemory = memory;
  #|         }
  #|       } else if (imp.kind === 'table') {
  #|         const fallbackMin = (imp.module === 'env' && imp.name === '__indirect_function_table') ? 32 : 1;
  #|         const minimum = Math.max(1, Number(imp.minimum ?? fallbackMin));
  #|         const tableInit = {
  #|           element: imp.element ?? 'anyfunc',
  #|           initial: minimum,
  #|         };
  #|         if (imp.maximum != null) {
  #|           tableInit.maximum = Math.max(minimum, Number(imp.maximum));
  #|         }
  #|         bucket[imp.name] = new WebAssembly.Table(tableInit);
  #|       } else if (imp.kind === 'global') {
  #|         const value = imp.value ?? 'i32';
  #|         const mutable = !!imp.mutable;
  #|         const init = value === 'i64' ? 0n : 0;
  #|         bucket[imp.name] = new WebAssembly.Global({ value, mutable }, init);
  #|       }
  #|     }
  #|     if (!envMemory) {
  #|       envMemory = new WebAssembly.Memory({ initial: 256, maximum: 256 });
  #|       ensureBucket('env').memory = envMemory;
  #|     }
  #|     ensureSbrk();
  #|     for (const imp of importDescs) {
  #|       if (imp.kind !== 'function') continue;
  #|       const bucket = ensureBucket(imp.module);
  #|       if (typeof bucket[imp.name] === 'function') continue;
  #|       const key = imp.module + '.' + imp.name;
  #|       if (key === 'env.abort') {
  #|         bucket[imp.name] = () => { throw new Error('abort'); };
  #|       } else if (key === 'env.exit') {
  #|         bucket[imp.name] = (code) => code | 0;
  #|       } else if (key === 'env.emscripten_get_sbrk_ptr') {
  #|         bucket[imp.name] = () => sbrkPtr;
  #|       } else if (key === 'env.emscripten_resize_heap') {
  #|         bucket[imp.name] = () => 0;
  #|       } else if (key === 'env.emscripten_memcpy_big') {
  #|         bucket[imp.name] = (dst, src, num) => {
  #|           if (envMemory) {
  #|             const view = new Uint8Array(envMemory.buffer);
  #|             view.copyWithin(dst >>> 0, src >>> 0, (src + num) >>> 0);
  #|           }
  #|           return dst | 0;
  #|         };
  #|       } else if (imp.module === 'wasi_snapshot_preview1') {
  #|         bucket[imp.name] = () => 0;
  #|       } else {
  #|         bucket[imp.name] = () => 0;
  #|       }
  #|     }
  #|     let instantiateNs = '0';
  #|     let instance = null;
  #|     try {
  #|       const t0 = process.hrtime.bigint();
  #|       instance = new WebAssembly.Instance(module, imports);
  #|       const t1 = process.hrtime.bigint();
  #|       instantiateNs = (t1 - t0).toString();
  #|     } catch (e) {
  #|       const msg = e && e.message ? e.message : String(e);
  #|       const unresolved = [];
  #|       for (const invalid of scenario.invalid) {
  #|         unresolved.push(
  #|           encodeUnresolved(
  #|             invalid.displayName,
  #|             'invalid-scenario',
  #|             invalid.detail,
  #|           ),
  #|         );
  #|       }
  #|       const targets = scenario.hasSpec
  #|         ? scenario.scenarios.map((item) => item.displayName)
  #|         : exportNames;
  #|       for (const name of targets) {
  #|         unresolved.push(encodeUnresolved(name, 'import-missing', msg));
  #|       }
  #|       return 'ok|' + instantiateNs + '|||' + unresolved.join(';;');
  #|     }
  #|     const profiled = [];
  #|     const skipped = [];
  #|     const unresolved = scenario.invalid.map((invalid) =>
  #|       encodeUnresolved(
  #|         invalid.displayName,
  #|         'invalid-scenario',
  #|         invalid.detail,
  #|       )
  #|     );
  #|     if (scenario.hasSpec) {
  #|       for (const item of scenario.scenarios) {
  #|         const value = instance.exports[item.exportName];
  #|         if (typeof value !== 'function') {
  #|           unresolved.push(
  #|             encodeUnresolved(
  #|               item.displayName,
  #|               'export-not-found',
  #|               item.exportName,
  #|             ),
  #|           );
  #|           continue;
  #|         }
  #|         if (value.length !== item.args.length) {
  #|           unresolved.push(
  #|             encodeUnresolved(
  #|               item.displayName,
  #|               'signature-mismatch',
  #|               'arity=' + value.length + ' args=' + item.args.length,
  #|             ),
  #|           );
  #|           continue;
  #|         }
  #|         let total = 0n;
  #|         let failed = null;
  #|         for (let i = 0; i < rounds; i++) {
  #|           try {
  #|             const s = process.hrtime.bigint();
  #|             value(...item.args);
  #|             total += (process.hrtime.bigint() - s);
  #|           } catch (e) {
  #|             failed = e;
  #|             break;
  #|           }
  #|         }
  #|         if (failed) {
  #|           const msg = failed && failed.message ? failed.message : String(failed);
  #|           unresolved.push(
  #|             encodeUnresolved(item.displayName, 'runtime-exception', msg),
  #|           );
  #|           continue;
  #|         }
  #|         profiled.push(encodeProfile(item.displayName, rounds, total.toString()));
  #|       }
  #|     } else {
  #|       for (const [name, value] of Object.entries(instance.exports)) {
  #|         if (typeof value !== 'function') continue;
  #|         if (value.length !== 0) {
  #|           skipped.push(name);
  #|           unresolved.push(
  #|             encodeUnresolved(name, 'signature-mismatch', 'arity=' + value.length)
  #|           );
  #|           continue;
  #|         }
  #|         let total = 0n;
  #|         let failed = null;
  #|         for (let i = 0; i < rounds; i++) {
  #|           try {
  #|             const s = process.hrtime.bigint();
  #|             value();
  #|             total += (process.hrtime.bigint() - s);
  #|           } catch (e) {
  #|             failed = e;
  #|             break;
  #|           }
  #|         }
  #|         if (failed) {
  #|           const msg = failed && failed.message ? failed.message : String(failed);
  #|           unresolved.push(
  #|             encodeUnresolved(name, 'runtime-exception', msg)
  #|           );
  #|           continue;
  #|         }
  #|         profiled.push(encodeProfile(name, rounds, total.toString()));
  #|       }
  #|     }
  #|     return 'ok|' + instantiateNs + '|' + profiled.join(';;') + '|' + skipped.join(',') + '|' + unresolved.join(';;');
  #|   } catch (e) {
  #|     const msg = e && e.message ? e.message : String(e);
  #|     return 'err|' + msg;
  #|   }
  #| }

///|
pub fn profile_runtime_exports(
  bytes : Bytes,
  iterations? : UInt = 50U,
  scenarios? : Array[RuntimeProfileScenario] = [],
) -> Result[RuntimeProfile, String] {
  let raw = js_profile_runtime_exports(
    bytes,
    UInt::reinterpret_as_int(iterations),
    serialize_runtime_profile_scenarios(scenarios),
  )
  let parts = split_string(raw, "|")
  if parts.length() < 2 {
    return Err("invalid runtime profile response")
  }
  if parts[0] == "err" {
    return Err("runtime profile failed: " + parts[1])
  }
  if parts[0] != "ok" {
    return Err("unknown runtime profile status: " + parts[0])
  }
  if parts.length() < 3 {
    return Err("runtime profile response is missing fields")
  }
  let instantiate_ns = match parse_u64_decimal(parts[1]) {
    Some(v) => v
    None => return Err("failed to parse instantiate time: " + parts[1])
  }
  let functions : Array[RuntimeFunctionProfile] = []
  let profile_entries = if parts.length() >= 3 { parts[2] } else { "" }
  for entry in split_non_empty(profile_entries, ";;") {
    let fields = split_string(entry, ",")
    if fields.length() != 3 {
      return Err("invalid function profile entry: " + entry)
    }
    let calls = match parse_uint_decimal(fields[1]) {
      Some(v) => v
      None => return Err("invalid call count in profile entry: " + entry)
    }
    let total_ns = match parse_u64_decimal(fields[2]) {
      Some(v) => v
      None => return Err("invalid total ns in profile entry: " + entry)
    }
    let average_ns = if calls == 0U {
      0UL
    } else {
      total_ns / calls.to_uint64()
    }
    functions.push({ name: fields[0], calls, total_ns, average_ns })
  }
  let skipped_exports = if parts.length() >= 4 {
    split_non_empty(parts[3], ",")
  } else {
    []
  }
  let unresolved_exports = if parts.length() >= 5 {
    parse_runtime_unresolved_exports(parts[4])
  } else {
    []
  }
  Ok({
    instantiate_ns,
    iterations,
    functions,
    skipped_exports,
    unresolved_exports,
  })
}

///|
pub fn profile_runtime_zero_arg_exports(
  bytes : Bytes,
  iterations? : UInt = 50U,
) -> Result[RuntimeProfile, String] {
  profile_runtime_exports(bytes, iterations~)
}
