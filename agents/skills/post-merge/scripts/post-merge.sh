#!/usr/bin/env bash
# Cleans up after the current branch's PR is merged: switches to the default
# branch, pulls, deletes the merged branch, prunes remote refs and updates
# submodules.
#
# Usage: post-merge.sh [--force]
#   --force  delete the branch even when its merge can't be confirmed
#
# Exit status: 0 done, 1 error, 2 merge not confirmed (nothing changed).
set -euo pipefail

say() { echo "post-merge: $*"; }
die() {
  echo "post-merge: $1" >&2
  exit "${2:-1}"
}

force=false
case "${1:-}" in
  --force) force=true ;;
  "") ;;
  *) die "usage: post-merge.sh [--force]" ;;
esac

branch=$(git symbolic-ref --quiet --short HEAD) || die "HEAD is detached"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  die "uncommitted changes on $branch"
fi

git fetch --quiet --prune origin
if ! default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD); then
  git remote set-head origin --auto >/dev/null
  default=$(git symbolic-ref --short refs/remotes/origin/HEAD)
fi
default=${default#origin/}
[ "$branch" != "$default" ] || die "already on $default; check out the merged branch first"

# A merge commit keeps the branch's commits; a squash or rebase merge doesn't,
# so fall back to asking GitHub.
if git merge-base --is-ancestor "$branch" "origin/$default"; then
  evidence="its commits are in origin/$default"
elif command -v gh >/dev/null && [ "$(gh pr view "$branch" --json state --jq .state 2>/dev/null)" = MERGED ]; then
  evidence="its PR is merged"
elif $force; then
  evidence="forced"
else
  die "can't confirm $branch is merged; rerun with --force to delete it anyway" 2
fi

git switch --quiet "$default"
git pull --quiet --ff-only
# -D because a squash-merged branch isn't an ancestor; the merge was checked above.
git branch --quiet -D "$branch"
say "deleted $branch ($evidence)"

if [ -f .gitmodules ]; then
  git submodule --quiet update --init --recursive
  say "updated submodules"
fi
say "on $default at $(git rev-parse --short HEAD)"
