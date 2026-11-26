# Throwaway repos for sync-repo.sh tests: a bare remote, a "seed" clone that
# plays the remote side, and a "work" clone the script runs in.

setup_repos() {
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_NOSYSTEM=1
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global protocol.file.allow always

  cd "$BATS_TEST_TMPDIR"
  git init -q --bare --initial-branch=main remote.git
  git clone -q remote.git seed 2>/dev/null
  commit_file seed README.md
  git -C seed push -q origin main
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

# Squash-merges origin/feature on the remote side and deletes the remote
# branch, as GitHub does on merge.
squash_merge_on_remote() {
  git -C ../seed pull -q
  git -C ../seed merge -q --squash origin/feature
  git -C ../seed commit -q -m "feature (#1)"
  git -C ../seed push -q origin HEAD
  git -C ../seed push -q origin --delete feature
}

current_branch() {
  git symbolic-ref --short HEAD
}
