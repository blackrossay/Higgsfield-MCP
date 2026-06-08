#!/usr/bin/env node
/**
 * Publish docs/article/anatomy-of-an-ai-token.devto.md to dev.to via the API.
 *
 * Usage:
 *   $env:DEVTO_API_KEY = '...'   (PowerShell)   or   export DEVTO_API_KEY=...   (bash)
 *   node scripts/publish-devto.mjs               # publishes as DRAFT (default, safe)
 *   node scripts/publish-devto.mjs --publish     # publishes PUBLIC immediately
 *
 * Get an API key at: https://dev.to/settings/extensions
 *
 * Requires: Node 18+ (uses global fetch). No npm dependencies.
 */
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// Corporate TLS-inspecting proxies (Zscaler, Netskope, etc.) re-sign certificates with a
// private root CA that lives in the Windows trust store. Node ships its own CA bundle and
// does NOT consult that store unless told to. If we hit the proxy without the right flag,
// fetch() fails with UNABLE_TO_GET_ISSUER_CERT_LOCALLY. Self-heal by re-executing under
// --use-system-ca (Node 22+) on the first run.
if (!process.env._DEVTO_TLS_FIXED) {
  const result = spawnSync(
    process.execPath,
    ["--use-system-ca", ...process.argv.slice(1)],
    {
      stdio: "inherit",
      env: { ...process.env, _DEVTO_TLS_FIXED: "1", NODE_USE_SYSTEM_CA: "1" },
    },
  );
  process.exit(result.status ?? 1);
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const SRC = join(repoRoot, "docs", "article", "anatomy-of-an-ai-token.devto.md");

const apiKey = process.env.DEVTO_API_KEY;
if (!apiKey) {
  console.error("ERROR: DEVTO_API_KEY is not set.");
  console.error("Get one at: https://dev.to/settings/extensions");
  console.error("PowerShell:  $env:DEVTO_API_KEY = '...'");
  console.error("Bash:        export DEVTO_API_KEY='...'");
  process.exit(1);
}

const published = process.argv.includes("--publish");

// Read the file and strip the YAML front-matter (between first two '---' lines).
const raw = readFileSync(SRC, "utf8");
const fmMatch = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
const body = fmMatch ? fmMatch[2] : raw;

const payload = {
  article: {
    title:
      "Anatomy of an AI Token: how I generated a cinematic visualisation of the AI inference pipeline from a locked-down corporate laptop",
    description:
      "An 8-second cinematic shot of a token's journey through fiber, GPUs, and silicon — generated with one CLI command, behind Zscaler, with no admin rights.",
    published,
    main_image:
      "https://raw.githubusercontent.com/blackrossay/Higgsfield-MCP/main/docs/article/anatomy-poster.jpg",
    canonical_url:
      "https://github.com/blackrossay/Higgsfield-MCP/blob/main/docs/article/anatomy-of-an-ai-token.md",
    tags: ["ai", "cli", "devops", "infrastructure"],
    body_markdown: body,
  },
};

console.log(`Posting to https://dev.to/api/articles  (published=${published}) ...`);

const res = await fetch("https://dev.to/api/articles", {
  method: "POST",
  headers: {
    "api-key": apiKey,
    "Content-Type": "application/json",
    "User-Agent": "Higgsfield-MCP-publisher/1.0",
  },
  body: JSON.stringify(payload),
});

const text = await res.text();
if (!res.ok) {
  console.error(`\nHTTP ${res.status} ${res.statusText}`);
  console.error(text);
  process.exit(1);
}

const data = JSON.parse(text);
console.log("");
console.log(`  id:   ${data.id}`);
console.log(`  url:  ${data.url}`);
console.log(`  edit: https://dev.to/${data.user?.username ?? "you"}/${data.slug}/edit`);
console.log("");
if (!published) {
  console.log("Posted as DRAFT. Review at the URL above, then click 'Publish' on dev.to.");
  console.log(`To flip THIS draft to public via API:`);
  console.log(
    `  curl -X PUT "https://dev.to/api/articles/${data.id}" -H "api-key: $DEVTO_API_KEY" -H "Content-Type: application/json" -d '{"article":{"published":true}}'`,
  );
} else {
  console.log("Posted PUBLIC. Live now.");
}
