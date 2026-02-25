---
name: review-copilot-comments
description: Triage GitHub Copilot code review comments on the current PR — address the ones worth fixing, dismiss the rest with an explanation
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(gh pr view*), Bash(gh pr list*), Bash(gh api*), Bash(git diff*), Bash(git log*), Bash(git show*), Bash(git rev-parse*)
user-invocable: true
---

# Review Copilot Comments

Fetch all GitHub Copilot code review comments on the current PR. For each comment, decide whether it is worth addressing. Fix the ones that are. Reply to all of them, then resolve the dismissed threads.

## Step 1: Identify the current PR

```bash
gh pr view --json number,headRefName,baseRefName,url,title
```

If this fails (not in a git repo, or no open PR for the current branch), stop and tell the user.

Extract the **owner/repo** slug:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

## Step 2: Fetch Copilot's review comments

Fetch all inline review comments on the PR and filter to Copilot's:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --paginate \
  --jq '[.[] | select(.user.login | test("copilot"; "i"))]'
```

Also fetch top-level (non-inline) review body comments from Copilot:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --paginate \
  --jq '[.[] | select(.user.login | test("copilot"; "i"))]'
```

If Copilot has left no comments at all, report: "No Copilot review comments found on this PR." and stop.

Build a working list of all Copilot comments, noting for each:
- `id` — comment ID (needed for replies)
- `path` — file path (inline comments only)
- `line` / `original_line` — line number (inline comments only)
- `body` — the comment text
- `in_reply_to_id` — if set, this is a follow-up in an existing thread (skip: only process root comments)
- `pull_request_review_id` — the review this comment belongs to

**Skip** any comment that already has a reply from a non-Copilot human — it has already been triaged.

## Step 3: Understand the changeset

To evaluate comments in context, fetch the PR diff:

```bash
git diff origin/{baseRefName}...HEAD
```

Read any files that Copilot commented on so you have the full current content, not just the diff hunk.

## Step 4: Triage each comment

For each root Copilot comment, decide: **Address** or **Dismiss**.

### Address if the comment identifies:
- A genuine bug, logic error, or incorrect assumption in the code
- A security vulnerability (injection, improper auth, unsafe deserialization, etc.)
- Missing or incorrect error handling for a real failure mode
- An API contract violation (wrong status code, missing validation, broken return shape)
- A correctness issue where the code will silently produce wrong results
- A resource leak or missing cleanup

### Dismiss if the comment is:
- A style/formatting suggestion — assume a formatter and linter handle this
- A naming preference with no correctness impact
- A suggestion to add unrelated features or expand the PR's scope
- Advice that conflicts with an established pattern in the codebase (check the surrounding code)
- A false positive where the bot misread the code or misunderstood the intent
- A suggestion already handled elsewhere in the PR or in a prior review cycle
- An overly pedantic observation with no practical benefit

When in doubt, **err on the side of addressing**. The cost of a small fix is low; the cost of a silent bug is high.

## Step 5: Address the comments worth fixing

For each **Address** comment:

1. Read the full file at the commented path.
2. Implement the fix using Edit or Write. Keep the fix minimal — only change what the comment requires.
3. Note what you changed (you'll include this in your reply).

If multiple comments touch the same file, batch the reads and edits.

## Step 6: Reply to every comment

After all fixes are applied, post a reply to **every** root Copilot comment.

### For an addressed comment:
```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  -X POST \
  -f body="Fixed — <one-sentence description of what changed>."
```

### For a dismissed comment:
```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  -X POST \
  -f body="Dismissing — <one-sentence reason: e.g., 'handled by the project formatter', 'conflicts with the existing pattern in X', 'false positive: the nil case cannot occur here because Y', etc.>."
```

Keep replies short and factual. Do not be defensive.

## Step 7: Resolve dismissed threads via GraphQL

For each **dismissed** comment, attempt to resolve its thread. This requires the thread's GraphQL node ID.

First, fetch the thread IDs for the PR:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { databaseId }
            }
          }
        }
      }
    }
  }
' -f owner="{owner}" -f repo="{repo}" -F pr={pr_number}
```

Match each dismissed comment's `id` (the `databaseId`) to a thread node. For each unresolved dismissed thread:

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -f threadId="{thread_node_id}"
```

If the GraphQL call fails (permissions, token scope, etc.), skip silently — the reply already communicates the dismissal; thread resolution is a best-effort courtesy.

## Step 8: Report

Print a summary to the user:

```
## Copilot Comment Triage — PR #{number}

**Total Copilot comments**: N

### Addressed (N)
- `path:line` — <comment summary> → <fix description>
- ...

### Dismissed (N)
- `path:line` — <comment summary> → <reason for dismissal>
- ...

### Skipped (N — already had human replies)
- `path:line` — <comment summary>
- ...
```

If all comments were dismissed, note that no code was changed. If all were addressed, note that all have been fixed and replied to.
