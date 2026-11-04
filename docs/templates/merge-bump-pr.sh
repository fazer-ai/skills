#!/usr/bin/env bash
# Merges the bump PR that publish.yml opens in the marketplace repo.
#
# Usage: merge-bump-pr.sh <owner/repo> <branch>
#
# A PR that branch protection is holding (merge state BLOCKED: required checks
# or reviews still missing) gets auto-merge right away, which makes GitHub
# wait for whatever the protection requires; nothing else runs.
#
# Otherwise it first waits for the PR's checks, required or not: `gh pr merge
# --auto` on a PR GitHub already calls clean merges it right away, even with a
# check still queued (measured on gh 2.95), so asking for the merge first
# would skip the check. Right after the PR opens its
# checks may not be registered yet, so neither "no checks" nor "all green"
# counts before a grace period. A failing check, or checks still running at the timeout, fail the
# job and leave the PR open.
#
# Then it asks for auto-merge, so a repo with branch protection still makes
# the merge wait for whatever else it requires. GitHub refuses auto-merge on
# a PR it calls "clean" or "unstable" and in a repo that does not allow it;
# the checks are already green at that point, so the PR is merged directly.
# Any other refusal, and a merge that fails, fail the job.
#
# Waits, in seconds (fractions allowed):
#   MERGE_BUMP_CHECKS_TIMEOUT  how long to wait for checks (default 900)
#   MERGE_BUMP_CHECKS_GRACE    how long "no checks" is waited out (default 30)
#   MERGE_BUMP_CHECKS_INTERVAL time between reads (default 10)
set -uo pipefail

repo=$1
branch=$2
timeout=${MERGE_BUMP_CHECKS_TIMEOUT:-900}
grace=${MERGE_BUMP_CHECKS_GRACE:-30}
interval=${MERGE_BUMP_CHECKS_INTERVAL:-10}

if [ "$(gh pr view "$branch" --repo "$repo" --json mergeStateStatus --jq .mergeStateStatus 2>/dev/null)" = BLOCKED ]; then
  if ! gh pr merge "$branch" --repo "$repo" --auto --squash --delete-branch; then
    echo "::error::could not enable auto-merge on ${repo} ${branch}; the PR is still open"
    exit 1
  fi
  echo "auto-merge enabled for ${branch}; branch protection decides when it merges"
  exit 0
fi

# Waits are counted in intervals slept, not timed, so it runs the same on
# bash 3 (macOS) and on the runner: a limit is reached once the intervals
# already slept cover it. The checks are read as their buckets (pass, fail,
# pending, skipping, cancel): the plain exit code of `gh pr checks` is 0 when
# the only non-passing check was cancelled, so it cannot tell green from
# cancelled. Measured on gh 2.95: with --json it exits 0 with the list, and
# exits 1 with "no checks reported on the '<branch>' branch" when there is none.
waits() { awk -v t="$1" -v i="$interval" 'BEGIN { n = t / i; print (n == int(n) ? n : int(n) + 1) }'; }
max_waits=$(waits "$timeout")
grace_waits=$(waits "$grace")
slept=0
while :; do
  checks=$(gh pr checks "$branch" --repo "$repo" --json bucket --jq '[.[].bucket] | join(" ")' 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ] && [[ $checks != *"no checks reported"* ]]; then
    printf '%s\n' "$checks" >&2
    echo "::error::could not read the checks of ${repo} ${branch}; the PR is still open"
    exit 1
  elif [ "$rc" -ne 0 ] || [ -z "$checks" ]; then
    if [ "$slept" -ge "$grace_waits" ]; then
      echo "no checks on ${branch}"
      break
    fi
  elif [[ " $checks " == *" fail "* || " $checks " == *" cancel "* ]]; then
    echo "checks: $checks" >&2
    echo "::error::a check failed or was cancelled on ${repo} ${branch}; the PR is still open"
    exit 1
  elif [[ " $checks " != *" pending "* ]] && [ "$slept" -ge "$grace_waits" ]; then
    # Green only counts after the grace period too: a check that passed early
    # can hide another workflow that has not registered its check yet.
    echo "checks green on ${branch} ($checks)"
    break
  fi
  if [ "$slept" -ge "$max_waits" ]; then
    printf '%s\n' "$checks" >&2
    echo "::error::checks on ${repo} ${branch} did not finish in ${timeout}s; the PR is still open"
    exit 1
  fi
  sleep "$interval"
  slept=$((slept + 1))
done

if out=$(gh pr merge "$branch" --repo "$repo" --auto --squash --delete-branch 2>&1); then
  printf '%s\n' "$out"
  echo "auto-merge requested for ${branch} (gh merges right away when the PR is already clean)"
  exit 0
fi
printf '%s\n' "$out" >&2

case $out in
  *"clean status"* | *"unstable status"* | *"Auto merge is not allowed"*) ;;
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
