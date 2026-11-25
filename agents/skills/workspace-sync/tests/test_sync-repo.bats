#!/usr/bin/env bats
# Runs sync-repo.sh against throwaway repos with a local remote.

load repos

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/sync-repo.sh"
  setup_repos
}

# Adds a commit to main on the remote.
advance_remote() {
  git -C ../seed pull -q
  commit_file ../seed upstream.txt
  git -C ../seed push -q origin main
}

@test "fast-forwards the checked-out default branch" {
  advance_remote
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"main: fast-forwarded"* ]] || false
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
}

@test "leaves the default branch alone with uncommitted changes" {
  advance_remote
  echo edit >>README.md
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"not updated: uncommitted changes"* ]] || false
  [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]
  grep -q edit README.md
}

@test "fast-forwards the default branch while another branch is checked out" {
  start_branch
  advance_remote
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"main: fast-forwarded"* ]] || false
  [[ "$output" == *"on feature: clean, ahead 0, behind 0"* ]] || false
  [ "$(current_branch)" = feature ]
  [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ]
}

@test "leaves a diverged default branch alone" {
  commit_file . local.txt
  advance_remote
  local_main=$(git rev-parse main)
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"main: diverged"* ]] || false
  [ "$(git rev-parse main)" = "$local_main" ]
}

@test "skips a default branch checked out in another worktree" {
  start_branch
  git worktree add -q ../other main
  advance_remote
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked out in another worktree"* ]] || false
}

@test "reports branches whose remote is gone without deleting them" {
  start_branch
  squash_merge_on_remote
  git switch -q main
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"gone: feature"* ]] || false
  git rev-parse --verify --quiet refs/heads/feature
}

@test "--shared reports a missing gc guard, and is quiet once it is set" {
  run "$SCRIPT" --shared .
  [ "$status" -eq 0 ]
  [[ "$output" == *"guard: . needs gc.pruneExpire=never"* ]] || false
  git config gc.pruneExpire never
  git config gc.reflogExpireUnreachable never
  run "$SCRIPT" --shared .
  [ "$status" -eq 0 ]
  [[ "$output" != *"guard:"* ]] || false
}

@test "reports a submodule commit the repo it borrows from doesn't have" {
  git init -q --bare --initial-branch=main ../sub.git
  git clone -q ../sub.git ../sub 2>/dev/null
  commit_file ../sub lib.txt
  git -C ../sub push -q origin main
  git clone -q ../sub.git ../owner
  git submodule add -q --reference ../owner "$BATS_TEST_TMPDIR/sub.git" sub
  git commit -q -m "add submodule"
  run "$SCRIPT" .
  [[ "$output" != *"not shared"* ]] || false

  commit_file ../sub lib.txt
  git -C ../sub push -q origin main
  git -C sub pull -q
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"not shared: sub"* ]] || false
}

@test "follows a change of the remote's default branch and reports it" {
  git -C ../seed switch -q -c develop
  git -C ../seed push -q origin develop
  git -C ../remote.git symbolic-ref HEAD refs/heads/develop
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"default: changed main -> develop"* ]] || false
  [[ "$output" == *"develop: no local branch"* ]] || false
  [ "$(git symbolic-ref --short refs/remotes/origin/HEAD)" = origin/develop ]
  run "$SCRIPT" .
  [[ "$output" != *"default: changed"* ]] || false
}

# Gives the remote a submodule "sub" (with its own submodule "inner") and
# clones it into the work repo, with only "sub" initialized.
add_submodules() {
  for r in inner sub; do
    git init -q --bare --initial-branch=main "../$r.git"
    git clone -q "../$r.git" "../$r" 2>/dev/null
    commit_file "../$r" lib.txt
    [ "$r" = inner ] || git -C ../sub submodule add -q "$BATS_TEST_TMPDIR/inner.git" inner
    git -C "../$r" commit -q --allow-empty -m "add inner"
    git -C "../$r" push -q origin main
  done
  git -C ../seed pull -q
  git -C ../seed submodule add -q "$BATS_TEST_TMPDIR/sub.git" sub
  git -C ../seed commit -q -m "add sub"
  git -C ../seed push -q origin main
  git pull -q
  git submodule update -q --init sub
}

# Moves the pins of "inner" in "sub" and of "sub" on the remote.
advance_submodules() {
  commit_file ../inner lib.txt
  git -C ../inner push -q origin main
  git -C ../sub submodule update -q --init --remote inner
  git -C ../sub commit -q -am "bump inner"
  git -C ../sub push -q origin main
  git -C ../seed submodule update -q --remote sub
  git -C ../seed commit -q -am "bump sub"
  git -C ../seed push -q origin main
}

@test "moves an initialized submodule to its new pin, and initializes nothing" {
  add_submodules
  advance_submodules
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"main: fast-forwarded"* ]] || false
  [[ "$output" == *"submodule: sub updated"* ]] || false
  [ "$(git -C sub rev-parse HEAD)" = "$(git rev-parse HEAD:sub)" ]
  [ ! -e sub/inner/.git ]
  [ -z "$(git status --porcelain)" ]
}

@test "leaves a submodule with uncommitted changes at its old pin" {
  add_submodules
  old_pin=$(git rev-parse HEAD:sub)
  echo edit >>sub/lib.txt
  advance_submodules
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"main: fast-forwarded"* ]] || false
  [[ "$output" == *"submodule: sub not updated: uncommitted changes"* ]] || false
  [ "$(git -C sub rev-parse HEAD)" = "$old_pin" ]
  grep -q edit sub/lib.txt
}

@test "updates nested submodules only when they are initialized" {
  add_submodules
  git -C sub submodule update -q --init inner
  advance_submodules
  run "$SCRIPT" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"submodule: sub/inner updated"* ]] || false
  [ "$(git -C sub/inner rev-parse HEAD)" = "$(git -C sub rev-parse HEAD:inner)" ]
}

@test "fails when the fetch fails" {
  git remote set-url origin "$BATS_TEST_TMPDIR/missing.git"
  run "$SCRIPT" .
  [ "$status" -eq 1 ]
  [[ "$output" == *"fetch failed"* ]] || false
}

@test "fails outside the top of a repo" {
  mkdir sub-dir
  run "$SCRIPT" sub-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"not the top of a git repo"* ]] || false
}
