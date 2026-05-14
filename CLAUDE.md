# CLAUDE.md — fazer.ai marketplace ops reference

Operational notes for the `fazer-ai/skills` marketplace and the private
Verdaccio at `https://npm.fazer.ai/`. Loaded into Claude Code's context
when working in this repo.

## Private npm registry (Verdaccio + admin plugin)

The marketplace gates plugin install via the `@fazer-ai-pro/*` scope on
the private Verdaccio at `https://npm.fazer.ai/`. Auth uses a custom
Verdaccio plugin (`verdaccio-plugin/src/admin-routes.ts` in
`fazer-ai/npm-registry`) that exposes `/-/admin/credentials` for
issuing and rotating per-credential secrets. Each plugin repo publishes
as a dedicated credential (`ci-<repo-name>`).

The admin token is set on the Verdaccio server (env var `ADMIN_TOKEN`);
the CLI scripts here consume it via the `VERDACCIO_ADMIN_TOKEN` env var.

### Create a publisher credential

```sh
USERNAME="ci-fazer-ai-vps"
DESCRIPTION="CI publisher for fazer-ai/fazer-ai-vps"

curl -fsS -X POST "https://npm.fazer.ai/-/admin/credentials" \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$USERNAME\",\"description\":\"$DESCRIPTION\",\"is_admin\":false}"
```

Response on `201 Created`:

```json
{
  "id": "...",
  "name": "ci-fazer-ai-vps",
  "description": "CI publisher for fazer-ai/fazer-ai-vps",
  "is_admin": false,
  "enabled": true,
  "created_at": "...",
  "updated_at": "...",
  "secret": "<24-byte base64url>"
}
```

The `secret` is only returned on creation — store immediately. Name
validation: lowercase alphanumeric + hyphens, 1-64 chars. On `409
Conflict`, rotate with PATCH (see below). Rate limit: 100 req / 5 min /
IP.

### Other credential operations

```sh
# Rotate secret (returns {"secret": "..."})
curl -fsS -X PATCH "https://npm.fazer.ai/-/admin/credentials/$USERNAME" \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN"

# Disable / re-enable
curl -fsS -X PUT "https://npm.fazer.ai/-/admin/credentials/$USERNAME" \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled":false}'

# Read (no secret in response)
curl -fsS "https://npm.fazer.ai/-/admin/credentials/$USERNAME" \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN"

# Revoke
curl -fsS -X DELETE "https://npm.fazer.ai/-/admin/credentials/$USERNAME" \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN"
```

## GitHub Actions secrets per plugin repo

Each plugin repo (`fazer-ai/fazer-ai-<name>`) needs three secrets for
the `publish.yml` workflow:

| Secret | Value | Notes |
| ------ | ----- | ----- |
| `NPM_REGISTRY_USER` | `ci-fazer-ai-<name>` | the Verdaccio username |
| `NPM_REGISTRY_TOKEN` | the password set above | used as the password, not as a token. Both values are base64'd as `user:pass` for Basic auth |
| `SKILLS_REPO_PAT` | a GitHub fine-grained PAT | needs **Contents: Write** + **Pull requests: Write** on `fazer-ai/skills`. Recommended: one PAT per plugin repo so revocation has tight blast radius |

Set them with:

```sh
gh secret set NPM_REGISTRY_USER  --repo fazer-ai/<repo> --body "$NPM_USER"
gh secret set NPM_REGISTRY_TOKEN --repo fazer-ai/<repo> --body "$NPM_TOKEN"
gh secret set SKILLS_REPO_PAT    --repo fazer-ai/<repo> --body "$PAT"
```

The helper script `scripts/set-plugin-secrets.sh` (in this repo) does
the user creation and secret-set in one go for any list of repos. It
reads `VERDACCIO_ADMIN_TOKEN` and per-repo PATs from `.env` (see
`.env.example` for the variable naming convention).

## Publish workflow expectations

The `publish.yml` workflow at `docs/templates/publish.yml` (also copied
into each plugin repo's `.github/workflows/`) does on release:

1. Verifies `package.json`, `.claude-plugin/plugin.json`, and
   `.claude-plugin/marketplace.json` versions match each other and the
   tag.
2. Writes `.npmrc` with `_auth = base64(user:password)`.
3. Runs `npm publish`.
4. Opens a PR against `fazer-ai/skills` bumping the plugin's entry in
   the central `.claude-plugin/marketplace.json` and propagating
   `description`, `descriptions`, `skills`, and `coming_soon` from the
   plugin repo.

If step 4 fails with 403, the PAT is missing **Contents: Write** — see
`SKILLS_REPO_PAT` above.

## Plugin entry in central marketplace

When adding a new plugin to `.claude-plugin/marketplace.json` in this
repo, seed the entry **before** the first release so step 4 of the
workflow finds it. Use `version: "1.0.0"` placeholder and let the
auto-bump PR refresh it on the first real release.

See [`docs/plugin-publish-workflow.md`](docs/plugin-publish-workflow.md)
for the full schema (`skills[]`, `coming_soon[]`).
