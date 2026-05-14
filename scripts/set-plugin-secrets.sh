#!/usr/bin/env bash
# Creates a Verdaccio CI user on npm.fazer.ai and sets the GitHub Actions
# secrets needed by a plugin repo's publish workflow. Idempotent: PUT on
# the Verdaccio user endpoint overwrites the password.
#
# Usage:
#   ./scripts/set-plugin-secrets.sh <repo> [<repo> ...]
#
# Repo names are without the fazer-ai/ prefix, e.g. fazer-ai-vps.
#
# Reads from .env at the repo root (gitignored):
#   VERDACCIO_ADMIN_TOKEN        - required, shared admin token
#   <REPO_NAME>_PAT              - per-repo GitHub PAT (uppercase, hyphens
#                                  converted to underscores). E.g.
#                                  fazer-ai-vps  ->  FAZER_AI_VPS_PAT
#   VERDACCIO_REGISTRY           - optional, default https://npm.fazer.ai
#   VERDACCIO_USER_EMAIL         - optional, default ops@fazer.ai
#
# Anything not in .env is prompted interactively.
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

if [ $# -lt 1 ]; then
  cat <<EOF >&2
usage: $0 <repo> [<repo> ...]

Repo names are without the fazer-ai/ prefix.
Example: $0 fazer-ai-vps fazer-ai-agentes fazer-ai-skills-dev
EOF
  exit 1
fi

REGISTRY="${VERDACCIO_REGISTRY:-https://npm.fazer.ai}"
EMAIL="${VERDACCIO_USER_EMAIL:-ops@fazer.ai}"

if [ -z "${VERDACCIO_ADMIN_TOKEN:-}" ]; then
  read -r -s -p "VERDACCIO_ADMIN_TOKEN: " VERDACCIO_ADMIN_TOKEN
  echo
fi
[ -n "$VERDACCIO_ADMIN_TOKEN" ] || { echo "admin token vazio, abortando." >&2; exit 1; }

tmp_resp="$(mktemp)"
trap 'rm -f "$tmp_resp"' EXIT

for repo in "$@"; do
  pat_var="$(echo "$repo" | tr '[:lower:]-' '[:upper:]_')_PAT"
  pat="${!pat_var:-}"
  if [ -z "$pat" ]; then
    read -r -s -p "PAT for $repo ($pat_var): " pat
    echo
  fi
  if [ -z "$pat" ]; then
    echo "  PAT vazio, pulando $repo." >&2
    continue
  fi

  USERNAME="ci-${repo}"
  PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)"
  DATE="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

  echo
  echo ">>> fazer-ai/$repo"
  echo "  PUT $REGISTRY/-/user/org.couchdb.user:$USERNAME"

  http_code=$(curl -sS -o "$tmp_resp" -w '%{http_code}' -X PUT \
    -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"email\":\"$EMAIL\",\"type\":\"user\",\"roles\":[],\"date\":\"$DATE\"}" \
    "$REGISTRY/-/user/org.couchdb.user:$USERNAME")

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    echo "  Verdaccio returned HTTP $http_code:" >&2
    cat "$tmp_resp" >&2
    echo >&2
    echo "  skipping $repo" >&2
    continue
  fi

  echo "  user OK. Setting GitHub secrets..."
  gh secret set NPM_REGISTRY_USER  --repo "fazer-ai/$repo" --body "$USERNAME"
  gh secret set NPM_REGISTRY_TOKEN --repo "fazer-ai/$repo" --body "$PASSWORD"
  gh secret set SKILLS_REPO_PAT    --repo "fazer-ai/$repo" --body "$pat"

  echo "  done"
done

echo
echo "Verify with:"
for repo in "$@"; do
  echo "  gh secret list --repo fazer-ai/$repo"
done
