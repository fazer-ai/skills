#!/usr/bin/env bash
# Creates a publisher credential on npm.fazer.ai (custom Verdaccio admin
# plugin) for each given plugin repo and sets the corresponding GitHub
# Actions secrets. If the credential already exists, rotates the secret.
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
#
# Anything not in .env is prompted interactively.
#
# Requires: gh (logged in), curl, python3.
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

if [ -z "${VERDACCIO_ADMIN_TOKEN:-}" ]; then
  read -r -s -p "VERDACCIO_ADMIN_TOKEN: " VERDACCIO_ADMIN_TOKEN
  echo
fi
[ -n "$VERDACCIO_ADMIN_TOKEN" ] || { echo "admin token vazio, abortando." >&2; exit 1; }

tmp_resp="$(mktemp)"
trap 'rm -f "$tmp_resp"' EXIT

extract_secret() {
  python3 -c "import json,sys;print(json.load(sys.stdin)['secret'])" < "$tmp_resp"
}

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
  DESCRIPTION="CI publisher for fazer-ai/${repo}"

  echo
  echo ">>> fazer-ai/$repo (credential: $USERNAME)"

  create_credential() {
    curl -sS -o "$tmp_resp" -w '%{http_code}' \
      -X POST "$REGISTRY/-/admin/credentials" \
      -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$USERNAME\",\"description\":\"$DESCRIPTION\",\"is_admin\":true}"
  }

  http_code=$(create_credential)

  if [ "$http_code" = "409" ]; then
    echo "  credential exists, replacing (DELETE + POST)"
    del_code=$(curl -sS -o "$tmp_resp" -w '%{http_code}' \
      -X DELETE "$REGISTRY/-/admin/credentials/$USERNAME" \
      -H "Authorization: Bearer $VERDACCIO_ADMIN_TOKEN")
    if [ "$del_code" != "204" ] && [ "$del_code" != "200" ]; then
      echo "  delete failed: HTTP $del_code" >&2
      cat "$tmp_resp" >&2; echo >&2
      echo "  skipping $repo" >&2
      continue
    fi
    http_code=$(create_credential)
  fi

  case "$http_code" in
    201)
      echo "  credential created (admin)"
      secret="$(extract_secret)"
      ;;
    *)
      echo "  Verdaccio returned HTTP $http_code:" >&2
      cat "$tmp_resp" >&2; echo >&2
      echo "  skipping $repo" >&2
      continue
      ;;
  esac

  echo "  setting GitHub secrets"
  gh secret set NPM_REGISTRY_USER  --repo "fazer-ai/$repo" --body "$USERNAME"
  gh secret set NPM_REGISTRY_TOKEN --repo "fazer-ai/$repo" --body "$secret"
  gh secret set SKILLS_REPO_PAT    --repo "fazer-ai/$repo" --body "$pat"

  echo "  done"
done

echo
echo "Verify with:"
for repo in "$@"; do
  echo "  gh secret list --repo fazer-ai/$repo"
done
