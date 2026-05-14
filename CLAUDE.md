# CLAUDE.md — fazer.ai marketplace ops reference

Operational notes for the `fazer-ai/skills` marketplace and the private
Verdaccio at `https://npm.fazer.ai/`. Loaded into Claude Code's context
when working in this repo.

## Private npm registry (Verdaccio)

The marketplace gates plugin install via the `@fazer-ai-pro/*` scope on
the private Verdaccio at `https://npm.fazer.ai/`. Each plugin repo
publishes there as a dedicated CI user (`ci-<repo-name>`).

### Create a publisher user (admin only)

Signup is closed on `npm.fazer.ai`. Use the CouchDB-style endpoint
`PUT /-/user/org.couchdb.user:NAME` with a Bearer admin token.

#### 1. Get an admin token

```sh
curl -fsS -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"ADMIN_USER","password":"ADMIN_PWD"}' \
  https://npm.fazer.ai/-/v1/login
# => {"token":"npm_..."}
```

Set the token in the shell:

```sh
export VERDACCIO_ADMIN_TOKEN="npm_..."
```

#### 2. Create the user

```sh
USERNAME="ci-fazer-ai-vps"
PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)"
EMAIL="ops@fazer.ai"
DATE="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"

curl -fsS -X PUT \
  -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"email\":\"$EMAIL\",\"type\":\"user\",\"roles\":[],\"date\":\"$DATE\"}" \
  "https://npm.fazer.ai/-/user/org.couchdb.user:$USERNAME"

echo
echo "  user=$USERNAME"
echo "  password=$PASSWORD"
```

The response is `{"ok":"user '<name>' created", "token":"..."}`. Save
`$USERNAME` and `$PASSWORD` (not the returned token) — those are the
values consumed by the publish workflow.

#### 3. Rotate the password

Repeat the same `PUT` with the same `USERNAME` and a new `PASSWORD`.
Then update the GitHub secret on the plugin repo.

## GitHub Actions secrets per plugin repo

Each plugin repo (`fazer-ai/fazer-ai-<name>`) needs three secrets for
the `publish.yml` workflow:

| Secret | Value | Notes |
| ------ | ----- | ----- |
| `NPM_REGISTRY_USER` | `ci-fazer-ai-<name>` | the Verdaccio username |
| `NPM_REGISTRY_TOKEN` | the password set above | used as the password, not as a token. Both values are base64'd as `user:pass` for Basic auth |
| `SKILLS_REPO_PAT` | a GitHub fine-grained PAT | needs **Contents: Write** + **Pull requests: Write** on `fazer-ai/skills`. Shared across all plugin repos (one PAT, set in each repo) |

Set them with:

```sh
gh secret set NPM_REGISTRY_USER  --repo fazer-ai/<repo> --body "$NPM_USER"
gh secret set NPM_REGISTRY_TOKEN --repo fazer-ai/<repo> --body "$NPM_TOKEN"
gh secret set SKILLS_REPO_PAT    --repo fazer-ai/<repo> --body "$PAT"
```

The helper script `~/set-plugin-secrets.sh` does the user creation and
secret-set in one go.

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
