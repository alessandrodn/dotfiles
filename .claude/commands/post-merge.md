---
description: Clean up after a PR is merged — checkout main, pull, delete the feature branch, prune origin, and update submodules.
---

## Your Task

Run the following post-merge cleanup steps in order.

## Steps

1. **Record the current branch name** so it can be deleted after switching away.
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

2. **Checkout the main branch**
   ```bash
   git checkout main
   ```

3. **Pull latest changes**
   ```bash
   git pull
   ```

4. **Delete the feature branch** (use the name recorded in step 1).
   ```bash
   git branch -d <branch>
   ```
   If the branch was not fully merged according to git (e.g. squash-merged), use `-D` instead and inform the user.

5. **Prune stale remote-tracking references**
   ```bash
   git remote prune origin
   ```

6. **Update submodules**
   ```bash
   git submodule update --init --recursive
   ```

## Expected Outcome

- You are now on `main` with the latest changes.
- The merged feature branch has been removed locally.
- Stale remote refs have been pruned.
- All submodules are up to date.

Report what was done. If there are no submodules, skip step 6 silently.
