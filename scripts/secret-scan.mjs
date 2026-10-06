import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const ignored = new Set([".git", ".next", "node_modules", "coverage", "playwright-report", "test-results"]);
const ignoredFiles = new Set([".env", ".env.local", "package-lock.json"]);
const extensions = new Set([".ts", ".tsx", ".js", ".jsx", ".mjs", ".json", ".md", ".yml", ".yaml", ".toml", ".sql"]);

const patterns = [
  /SUPABASE_SERVICE_ROLE_KEY\s*=\s*.+/i,
  /sb_secret_[a-z0-9_-]+/i,
  /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/,
];

function hasAllowedExtension(file) {
  return [...extensions].some((extension) => file.endsWith(extension));
}

function collectFiles(dir) {
  const files = [];

  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (ignored.has(entry.name) || ignoredFiles.has(entry.name)) {
      continue;
    }

    const path = join(dir, entry.name);

    if (entry.isDirectory()) {
      files.push(...collectFiles(path));
    } else if (entry.isFile() && hasAllowedExtension(entry.name)) {
      files.push(path);
    }
  }

  return files;
}

const offenders = collectFiles(process.cwd()).filter((file) => {
  if (!statSync(file).isFile()) return false;
  const text = readFileSync(file, "utf8");
  return patterns.some((pattern) => pattern.test(text));
});

if (offenders.length > 0) {
  console.error(`Potential secrets found:\n${offenders.join("\n")}`);
  process.exit(1);
}
