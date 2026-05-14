#!/usr/bin/env bash
# Creates a Verdaccio CI user per plugin repo and sets the corresponding
# GitHub Actions secrets. Run once when bringing up new plugin repos.
#
# Reads VERDACCIO_ADMIN_TOKEN and SKILLS_REPO_PAT from the repo root .env
# (if present), or prompts interactively.
#
# Usage:
#   ./scripts/set-plugin-secrets.sh                  # defaults to the 3 new plugin repos
#   ./scripts/set-plugin-secrets.sh fazer-ai-foo ... # explicit repo list (without the fazer-ai/ prefix)
#
# Requires: gh (logged in), curl, openssl.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

REGISTRY="${VERDACCIO_REGISTRY:-https://npm.fazer.ai}"
EMAIL="${VERDACCIO_USER_EMAIL:-ops@fazer.ai}"

if [ $# -gt 0 ]; then
  REPOS=("$@")
else
  REPOS=(fazer-ai-vps fazer-ai-agentes fazer-ai-skills-dev)
fi

if [ -z "${VERDACCIO_ADMIN_TOKEN:-}" ]; then
  read -r -s -p "VERDACCIO_ADMIN_TOKEN: " VERDACCIO_ADMIN_TOKEN
  echo
fi
[ -n "$VERDACCIO_ADMIN_TOKEN" ] || { echo "admin token vazio, abortando."; exit 1; }

if [ -z "${SKILLS_REPO_PAT:-}" ]; then
  read -r -s -p "SKILLS_REPO_PAT (github_pat_...): " SKILLS_REPO_PAT
  echo
fi
[ -n "$SKILLS_REPO_PAT" ] || { echo "PAT vazio, abortando."; exit 1; }

tmp_resp="$(mktemp)"
trap 'rm -f "$tmp_resp"' EXIT

for repo in "${REPOS[@]}"; do
  USERNAME="ci-${repo}"
  PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)"
  DATE="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

  echo
  echo ">>> fazer-ai/$repo"
  echo "  creating $USERNAME on $REGISTRY"

  http_code=$(curl -sS -o "$tmp_resp" -w '%{http_code}' -X PUT \
    -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"email\":\"$EMAIL\",\"type\":\"user\",\"roles\":[],\"date\":\"$DATE\"}" \
    "$REGISTRY/-/user/org.couchdb.user:$USERNAME")

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    echo "  Verdaccio returned HTTP $http_code:"
    cat "$tmp_resp"
    echo
    echo "  skipping $repo"
    continue
  fi

  echo "  user created. Setting GitHub secrets..."
  gh secret set NPM_REGISTRY_USER  --repo "fazer-ai/$repo" --body "$USERNAME"
  gh secret set NPM_REGISTRY_TOKEN --repo "fazer-ai/$repo" --body "$PASSWORD"
  gh secret set SKILLS_REPO_PAT    --repo "fazer-ai/$repo" --body "$SKILLS_REPO_PAT"

  echo "  done: user=$USERNAME"
done

echo
echo "Verify with:"
for repo in "${REPOS[@]}"; do
  echo "  gh secret list --repo fazer-ai/$repo"
done
