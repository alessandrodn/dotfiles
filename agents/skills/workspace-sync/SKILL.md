---
name: workspace-sync
description: Bring every repo in a local workspace folder up to date without touching local work - fetch with prune, follow the remote's default branch, fast-forward it where safe (with its initialized submodules), check shared object stores (git alternates), and report dirty trees, diverged branches and branches whose remote is gone, including merged worktrees to remove. Use when the user starts the day, says they just arrived, asks to sync, update or fetch all their repos, or to clean up merged branches or worktrees.
---

The workspace is described in a `CLAUDE.md` at its root, in a `## Workspace sync` section: the repos to sync, and which of them are **shared** (object stores that other clones borrow from through `objects/info/alternates`). If there is no such section, list the git repos directly under the folder, ask which ones to sync and which are shared, and offer to write the section.

## Run

One Bash call, shared repos first, so the others find new objects in them:

```bash
S=<this skill>/scripts/sync-repo.sh
for r in <shared repos>; do "$S" --shared "<root>/$r"; done
for r in <other repos>; do "$S" "<root>/$r"; done
```

(`scripts/` is next to this file; use its full path.) The script handles one repo, deletes nothing, and prints `== <repo>` followed by `key: value` lines. It exits 1 only on an error for that repo (`error:` line); keep going with the rest.

## Report

One short table: repo, default branch result, current branch and state. Then only what needs the user:

| Line | Meaning | What to do |
|---|---|---|
| `error: fetch failed` | network or credentials | Say so once (likely the SSH key); don't retry in a loop. |
| `default: changed <old> -> <new>` | the remote's default branch changed; the local `<old>` is no longer fast-forwarded | Ask whether to delete `<old>`. First check it has nothing unpushed (`git log origin/<old>..<old>` is empty) and isn't checked out in a worktree. |
| `<default>: diverged` / `not updated` | local commits or uncommitted changes | Report; never pull, rebase or stash for them. |
| `submodule: <path> not updated: …` | after the fast-forward, that submodule wasn't at its old pin or had changes | Report; leave it to the user. |
| `gone: a b` | local branches whose remote branch was deleted | Ask which to delete. Only on a yes: `git branch -D <name>` (squash merges make `-d` refuse). |
| `gone worktree: <branch> at <path>, clean` | a gone branch checked out in another worktree; it can't be deleted while checked out | Check the PR is merged (`gh pr view <branch> --json state` says `MERGED`): a deleted remote branch may also mean a closed PR. Then ask, saying that removing the worktree deletes its folder, including ignored files such as build output; only on a yes: `git worktree remove <path>`, then `git branch -D <branch>`. Never `--force`. |
| `gone worktree: …, uncommitted changes` | the same, with changes or untracked files in the worktree | Report; leave it to the user. `git worktree remove` refuses it anyway. |
| `guard: <path> needs …=never` | a shared store could prune objects its borrowers need | Offer `git -C <path> config <key> never`; set it only on a yes. Say where it goes: that repo's own config (`.git/config`, or `<repo>/.git/modules/<path>/config` for a submodule), never `~/.gitconfig`. A fresh clone loses it, and the next sync flags it again. |
| `not shared: <submodule> <sha>` | that commit is stored in the borrowing copy, not the shared store | Say the shared repo is behind; already-downloaded objects stay where they are. |

## Never

- Delete branches, set config or change anything else without the user's yes.
- Run `gc`, `prune` or `repack` in a shared repo, or `submodule update --recursive` anywhere.
- Change submodule pins or check out branches. The script only moves already-initialized submodules to the pins the default branch records.
- Initialize submodules: some are left uninitialized on purpose.
