---
name: address-pr-comments
description: Fetch unresolved PR review comments, present them for decision, implement and commit the agreed changes, then, after a final confirmation, push, update the PR description, reply in each thread and resolve it. Use when the user asks to address, handle or resolve review comments on a PR.
---

Address all unresolved review comments on a GitHub PR. Use the PR number the user gave; if none, use the current branch's open PR.

Follow these steps in order:

## 1. Fetch unresolved threads

Find the PR. If there is no PR, say so and stop.

```
gh pr view [<number>] --json number,url,author,headRefName --jq '"\(.number) \(.url) \(.author.login) \(.headRefName)"'
```

Take `<owner>` and `<repo>` from the URL (`https://github.com/<owner>/<repo>/pull/<number>`), so they name the repo the PR lives in, even from a fork. `<remote>` is the local remote that holds `<headRefName>`, usually `origin`.

Fetch its review threads with the GraphQL API. While `hasNextPage` is true, repeat with `-F after=<endCursor>`:

```
gh api graphql -f owner=<owner> -f name=<repo> -F number=<number> -f query='
query($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 50, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved path line
          comments(first: 100) {
            totalCount
            nodes { author { login } body reactions(first: 20) { nodes { content user { login } } } }
          }
        }
      }
    }
  }
}'
```

Keep the threads with `isResolved: false`: the API can't filter them. If a thread's `totalCount` is over 100, say that its later comments weren't read. If no thread is unresolved, say so and stop.

## 2. Present the list

Show the user a numbered list of unresolved threads. For each one include:
- The file and line (if applicable)
- The reviewer's comment (truncated to ~150 chars)
- Any reply already left by the PR author (the login from `gh pr view`), clearly marked
- Emoji reactions on each comment, grouped by type with a count (e.g. 👍 3, 👀 1). The API returns names: `THUMBS_UP` 👍, `THUMBS_DOWN` 👎, `LAUGH` 😄, `HOORAY` 🎉, `CONFUSED` 😕, `HEART` ❤️, `ROCKET` 🚀, `EYES` 👀.

## 3. Get decisions

For each thread, read available signals to determine the author's intent:
- **Emoji reaction** left by the PR author on the comment: `THUMBS_UP` 👍 → Fix, `THUMBS_DOWN` 👎 → Won't fix
- **Author's reply** in the thread: read the reply and infer intent from its meaning

Then, independently assess each reviewer comment on its technical merits. Consider: Is the feedback correct? Is there a better approach? Are there trade-offs worth surfacing? Form your own view separately from the author's signals.

Present the full list to the user with, for each thread:
1. **Author intent (inferred)** from the reaction or reply: Fix / Won't fix / Unclear
2. **Agent's take**: A brief, honest opinion on whether the reviewer's point is valid, partially valid, or incorrect — and why

Wait for the user to confirm or override each decision before proceeding.

## 4. Implement changes

Make all agreed code/doc changes across the relevant files.

## 5. Commit locally

Stage only the modified files (never `git add -A` blindly). Make one small commit per concern, each building on its own. Don't push yet.

Write each headline in the repo's convention: check `git log --oneline -10` and any contributing guide. Add a ticket only where the convention uses one and the branch name has it (e.g. `feature/abc-123-...` → `ABC-123`).

## 6. Draft the PR description update and the replies

Always review the PR description against the full set of changes the PR will have (original + changes from step 4). Draft an update if anything is outdated, missing, or no longer accurate. Keep the repo's PR template if it has one. This step is mandatory: do not skip it even if you expect no changes.

Draft a reply for every thread: what was done, or why it was not actioned.

## 7. Confirm

Show the user, together:
- the new commits: `git fetch <remote> <headRefName>`, then `git log -p FETCH_HEAD..HEAD`
- the PR description change, as a diff, or "no change"
- each reply draft, and whether its thread will be resolved: fixed threads yes; won't-fix threads only if the user says so, otherwise the reviewer resolves them

Wait for a yes. Apply any edits the user asks for and show them again.

## 8. Push and publish

1. Push with `git push <remote> HEAD:<headRefName>`. If it is rejected because the PR branch moved, stop and tell the user. Never force-push.
2. If the description changed, write it to a file and run `gh pr edit <number> --body-file <file>`. A file avoids shell quoting problems with backticks or `$`.
3. For each thread, reply **in the thread**, never as a top-level PR comment. Write the reply to a file:
   ```
   gh api graphql -F threadId=<id> -F body=@<file> -f query='
   mutation($threadId: ID!, $body: String!) {
     addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) { comment { url } }
   }'
   ```
4. Resolve the threads agreed in step 7:
   ```
   gh api graphql -F threadId=<id> -f query='
   mutation($threadId: ID!) { resolveReviewThread(input: {threadId: $threadId}) { thread { isResolved } } }'
   ```
