import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { resolve, dirname, basename } from "node:path";

let jcoAvailable: boolean | undefined;

/**
 * Check if jco CLI is available.
 */
export function isJcoAvailable(): boolean {
  if (jcoAvailable !== undefined) return jcoAvailable;
  try {
    execFileSync("npx", ["jco", "--version"], {
      stdio: "pipe",
      timeout: 10000,
    });
    jcoAvailable = true;
  } catch {
    jcoAvailable = false;
  }
  return jcoAvailable;
}

/**
 * Transpile a Component Model wasm to ESM using jco.
 * Returns the generated JS code, or null if jco is not available.
 */
export function jcoTranspile(
  wasmPath: string,
  outDir?: string,
): { js: string; files: string[] } | null {
  if (!isJcoAvailable()) return null;

  const targetDir = outDir ?? resolve(dirname(wasmPath), ".wite-jco");
  if (!existsSync(targetDir)) {
    mkdirSync(targetDir, { recursive: true });
  }

  try {
    execFileSync(
      "npx",
      [
        "jco",
        "transpile",
        wasmPath,
        "-o",
        targetDir,
        "--no-typescript",
        "--map",
        "*=*",
      ],
      { stdio: "pipe", timeout: 30000 },
    );
  } catch (e: any) {
    const stderr = e?.stderr?.toString() ?? "";
    console.warn(`[vite-plugin-wite] jco transpile failed: ${stderr}`);
    return null;
  }

  // Read the generated JS entry
  const name = basename(wasmPath, ".wasm");
  const jsPath = resolve(targetDir, name + ".js");
  if (!existsSync(jsPath)) {
    // Try to find any .js file
    const files = readdirSync(targetDir).filter((f) => f.endsWith(".js"));
    if (files.length === 0) return null;
    const mainJs = readFileSync(resolve(targetDir, files[0]), "utf-8");
    return { js: mainJs, files };
  }

  const js = readFileSync(jsPath, "utf-8");
  const files = readdirSync(targetDir);
  return { js, files };
}
