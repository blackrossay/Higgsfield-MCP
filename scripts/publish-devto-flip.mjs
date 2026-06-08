#!/usr/bin/env node
/**
 * Flip a dev.to draft to PUBLIC (or back to draft).
 *
 * Usage:
 *   $env:DEVTO_API_KEY = '...'
 *   node scripts/publish-devto-flip.mjs <article_id>           # -> public
 *   node scripts/publish-devto-flip.mjs <article_id> --draft   # -> draft
 *
 * Requires: Node 18+. No npm dependencies.
 */
import { spawnSync } from "node:child_process";

// Re-exec with Windows trust store on first run (Zscaler / corporate proxy fix).
if (!process.env._DEVTO_TLS_FIXED) {
  const r = spawnSync(process.execPath, ["--use-system-ca", ...process.argv.slice(1)], {
    stdio: "inherit",
    env: { ...process.env, _DEVTO_TLS_FIXED: "1", NODE_USE_SYSTEM_CA: "1" },
  });
  process.exit(r.status ?? 1);
}

const apiKey = process.env.DEVTO_API_KEY;
if (!apiKey) {
  console.error("ERROR: DEVTO_API_KEY is not set. Get one at https://dev.to/settings/extensions");
  process.exit(1);
}

const id = process.argv.find((a) => /^\d+$/.test(a));
if (!id) {
  console.error("ERROR: pass the numeric article id, e.g. node scripts/publish-devto-flip.mjs 3847447");
  process.exit(1);
}

const published = !process.argv.includes("--draft");

console.log(`PUT https://dev.to/api/articles/${id}  (published=${published}) ...`);

const res = await fetch(`https://dev.to/api/articles/${id}`, {
  method: "PUT",
  headers: {
    "api-key": apiKey,
    "Content-Type": "application/json",
    "User-Agent": "Higgsfield-MCP-publisher/1.0",
  },
  body: JSON.stringify({ article: { published } }),
});

const text = await res.text();
if (!res.ok) {
  console.error(`\nHTTP ${res.status} ${res.statusText}`);
  console.error(text);
  process.exit(1);
}

const data = JSON.parse(text);
// dev.to's PUT response shape varies; infer publish state from the URL (drafts contain
// "?preview=...") rather than relying on the `published` field which is sometimes absent.
const looksPublic = typeof data.url === "string" && !data.url.includes("preview=");
console.log("");
console.log(`  id:        ${data.id}`);
console.log(`  published: ${data.published ?? looksPublic}`);
console.log(`  url:       ${data.url}`);
console.log(`  reactions: ${data.public_reactions_count ?? 0}`);
console.log("");
console.log(published ? "Live now." : "Reverted to draft.");
