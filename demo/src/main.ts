import { add, memory } from "./add.wasm";

// --- Demo state ---
const output = document.getElementById("output")!;
const wasmResult = document.getElementById("wasm-result")!;
const dropZone = document.getElementById("drop-zone")!;
const fileInput = document.getElementById("file-input") as HTMLInputElement;
const analyzeOutput = document.getElementById("analyze-output")!;

// --- Run wasm demo ---
function runWasmDemo() {
  const a = 40, b = 2;
  const result = add(a, b);
  wasmResult.textContent = `add(${a}, ${b}) = ${result}`;

  // Show memory info
  const memInfo = document.getElementById("mem-info")!;
  memInfo.textContent = `Memory: ${memory.buffer.byteLength} bytes (${memory.buffer.byteLength / 65536} pages)`;
}

runWasmDemo();

// --- Wasm analyzer (client-side) ---
async function analyzeWasm(bytes: Uint8Array) {
  const view = new DataView(bytes.buffer);
  const magic = bytes.slice(0, 4);
  const isWasm = magic[0] === 0x00 && magic[1] === 0x61 && magic[2] === 0x73 && magic[3] === 0x6d;

  if (!isWasm) {
    return "Error: Not a valid WebAssembly binary";
  }

  const version = view.getUint32(4, true);
  const isComponent = version === 0x0001000d;

  const lines: string[] = [];
  lines.push(`File size: ${bytes.length.toLocaleString()} bytes`);
  lines.push(`Type: ${isComponent ? "Component Model" : "Core Module"}`);
  lines.push(`Version: ${isComponent ? "component" : "1"}`);
  lines.push("");

  if (!isComponent) {
    // Parse sections
    let offset = 8;
    const sections: { id: number; name: string; start: number; size: number; customName?: string }[] = [];
    const sectionNames: Record<number, string> = {
      0: "Custom", 1: "Type", 2: "Import", 3: "Function",
      4: "Table", 5: "Memory", 6: "Global", 7: "Export",
      8: "Start", 9: "Element", 10: "Code", 11: "Data", 12: "DataCount",
    };

    while (offset < bytes.length) {
      const id = bytes[offset];
      offset++;
      let size = 0;
      let shift = 0;
      while (offset < bytes.length) {
        const b = bytes[offset++];
        size |= (b & 0x7f) << shift;
        if (!(b & 0x80)) break;
        shift += 7;
      }
      let customName: string | undefined;
      if (id === 0) {
        // Read custom section name
        let nameLen = 0;
        let nShift = 0;
        const nameStart = offset;
        while (offset < bytes.length) {
          const b = bytes[nameStart + nShift];
          nameLen |= (b & 0x7f) << (nShift * 7);
          nShift++;
          if (!(b & 0x80)) break;
        }
        customName = new TextDecoder().decode(bytes.slice(nameStart + nShift, nameStart + nShift + nameLen));
      }
      sections.push({
        id,
        name: sectionNames[id] ?? `Unknown(${id})`,
        start: offset,
        size,
        customName,
      });
      offset += size;
    }

    lines.push("Sections:");
    lines.push("  ID  Name             Size");
    lines.push("  " + "─".repeat(40));
    for (const s of sections) {
      const extra = s.customName ? ` "${s.customName}"` : "";
      lines.push(`  ${String(s.id).padEnd(4)}${(s.name + extra).padEnd(20)}${s.size.toLocaleString().padStart(10)} bytes`);
    }
    lines.push("");

    // Try to instantiate and list exports
    try {
      const module = new WebAssembly.Module(bytes);
      const exports = WebAssembly.Module.exports(module);
      const imports = WebAssembly.Module.imports(module);

      if (imports.length > 0) {
        lines.push(`Imports (${imports.length}):`);
        for (const imp of imports) {
          lines.push(`  ${imp.module}.${imp.name} [${imp.kind}]`);
        }
        lines.push("");
      }

      lines.push(`Exports (${exports.length}):`);
      for (const exp of exports) {
        lines.push(`  ${exp.name} [${exp.kind}]`);
      }
    } catch (e) {
      lines.push(`(Could not compile module: ${e})`);
    }
  } else {
    lines.push("Component Model binary detected.");
    lines.push("Use 'wite dump' CLI for detailed inspection.");
  }

  return lines.join("\n");
}

// --- Drag & drop ---
dropZone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropZone.classList.add("dragover");
});

dropZone.addEventListener("dragleave", () => {
  dropZone.classList.remove("dragover");
});

dropZone.addEventListener("drop", async (e) => {
  e.preventDefault();
  dropZone.classList.remove("dragover");
  const file = e.dataTransfer?.files[0];
  if (file) await handleFile(file);
});

fileInput.addEventListener("change", async () => {
  const file = fileInput.files?.[0];
  if (file) await handleFile(file);
});

async function handleFile(file: File) {
  analyzeOutput.textContent = "Analyzing...";
  const bytes = new Uint8Array(await file.arrayBuffer());
  const result = await analyzeWasm(bytes);
  analyzeOutput.textContent = `${file.name}\n${"─".repeat(40)}\n${result}`;
}
