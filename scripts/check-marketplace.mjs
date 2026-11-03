#!/usr/bin/env node
// Consistency check for .claude-plugin/marketplace.json. No dependencies: runs on plain Node (or Bun).
//
//   node scripts/check-marketplace.mjs [path/to/marketplace.json] [path/to/README.md]
//
// Exits 1 and prints one line per problem, naming the plugin and the field.
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const marketplacePath = process.argv[2] ?? path.join(root, ".claude-plugin", "marketplace.json");
const readmePath = process.argv[3] ?? path.join(root, "README.md");

const NAME = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const SEMVER = /^\d+\.\d+\.\d+$/;
const REGISTRY = "https://npm.fazer.ai/";
const SCOPE = "@fazer-ai-pro/";

const problems = [];
const report = (where, msg) => problems.push(`${where}: ${msg}`);
const isObj = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
const nonEmpty = (v) => typeof v === "string" && v.trim() !== "";

function checkDescriptions(where, item) {
  if (!nonEmpty(item.description)) report(where, "`description` is missing or empty");
  if (!isObj(item.descriptions)) {
    report(where, "`descriptions` is missing");
    return;
  }
  for (const lang of ["en", "pt-BR"]) {
    if (!nonEmpty(item.descriptions[lang])) report(where, `\`descriptions.${lang}\` is missing or empty`);
  }
}

function checkSkillList(pluginWhere, key, list) {
  if (list === undefined) return;
  if (!Array.isArray(list)) {
    report(pluginWhere, `\`${key}\` is not an array`);
    return;
  }
  const seen = new Set();
  list.forEach((skill, i) => {
    const where = `${pluginWhere} ${key}[${i}]${isObj(skill) && nonEmpty(skill.name) ? ` (${skill.name})` : ""}`;
    if (!isObj(skill)) {
      report(where, "is not an object");
      return;
    }
    if (!nonEmpty(skill.name)) report(where, "`name` is missing or empty");
    else if (seen.has(skill.name)) report(where, `skill name \`${skill.name}\` repeats inside the plugin`);
    else seen.add(skill.name);
    checkDescriptions(where, skill);
  });
}

function checkPlugin(plugin, i, names, listed) {
  const label = isObj(plugin) && nonEmpty(plugin.name) ? plugin.name : `plugins[${i}]`;
  const where = `plugin ${label}`;
  if (!isObj(plugin)) {
    report(where, "is not an object");
    return;
  }
  if (!nonEmpty(plugin.name)) report(where, "`name` is missing or empty");
  else {
    if (!NAME.test(plugin.name)) report(where, "`name` must be lowercase letters, digits and hyphens");
    if (names.has(plugin.name)) report(where, "`name` is used by more than one plugin");
    names.add(plugin.name);
  }
  checkDescriptions(where, plugin);
  if (typeof plugin.version !== "string" || !SEMVER.test(plugin.version)) {
    report(where, `\`version\` must be X.Y.Z semver (got ${JSON.stringify(plugin.version)})`);
  }
  const src = plugin.source;
  if (isObj(src) && src.source === "npm") {
    if (typeof src.package !== "string" || !src.package.startsWith(SCOPE)) {
      report(where, `\`source.package\` must be a ${SCOPE} package (got ${JSON.stringify(src.package)})`);
    }
    if (src.registry !== REGISTRY) report(where, `\`source.registry\` must be ${REGISTRY} (got ${JSON.stringify(src.registry)})`);
    if (src.version !== plugin.version) {
      report(where, `\`source.version\` (${JSON.stringify(src.version)}) differs from \`version\` (${JSON.stringify(plugin.version)})`);
    }
  } else if (src === undefined) {
    report(where, "`source` is missing");
  }
  if (!nonEmpty(plugin.category)) report(where, "`category` is missing or empty");
  if (!Array.isArray(plugin.tags) || !plugin.tags.every((t) => typeof t === "string")) {
    report(where, "`tags` must be an array of strings");
  }
  if ("skills" in plugin) report(where, "legacy `skills` key: use `available_skills`");
  checkSkillList(where, "available_skills", plugin.available_skills);
  checkSkillList(where, "coming_soon", plugin.coming_soon);
  if (nonEmpty(plugin.name)) listed.push(plugin.name);
}

// The README plugin table: rows shaped like "| `name` | description |".
function readmePlugins(text) {
  const names = new Set();
  for (const line of text.split("\n")) {
    const m = line.match(/^\|\s*`([^`]+)`\s*\|/);
    if (m) names.add(m[1]);
  }
  return names;
}

function main() {
  let raw;
  try {
    raw = readFileSync(marketplacePath, "utf8");
  } catch (e) {
    console.error(`cannot read ${marketplacePath}: ${e.message}`);
    process.exit(1);
  }
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    console.error(`marketplace.json: not valid JSON: ${e.message}`);
    process.exit(1);
  }
  // NOTE: the auto-bump in docs/templates/publish.yml rewrites the file with this exact serialization;
  // any other formatting turns every bump into a whole-file diff.
  if (raw !== `${JSON.stringify(data, null, 2)}\n`) {
    report("marketplace.json", "not serialized as JSON.stringify(data, null, 2) plus a trailing newline");
  }
  if (!isObj(data)) {
    report("marketplace.json", "top level is not an object");
  } else {
    if (!nonEmpty(data.name)) report("marketplace", "`name` is missing or empty");
    if (!isObj(data.owner)) report("marketplace", "`owner` is missing");
    if (!Array.isArray(data.plugins)) report("marketplace", "`plugins` is not an array");
    else {
      const names = new Set();
      const listed = [];
      data.plugins.forEach((p, i) => checkPlugin(p, i, names, listed));
      let readme = null;
      try {
        readme = readFileSync(readmePath, "utf8");
      } catch (e) {
        report("README", `cannot read ${readmePath}: ${e.message}`);
      }
      if (readme !== null) {
        const inTable = readmePlugins(readme);
        for (const name of listed) if (!inTable.has(name)) report(`plugin ${name}`, "missing from the README plugin table");
      }
    }
  }
  if (problems.length) {
    for (const p of problems) console.error(p);
    console.error(`\n${problems.length} problem(s) in ${path.relative(process.cwd(), marketplacePath) || marketplacePath}`);
    process.exit(1);
  }
  console.log(`marketplace.json ok (${data.plugins.length} plugins)`);
}

main();
