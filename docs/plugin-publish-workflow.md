# Plugin publish workflow

Reference for wiring a new plugin repo into this marketplace. The pattern
was established for `fazer-ai/fazer-ai-atendimento` and should be mirrored by
every future plugin repo so the central `marketplace.json` in this repo
stays in sync automatically.

## How it works

1. The plugin repo publishes to the private npm registry on release.
2. The same workflow opens a PR against `fazer-ai/skills` that bumps the
   plugin's entry in `.claude-plugin/marketplace.json` to the new
   version.
3. The PR also propagates `description` and `descriptions` from the
   plugin repo's `package.json`, so the copy shown in the fazer.ai hub
   (`/claude-skills`) stays current without manual edits here.

**Rule of thumb:** to change a plugin's description or add a locale,
edit the plugin's own `package.json` and cut a release. Do not hand-edit
this repo's `marketplace.json` for per-plugin metadata, or the next
release PR will overwrite it.

## Localized descriptions convention

npm has no standard field for localized descriptions, so we use
`descriptions: Record<string, string>` alongside the existing
`description`. The hub (`marketplace.service.ts`) resolves the locale as
follows:

1. Exact match (`pt-BR`, `en-US`, ...)
2. Short code (`pt`, `en`, ...)
3. Fallback to `en`
4. Fallback to the singular `description`

### Required shape in the plugin repo's `package.json`

```json
{
  "name": "@fazer-ai-pro/<plugin-name>",
  "version": "x.y.z",
  "description": "English one-liner (also used as npm search blurb).",
  "descriptions": {
    "en": "English one-liner (same as description).",
    "pt-BR": "Versão em português com acentuação correta."
  }
}
```

Add new locales (`es`, `fr`, ...) at any time. The hub routes them
automatically the moment the panel exposes those locales.

### Also populate `.claude-plugin/marketplace.json` in the plugin repo

The plugin repo's own `.claude-plugin/marketplace.json` is consumed when
someone adds the repo directly as a marketplace (useful for testing
unreleased versions). Keep its `descriptions` in sync with
`package.json` so the direct-install path matches what the hub shows.

## Release workflow template

A full, copy-pasteable workflow lives at
[`templates/publish.yml`](templates/publish.yml). Drop it into
`.github/workflows/publish.yml` of the plugin repo.

It assumes the standard fazer.ai layout:

- `package.json`, `.claude-plugin/plugin.json`, and
  `.claude-plugin/marketplace.json` all carry the same version.
- Package scope is `@fazer-ai-pro/` and the registry is
  `https://npm.fazer.ai/`.

Required repo secrets:

- `NPM_REGISTRY_USER`, `NPM_REGISTRY_TOKEN`: publish credentials for
  `npm.fazer.ai`.
- `SKILLS_REPO_PAT`: PAT with push + PR access to `fazer-ai/skills`
  (classic `repo` scope, or fine-grained with **Contents: write** and
  **Pull requests: write**).

Only the final `Open PR in fazer-ai/skills` step is specific to this
propagation flow. The earlier steps (version check, registry auth,
`npm publish`) are standard and can be adapted.

## Checklist for a new plugin repo

1. Add the plugin entry to `.claude-plugin/marketplace.json` in this
   repo (seed `name`, `description`, `descriptions`, `source`,
   `version`, `category`, `tags`).
2. In the plugin repo:
   - `package.json` has `description` and `descriptions` with at least
     `en` and `pt-BR`.
   - `.claude-plugin/marketplace.json` (if present) mirrors them.
   - `.github/workflows/publish.yml` includes the `Open PR in
     fazer-ai/skills` step above.
   - Repo admin adds the `SKILLS_REPO_PAT` secret.
3. Ship a release. Verify the auto-opened PR lands the expected bump
   and description changes, then merge.
