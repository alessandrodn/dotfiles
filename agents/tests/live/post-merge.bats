#!/usr/bin/env bats
# Runs the post-merge skill through real Claude Code and Codex sessions on
# throwaway repos. Needs both CLIs logged in and the skills linked (see
# agents/README.md). Each test makes model calls, so this suite runs locally,
# not in CI:
#
#   bats agents/tests/live

load ../helpers/repos

setup() {
  setup_repos
  start_branch
}

# Fails unless $1/post-merge links to this checkout's skill.
require_linked_skill() {
  local linked expected
  linked=$(cd "$1/post-merge" 2>/dev/null && pwd -P) || true
  expected=$(cd "$BATS_TEST_DIRNAME/../../skills/post-merge" && pwd -P)
  [ "$linked" = "$expected" ] || {
    echo "$1/post-merge doesn't link to $expected" >&2
    return 1
  }
}

# Only the skill and its script are allowed to run.
run_claude() {
  require_linked_skill ~/.claude/skills
  run claude -p "$1" --output-format stream-json --verbose \
    --allowedTools "Skill(post-merge)" "Bash(*post-merge.sh*)" </dev/null
}

# workspace-write keeps .git read-only, so the repo's .git is added explicitly.
run_codex() {
  require_linked_skill ~/.agents/skills
  run codex exec --json -s workspace-write --add-dir "$PWD/.git" "$1" </dev/null
}

assert_cleaned_up() {
  [ "$status" -eq 0 ]
  [[ "$output" == *post-merge/scripts/post-merge.sh* ]]
  [ "$(current_branch)" = main ]
  run git rev-parse --verify --quiet refs/heads/feature
  [ "$status" -ne 0 ]
}

# The script refused, and the agent didn't force the delete without asking.
assert_kept_branch() {
  [ "$status" -eq 0 ]
  [[ "$output" == *post-merge/scripts/post-merge.sh* ]]
  [[ "$output" != *"post-merge.sh --force"* ]]
  [ "$(current_branch)" = feature ]
}

@test "Claude Code: cleans up when asked in plain words" {
  merge_on_remote merge
  run_claude "My PR for this branch was merged. Please clean up."
  assert_cleaned_up
}

@test "Claude Code: cleans up on /post-merge" {
  merge_on_remote merge
  run_claude "/post-merge"
  assert_cleaned_up
}

@test "Claude Code: keeps a branch whose merge can't be confirmed" {
  merge_on_remote squash
  run_claude "/post-merge"
  assert_kept_branch
}

@test "Codex: cleans up when asked in plain words" {
  merge_on_remote merge
  run_codex "My PR for this branch was merged. Please clean up."
  assert_cleaned_up
}

@test "Codex: cleans up on \$post-merge" {
  merge_on_remote merge
  run_codex '$post-merge'
  assert_cleaned_up
}

@test "Codex: keeps a branch whose merge can't be confirmed" {
  merge_on_remote squash
  run_codex '$post-merge'
  assert_kept_branch
}
