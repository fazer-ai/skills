#!/usr/bin/env bash
# Merges the bump PR that publish.yml opens in the marketplace repo.
#
# Usage: merge-bump-pr.sh <owner/repo> <branch>
#
# Auto-merge first, so a repo with branch protection or required checks still
# makes the merge wait for them. GitHub refuses auto-merge on a PR that has
# nothing to wait for ("clean status"), which is what fazer-ai/skills answers
# today (no protection, no checks): that PR is merged right away, and so is
# one in a repo that does not allow auto-merge at all. Any other
# refusal, and a merge that fails, fail the job instead of leaving the PR open
# behind a warning on a green run.
set -uo pipefail

repo=$1
branch=$2

if out=$(gh pr merge "$branch" --repo "$repo" --auto --squash --delete-branch 2>&1); then
  printf '%s\n' "$out"
  echo "auto-merge requested for ${branch} (gh merges right away when the PR is already clean)"
  exit 0
fi
printf '%s\n' "$out" >&2

case $out in
  # Nothing to wait for, or a repo that does not allow auto-merge: merge now.
  *"clean status"* | *"Auto merge is not allowed"*) ;;
  *)
    echo "::error::could not enable auto-merge on ${repo} ${branch}; the PR is still open"
    exit 1
    ;;
esac

if ! gh pr merge "$branch" --repo "$repo" --squash --delete-branch; then
  echo "::error::could not merge ${branch} into ${repo}; the PR is still open"
  exit 1
fi
echo "merged ${branch} into ${repo}"
