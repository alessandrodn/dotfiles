---
name: post-merge
description: Clean up a local repo after the current branch's PR is merged — switch to the default branch, pull, delete the merged branch, prune remote refs, and update submodules. Use when the user says their PR or branch was merged and wants to clean up, or asks for post-merge cleanup.
---

Run the bundled script from the repository root:

```bash
scripts/post-merge.sh
```

(`scripts/` is next to this file; use its full path.)

The script exits with:

- **0**: done. Report its output to the user.
- **1**: it refused or failed; nothing was deleted. Report the message. Fix the cause only if the user asks (for example, commit or stash uncommitted changes).
- **2**: it couldn't confirm the branch was merged (no merge commit in the default branch and `gh` doesn't report the PR as merged), so it changed nothing. Tell the user and ask whether to delete the branch anyway. Only if they confirm, rerun it with `--force`.

Don't run the steps by hand instead of the script.
