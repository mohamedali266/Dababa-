import { globSync } from "node:fs";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const forbidden = "SUPABASE_SERVICE_ROLE_KEY";
const roots = ["src"];
const offenders = [];

function walk(dir) {
  for (const entry of globSync(`${dir.replaceAll("\\", "/")}/**/*.{ts,tsx,js,jsx}`, { nodir: true })) {
    const text = readFileSync(entry, "utf8");
    const normalized = entry.replaceAll("\\", "/");
    const isServerOnly = normalized.includes("/server.") || normalized.includes("/lib/env.");
    if (text.includes(forbidden) && !isServerOnly) {
      offenders.push(entry);
    }
  }
}

roots.forEach((root) => walk(join(process.cwd(), root)));

if (offenders.length > 0) {
  console.error(`Service role key referenced outside server-only files:\n${offenders.join("\n")}`);
  process.exit(1);
}
