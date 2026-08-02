/**
 * Merge agent-memory hook entries into an existing JSON config.
 * Used by hooks/install-hooks.sh and tests.
 *
 * Args (CLI): source_json target_json out_json mode
 * mode: flat (cursor/copilot — hooks.<event> = array)
 *       nested (claude/codex/gemini — hooks.<event> = [{matcher?, hooks: [...]}])
 */
import fs from "node:fs";

/**
 * Product hook entries invoke our scripts by path/basename, optionally with
 * AGENT_MEMORY_* env prefixes. Do not match mere mentions of the filenames
 * (e.g. docs/agent-memory-sync.sh.example).
 */
export function isOurs(value) {
  const s = typeof value === "string" ? value : JSON.stringify(value);
  return /(?:^|[\s/"'=])(?:[\w./-]*\/)?agent-memory-(?:session|sync|common)\.sh(?:$|[\s"'])/.test(
    s,
  );
}

function asHooksObject(hooks) {
  if (hooks && typeof hooks === "object" && !Array.isArray(hooks)) return hooks;
  return {};
}

/** Nested groups: strip only our command entries; keep sibling custom hooks. */
export function scrubNestedGroup(group) {
  if (!group || typeof group !== "object" || Array.isArray(group)) return null;
  const next = { ...group };
  if (Array.isArray(next.hooks)) {
    next.hooks = next.hooks.filter((entry) => !isOurs(entry));
    if (next.hooks.length === 0) return null;
  } else if (isOurs(group)) {
    return null;
  }
  return next;
}

/** Legacy per-tool events — drop ours on reinstall; keep custom. */
export const REMOVED_PER_TOOL_EVENTS = new Set([
  "postToolUse",
  "afterFileEdit",
  "PostToolUse",
  "AfterTool",
]);

function scrubRemovedPerToolOurs(hooks) {
  for (const event of REMOVED_PER_TOOL_EVENTS) {
    if (!Object.prototype.hasOwnProperty.call(hooks, event)) continue;
    const existing = hooks[event];
    if (!Array.isArray(existing)) {
      delete hooks[event];
      continue;
    }
    const kept = [];
    for (const entry of existing) {
      // Nested groups (Claude/Codex/Gemini) or flat command entries.
      if (entry && typeof entry === "object" && Array.isArray(entry.hooks)) {
        const scrubbed = scrubNestedGroup(entry);
        if (scrubbed) kept.push(scrubbed);
      } else if (!isOurs(entry)) {
        kept.push(entry);
      }
    }
    if (kept.length === 0) delete hooks[event];
    else hooks[event] = kept;
  }
}

export function mergeHooksConfig(src, tgt, mode) {
  const out = { ...tgt };
  if (mode === "flat") {
    if (src.version != null && out.version == null) out.version = src.version;
    out.hooks = asHooksObject(out.hooks);
    scrubRemovedPerToolOurs(out.hooks);
    const srcHooks = src.hooks || {};
    for (const [event, entries] of Object.entries(srcHooks)) {
      const existing = Array.isArray(out.hooks[event]) ? out.hooks[event] : [];
      const kept = existing.filter((e) => !isOurs(e));
      out.hooks[event] = [...kept, ...(Array.isArray(entries) ? entries : [])];
    }
  } else if (mode === "nested") {
    out.hooks = asHooksObject(out.hooks);
    scrubRemovedPerToolOurs(out.hooks);
    const srcHooks = src.hooks || {};
    for (const [event, groups] of Object.entries(srcHooks)) {
      const existing = Array.isArray(out.hooks[event]) ? out.hooks[event] : [];
      const kept = [];
      for (const group of existing) {
        const scrubbed = scrubNestedGroup(group);
        if (scrubbed) kept.push(scrubbed);
      }
      out.hooks[event] = [...kept, ...(Array.isArray(groups) ? groups : [])];
    }
  } else {
    throw new Error(`unknown merge mode: ${mode}`);
  }
  return out;
}

function main(argv) {
  const [sourcePath, targetPath, outPath, mode] = argv.slice(2);
  if (!sourcePath || !targetPath || !outPath || !mode) {
    console.error(
      "usage: merge-hooks.mjs <source.json> <target.json> <out.json> <flat|nested>",
    );
    process.exit(1);
  }
  const src = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
  let tgt = {};
  if (fs.existsSync(targetPath)) {
    tgt = JSON.parse(fs.readFileSync(targetPath, "utf8"));
  }
  const merged = mergeHooksConfig(src, tgt, mode);
  fs.writeFileSync(outPath, `${JSON.stringify(merged, null, 2)}\n`);
}

const isDirect =
  typeof process !== "undefined" &&
  process.argv[1] &&
  /merge-hooks\.mjs$/.test(process.argv[1].replace(/\\/g, "/"));

if (isDirect) {
  main(process.argv);
}
