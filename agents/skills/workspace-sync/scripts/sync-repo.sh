#!/usr/bin/env bash
# Syncs one repo without touching local work: fetches with prune,
# fast-forwards the default branch when that is safe (moving its initialized
# submodules along), and reports what needs a decision (dirty tree, diverged
# branches, branches whose remote is gone, a new default branch).
# Deletes nothing and initializes no submodule.
#
# Usage: sync-repo.sh [--shared] <repo>
#   --shared  the repo is an object store other clones borrow from
#             (objects/info/alternates): also fetch its submodules and check
#             that gc never prunes objects they may still need.
#
# Output: "== <repo>" then one "key: value" line per finding.
# Exit status: 0 done (findings may still need attention), 1 error.
set -euo pipefail

say() { echo "$1: $2"; }

# Moves the initialized submodules of $1 whose pin changed since commit $2 to
# their new pin, then does the same inside them. A submodule that isn't at its
# old pin, or has uncommitted changes, is left alone and reported.
update_submodules() {
  local dir=$1 old=$2 mode sha path sub old_pin head
  git -C "$dir" ls-files --stage | while read -r mode sha _ path; do
    [ "$mode" = 160000 ] || continue
    sub=${dir#./}/$path
    sub=${sub#./}
    [ -e "$dir/$path/.git" ] || continue
    old_pin=$(git -C "$dir" rev-parse --quiet --verify "$old:$path" || true)
    [ -n "$old_pin" ] && [ "$old_pin" != "$sha" ] || continue
    head=$(git -C "$dir/$path" rev-parse HEAD)
    if [ "$head" = "$sha" ]; then
      continue
    elif [ "$head" != "$old_pin" ]; then
      say submodule "$sub not updated: not at its old pin"
    elif [ -n "$(git -C "$dir/$path" status --porcelain --untracked-files=no)" ]; then
      say submodule "$sub not updated: uncommitted changes"
    elif git -C "$dir" submodule update --quiet -- "$path" 2>/dev/null; then
      say submodule "$sub updated ${old_pin:0:9}..${sha:0:9}"
      update_submodules "$dir/$path" "$old_pin"
    else
      say submodule "$sub not updated: checkout failed"
    fi
  done
}
die() {
  echo "error: $1"
  exit 1
}

shared=false
if [ "${1:-}" = --shared ]; then
  shared=true
  shift
fi
[ $# -eq 1 ] || die "usage: sync-repo.sh [--shared] <repo>"
repo=$1

echo "== $repo"
[ "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$repo" 2>/dev/null && pwd -P)" ] ||
  die "not the top of a git repo"
cd "$repo"

# origin/HEAD is set at clone time; following the remote keeps it current
# when the default branch changes on the server (git 2.48+).
before=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)
git -c remote.origin.followRemoteHEAD=always fetch --quiet --all --prune 2>/dev/null ||
  die "fetch failed (network or credentials?)"
say fetch ok

default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD) || die "can't tell origin's default branch"
[ -z "$before" ] || [ "$before" = "$default" ] || say default "changed ${before#origin/} -> ${default#origin/}"
default=${default#origin/}
upstream=refs/remotes/origin/$default
current=$(git symbolic-ref --quiet --short HEAD || echo "(detached)")
dirty=false
[ -z "$(git status --porcelain --untracked-files=no --ignore-submodules=dirty)" ] || dirty=true

# Fast-forward only: never rewrites local commits or touches uncommitted work.
old=$(git rev-parse --quiet --verify "refs/heads/$default" || true)
new=$(git rev-parse "$upstream")
if [ -z "$old" ]; then
  say "$default" "no local branch"
elif [ "$old" = "$new" ]; then
  say "$default" "up to date"
elif ! git merge-base --is-ancestor "$old" "$new"; then
  say "$default" "diverged from origin, left as is"
elif [ "$current" = "$default" ]; then
  if $dirty; then
    say "$default" "behind origin, not updated: uncommitted changes"
  else
    git merge --quiet --ff-only "$upstream"
    say "$default" "fast-forwarded ${old:0:9}..${new:0:9}"
    update_submodules . "$old"
  fi
elif git worktree list --porcelain | grep -qxF "branch refs/heads/$default"; then
  say "$default" "behind origin, not updated: checked out in another worktree"
else
  git update-ref "refs/heads/$default" "$new" "$old"
  say "$default" "fast-forwarded ${old:0:9}..${new:0:9}"
fi

if [ "$current" != "$default" ]; then
  state=$($dirty && echo "uncommitted changes" || echo clean)
  if track=$(git rev-list --left-right --count "HEAD...@{upstream}" 2>/dev/null); then
    state="$state, ahead ${track%%[[:space:]]*}, behind ${track##*[[:space:]]}"
  fi
  say "on $current" "$state"
elif $dirty; then
  say "on $current" "uncommitted changes"
fi

# A gone branch checked out in a linked worktree gets its own line: the
# worktree must be removed before the branch can be deleted.
gone=""
for branch in $(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" { print $1 }'); do
  worktree=$(git worktree list --porcelain | awk -v ref="branch refs/heads/$branch" '
    /^worktree / { n++; path = substr($0, 10) }
    n > 1 && $0 == ref { print path }')
  if [ -z "$worktree" ]; then
    gone="$gone $branch"
  elif [ -z "$(git -C "$worktree" status --porcelain)" ]; then
    say "gone worktree" "$branch at $worktree, clean"
  else
    say "gone worktree" "$branch at $worktree, uncommitted changes"
  fi
done
[ -z "$gone" ] || say gone "${gone# }"

# A submodule that borrows objects stores its pinned commit itself when the
# repo it borrows from doesn't have it yet.
if [ -f .gitmodules ]; then
  # shellcheck disable=SC2016 # expanded by git submodule foreach
  git submodule foreach --quiet --recursive '
    alternates="$(git rev-parse --git-path objects/info/alternates)"
    [ -f "$alternates" ] || exit 0
    head=$(git rev-parse --short=9 HEAD)
    while read -r objects; do
      [ -e "$objects" ] || { echo "not shared: $displaypath borrows from missing $objects"; continue; }
      git --git-dir="${objects%/objects}" cat-file -e "$head^{commit}" 2>/dev/null && exit 0
    done <"$alternates"
    echo "not shared: $displaypath $head is not in the repo it borrows from"
  '
fi

if $shared; then
  # shellcheck disable=SC2016 # expanded by git submodule foreach
  check_guard='
    for key in gc.pruneExpire gc.reflogExpireUnreachable; do
      [ "$(git config --get "$key")" = never ] || echo "guard: ${displaypath:-.} needs $key=never"
    done'
  sh -c "displaypath=.; $check_guard"
  if [ -f .gitmodules ]; then
    git submodule foreach --quiet --recursive "git fetch --quiet --all --prune 2>/dev/null || echo \"error: fetch failed in \$displaypath\"; $check_guard"
  fi
fi
