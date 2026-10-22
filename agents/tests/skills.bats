#!/usr/bin/env bats
# Checks every skill against the Agent Skills format (https://agentskills.io/specification)
# and this repo's conventions.

setup() {
  SKILLS_DIR="$BATS_TEST_DIRNAME/../skills"
}

fail() {
  echo "$1" >&2
  return 1
}

# Prints the value of a top-level field from a SKILL.md frontmatter block.
frontmatter_field() {
  awk -v field="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, field ": ") == 1 { print substr($0, length(field) + 3); exit }
  ' "$1"
}

@test "every skill has a SKILL.md" {
  for dir in "$SKILLS_DIR"/*/; do
    [ -f "$dir/SKILL.md" ] || fail "$(basename "$dir"): missing SKILL.md"
  done
}

@test "name matches the folder and the spec's format" {
  for skill in "$SKILLS_DIR"/*/SKILL.md; do
    folder=$(basename "$(dirname "$skill")")
    name=$(frontmatter_field "$skill" name)
    [ "$name" = "$folder" ] || fail "$folder: name is '$name'"
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$folder: name must be lowercase words joined by single hyphens"
    [ "${#name}" -le 64 ] || fail "$folder: name is longer than 64 characters"
  done
}

@test "description is present and at most 1024 characters" {
  for skill in "$SKILLS_DIR"/*/SKILL.md; do
    folder=$(basename "$(dirname "$skill")")
    description=$(frontmatter_field "$skill" description)
    [ -n "$description" ] || fail "$folder: missing description"
    [ "${#description}" -le 1024 ] || fail "$folder: description is longer than 1024 characters"
  done
}

@test "skill files use LF line endings" {
  if crlf=$(grep -rlI $'\r' "$SKILLS_DIR"); then
    fail "CRLF line endings in: $crlf"
  fi
}

@test "skill scripts are executable and pass shellcheck" {
  command -v shellcheck >/dev/null || skip "shellcheck is not installed"
  for script in "$SKILLS_DIR"/*/scripts/*; do
    [ -e "$script" ] || continue
    [ -x "$script" ] || fail "$script is not executable"
    shellcheck "$script"
  done
}
