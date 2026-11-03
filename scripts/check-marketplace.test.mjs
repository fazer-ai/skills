// Tests for check-marketplace.mjs: each one plants a single defect in a copy of the real
// marketplace.json and expects the checker to fail naming the plugin and the field.
//
//   node --test 'scripts/*.test.mjs'
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CHECK = path.join(root, "scripts", "check-marketplace.mjs");
const realMarketplace = readFileSync(path.join(root, ".claude-plugin", "marketplace.json"), "utf8");
const realReadme = readFileSync(path.join(root, "README.md"), "utf8");
const dir = mkdtempSync(path.join(tmpdir(), "check-marketplace-"));
after(() => rmSync(dir, { recursive: true, force: true }));

let n = 0;
function run({ marketplace = realMarketplace, readme = realReadme } = {}) {
  n++;
  const m = path.join(dir, `m${n}.json`);
  const r = path.join(dir, `r${n}.md`);
  writeFileSync(m, marketplace);
  writeFileSync(r, readme);
  const res = spawnSync(process.execPath, [CHECK, m, r], { encoding: "utf8" });
  return { code: res.status, err: res.stderr };
}
const serialize = (d) => `${JSON.stringify(d, null, 2)}\n`;
// a copy of the real file with one change applied to the first npm-sourced plugin
function planted(mutate) {
  const d = JSON.parse(realMarketplace);
  const p = d.plugins.find((x) => x.source?.source === "npm");
  mutate(p, d);
  return { marketplace: serialize(d), name: p.name };
}
function expectProblem(res, ...parts) {
  assert.equal(res.code, 1, `expected exit 1, got ${res.code}: ${res.err}`);
  const line = res.err.split("\n").find((l) => parts.every((s) => l.includes(s)));
  assert.ok(line, `no line with ${JSON.stringify(parts)} in:\n${res.err}`);
}

test("the real file passes", () => {
  const res = run();
  assert.equal(res.code, 0, res.err);
});

test("invalid JSON and a different serialization fail", () => {
  expectProblem(run({ marketplace: `${realMarketplace.trimEnd()},\n` }), "not valid JSON");
  expectProblem(run({ marketplace: `${JSON.stringify(JSON.parse(realMarketplace), null, 4)}\n` }), "JSON.stringify");
  expectProblem(run({ marketplace: realMarketplace.trimEnd() }), "trailing newline");
});

test("source.version that drifts from version names the plugin", () => {
  const { marketplace, name } = planted((p) => {
    p.source.version = "9.9.9";
  });
  expectProblem(run({ marketplace }), `plugin ${name}`, "source.version");
});

test("npm source outside the private scope or registry fails", () => {
  let x = planted((p) => {
    p.source.package = "fazer-ai-solto";
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "source.package");
  x = planted((p) => {
    p.source.registry = "https://registry.npmjs.org/";
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "source.registry");
});

test("a source that is not an npm object fails", () => {
  for (const bad of [null, {}, { source: "nmp", package: "@fazer-ai-pro/x" }, { source: "github", repo: "fazer-ai/x" }]) {
    const { marketplace, name } = planted((p) => {
      p.source = bad;
    });
    expectProblem(run({ marketplace }), `plugin ${name}`, "source");
  }
  // a github source that would pass every npm field check is still refused for its kind
  const gh = planted((p) => {
    p.source = { ...p.source, source: "github" };
  });
  expectProblem(run({ marketplace: gh.marketplace }), `plugin ${gh.name}`, "`source.source` must be \"npm\"");
  const { marketplace, name } = planted((p) => {
    delete p.source;
  });
  expectProblem(run({ marketplace }), `plugin ${name}`, "`source` must be an object");
});

test("version that is not X.Y.Z fails", () => {
  const { marketplace, name } = planted((p) => {
    p.version = "1.2";
    p.source.version = "1.2";
  });
  expectProblem(run({ marketplace }), `plugin ${name}`, "`version`");
});

test("missing translation fails, for the plugin and for a skill", () => {
  let x = planted((p) => {
    delete p.descriptions["pt-BR"];
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "descriptions.pt-BR");
  x = planted((p) => {
    p.available_skills = [{ name: "s", description: "d", descriptions: { "pt-BR": "d" } }];
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name} available_skills[0] (s)`, "descriptions.en");
});

test("duplicate plugin name and malformed name fail", () => {
  const d = JSON.parse(realMarketplace);
  d.plugins.push(structuredClone(d.plugins[0]));
  expectProblem(run({ marketplace: serialize(d) }), `plugin ${d.plugins[0].name}`, "more than one plugin");
  const x = planted((p) => {
    p.name = "Fazer_AI";
  });
  expectProblem(run({ marketplace: x.marketplace }), "plugin Fazer_AI", "lowercase");
});

test("a skill repeated inside a plugin fails, in coming_soon too", () => {
  const skill = { name: "dup", description: "d", descriptions: { en: "d", "pt-BR": "d" } };
  const { marketplace, name } = planted((p) => {
    p.coming_soon = [skill, structuredClone(skill)];
  });
  expectProblem(run({ marketplace }), `plugin ${name} coming_soon[1] (dup)`, "repeats");
});

test("legacy skills key, missing category and non-string tags fail", () => {
  let x = planted((p) => {
    p.skills = [];
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "legacy `skills`");
  x = planted((p) => {
    delete p.category;
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "category");
  x = planted((p) => {
    p.tags = ["ok", 3];
  });
  expectProblem(run({ marketplace: x.marketplace }), `plugin ${x.name}`, "tags");
});

test("missing top-level fields fail", () => {
  const d = JSON.parse(realMarketplace);
  delete d.owner;
  expectProblem(run({ marketplace: serialize(d) }), "marketplace", "owner");
});

test("a plugin missing from the README table fails", () => {
  const d = JSON.parse(realMarketplace);
  const name = d.plugins[0].name;
  const readme = realReadme
    .split("\n")
    .filter((l) => !l.startsWith(`| \`${name}\``))
    .join("\n");
  expectProblem(run({ readme }), `plugin ${name}`, "README");
});
