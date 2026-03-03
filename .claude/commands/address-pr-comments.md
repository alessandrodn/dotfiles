---
description: Fetch unresolved PR review comments, present them for decision, implement agreed changes, commit, push, reply to each comment thread, and resolve it.
argument-hint: "<pr-number>"
---

Address all unresolved review comments on a GitHub PR. The PR number may be passed as $ARGUMENTS; if omitted, use the current branch's open PR.

Follow these steps in order:

## 1. Fetch unresolved threads

Use the GitHub GraphQL API to get all review threads on the PR, filtering to `isResolved: false`. For each thread, also retrieve any replies so you can see if the author has already commented.

```
gh api graphql -f query='{ repository(owner: "...", name: "...") { pullRequest(number: N) { reviewThreads(first: 50) { nodes { id isResolved comments(first: 10) { nodes { author { login } body reactions(first: 20) { nodes { content user { login } } } } } } } } } }'
```

## 2. Present the list

Show the user a numbered list of unresolved threads. For each one include:
- The file and line (if applicable)
- The reviewer's comment (truncated to ~150 chars)
- Any reply already left by the author, clearly marked
- Emoji reactions on each comment, grouped by type with a count (e.g. 👍 3, 👀 1)

## 3. Get decisions

For each thread, read available signals to determine the author's intent:
- **Emoji reaction** on the comment left by the author: 👍 → Fix, 👎 → Won't fix
- **Author's reply** in the thread: read the reply and infer intent from its meaning

Then, independently assess each reviewer comment on its technical merits. Consider: Is the feedback correct? Is there a better approach? Are there trade-offs worth surfacing? Form your own view separately from the author's signals.

Present the full list to the user with, for each thread:
1. **Your intent** (inferred from emoji/reply): Fix / Won't fix / Unclear
2. **Claude's take**: A brief, honest opinion on whether the reviewer's point is valid, partially valid, or incorrect — and why

Wait for the user to confirm or override each decision before proceeding.

## 4. Implement changes

Make all agreed code/doc changes across the relevant files.

## 5. Commit and push

Stage only the modified files (never `git add -A` blindly). Create a single commit covering all the changes, then push.

Commit message format:
```
<ticket>: Address PR review comments

<brief bullet list of what was changed>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Extract the ticket prefix from the branch name (e.g. `feature/fs-3679-...` → `FS-3679`).

## 6. Update PR description

Review the PR description and update it if the changes made in step 4 affect what was previously described. Use `gh pr edit --body "..."` to update. Only update if the description is outdated or incomplete relative to the new state of the PR.

## 7. Reply and resolve

For every thread (whether fixed or won't-fix):
1. Post a reply in the thread explaining what was done (or why it was not actioned)
2. Resolve the thread via the GraphQL `resolveReviewThread` mutation

Per project memory: always reply **in the comment thread** (not as a top-level PR comment), then resolve.
