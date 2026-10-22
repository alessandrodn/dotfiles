# Throwaway repos for post-merge tests: a bare remote, a "seed" clone that
# plays the remote side, a "work" clone to clean up, and a fake gh.

setup_repos() {
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_NOSYSTEM=1
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
