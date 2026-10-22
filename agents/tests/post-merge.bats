#!/usr/bin/env bats
# Runs post-merge.sh against throwaway repos with a local remote and a fake gh.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../skills/post-merge/scripts/post-merge.sh"

  export HOME="$BATS_TEST_TMPDIR/home" GIT_CONFIG_NOSYSTEM=1
  mkdir -p "$HOME"
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global protocol.file.allow always

  # gh reports whatever PR state the test sets.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "$FAKE_PR_STATE"\n' >"$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" FAKE_PR_STATE=OPEN

  make_repos main
}

# Creates a bare remote whose default branch is $1, a "seed" clone that plays
# the remote side (merging PRs), and the "work" clone the script runs in.
make_repos() {
  cd "$BATS_TEST_TMPDIR"
  rm -rf remote.git seed work
  git init -q --bare --initial-branch="$1" remote.git
  git clone -q remote.git seed 2>/dev/null
  commit_file seed README.md
  git -C seed push -q origin "$1"
  git clone -q remote.git work
  cd work
}

commit_file() {
  echo "$2 $RANDOM" >>"$1/$2"
  git -C "$1" add "$2"
  git -C "$1" commit -q -m "change $2"
}

start_branch() {
  git switch -q -c feature
  commit_file . feature.txt
  git push -q -u origin feature 2>/dev/null
}

# Merges origin/feature on the remote side (merge commit or squash) and
# deletes the remote branch, as GitHub does on merge.
merge_on_remote() {
  git -C ../seed pull -q
  if [ "$1" = squash ]; then
    git -C ../seed merge -q --squash origin/feature
    git -C ../seed commit -q -m "feature (#1)"
  else
    git -C ../seed merge -q --no-ff -m "Merge feature" origin/feature
  fi
  git -C ../seed push -q origin HEAD
  git -C ../seed push -q origin --delete feature
}

current_branch() {
  git symbolic-ref --short HEAD
}

@test "deletes a branch merged with a merge commit" {
  start_branch
  merge_on_remote merge
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted feature"* ]]
  [ "$(current_branch)" = main ]
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  run git rev-parse --verify --quiet refs/heads/feature
  [ "$status" -ne 0 ]
  run git rev-parse --verify --quiet refs/remotes/origin/feature
  [ "$status" -ne 0 ]
}

@test "deletes a squash-merged branch when its PR is merged" {
  start_branch
  merge_on_remote squash
  FAKE_PR_STATE=MERGED run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(current_branch)" = main ]
  run git rev-parse --verify --quiet refs/heads/feature
  [ "$status" -ne 0 ]
}

@test "keeps the branch when the merge can't be confirmed" {
  start_branch
  merge_on_remote squash
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--force"* ]]
  [ "$(current_branch)" = feature ]
}

@test "--force deletes a branch whose merge can't be confirmed" {
  start_branch
  merge_on_remote squash
  run "$SCRIPT" --force
  [ "$status" -eq 0 ]
  [ "$(current_branch)" = main ]
  run git rev-parse --verify --quiet refs/heads/feature
  [ "$status" -ne 0 ]
}

@test "refuses to run with uncommitted changes" {
  start_branch
  merge_on_remote merge
  echo edit >>feature.txt
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ "$(current_branch)" = feature ]
  grep -q edit feature.txt
}

@test "refuses to run on the default branch" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ "$(current_branch)" = main ]
}

@test "detects a default branch other than main" {
  make_repos master
  start_branch
  merge_on_remote merge
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(current_branch)" = master ]
}

@test "initializes and updates submodules" {
  git init -q --bare --initial-branch=main ../sub.git
  git clone -q ../sub.git ../sub 2>/dev/null
  commit_file ../sub lib.txt
  git -C ../sub push -q origin main
  git -C ../seed submodule add -q "$BATS_TEST_TMPDIR/sub.git" sub
  git -C ../seed commit -q -m "add submodule"
  git -C ../seed push -q origin main
  git pull -q

  start_branch
  merge_on_remote merge
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f sub/lib.txt ]
}
