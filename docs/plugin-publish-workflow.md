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

## Roadmap / "Em breve" — `coming_soon` field

Plugins that host multiple skills can advertise upcoming ones via a
`coming_soon` array in their own `.claude-plugin/marketplace.json` (the
plugin repo, not the central marketplace in `fazer-ai/skills`).
Anthropic's plugin parser ignores unknown fields, so this is forward-
compatible. The hub (`app.fazer.ai/#/claude-skills`) reads it and renders
a separate "Em breve" section per plugin.

### Entry shape

```ts
type ComingSoonEntry = {
  name: string;                                // slash-command-style slug
  description: string;                         // fallback / English baseline
  descriptions?: Record<string, string>;       // per-locale, same resolution as plugin-level descriptions
  category?: string;                           // free string; may differ from the plugin's category
  tags?: string[];                             // skill-specific tags (more granular than plugin tags)
};
```

### Rules

- **No ETA.** Order of the array communicates priority/release order.
  Skipping ETAs avoids promising dates the team has not committed to.
- **`name` and `description` required, everything else optional.** The
  hub falls back to `description` when no locale matches (same logic as
  plugin-level `descriptions`).
- **Granular `category` and `tags`.** A plugin classified as `devops`
  can have a coming-soon skill classified as `security` or `monitoring`.
  The hub uses these for filtering inside the plugin page.
- **Lives only in the plugin repo's `marketplace.json`.** Do not
  duplicate `coming_soon` into the central `fazer-ai/skills` marketplace.
  The auto-bump PR step in `templates/publish.yml` only propagates
  `description` and `descriptions`. The hub fetches each plugin repo's
  `marketplace.json` directly to render the roadmap.
- **Move out, don't archive.** When a coming-soon skill ships, remove
  its entry from `coming_soon` and add the real skill folder under
  `skills/<name>/`. Bump the plugin minor version on release.

### Example

```json
{
  "plugins": [
    {
      "name": "fazer-ai-vps",
      "source": "./",
      "version": "1.0.0",
      "description": "Skills to operate AI VPS infrastructure.",
      "descriptions": {
        "en": "Skills to operate AI VPS infrastructure.",
        "pt-BR": "Skills para operar VPS de IA."
      },
      "category": "devops",
      "tags": ["vps", "coolify", "n8n", "infra"],
      "coming_soon": [
        {
          "name": "hardening-vps",
          "description": "SSH key only, firewall, fail2ban, autoupdate, port and sudoers audit.",
          "descriptions": {
            "en": "SSH key only, firewall, fail2ban, autoupdate, port and sudoers audit.",
            "pt-BR": "SSH key only, firewall, fail2ban, autoupdate, auditoria de portas e sudoers."
          },
          "category": "security",
          "tags": ["seguranca", "ssh", "fail2ban", "firewall", "hardening"]
        },
        {
          "name": "monitoramento-grafana",
          "description": "Grafana + Prometheus: install, alerts, complex dashboards.",
          "category": "monitoring",
          "tags": ["grafana", "prometheus", "alertas", "dashboard"]
        }
      ]
    }
  ]
}
```

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
