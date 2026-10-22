#!/usr/bin/env bats
# Runs post-merge.sh against throwaway repos with a local remote and a fake gh.

load helpers/repos

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../skills/post-merge/scripts/post-merge.sh"
  setup_repos
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
