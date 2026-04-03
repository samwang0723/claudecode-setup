---
name: pr-comments
description: >
  Review and address PR review comments. Fetches comments from a GitHub PR,
  presents them in a structured table, and asks the user which to address
  before making any code changes. Use when the user says "check PR comments",
  "address review feedback", "fix PR comments", or "pr-comments".
user-invocable: true
---

# PR Comments

Fetch, review, and optionally address PR review comments with user approval.

## Arguments

Parse the user's input after `/pr-comments`:

| Input | Action |
|-------|--------|
| `<number>` | Use PR #number in the current repo |
| `<owner/repo#number>` | Use a specific repo's PR |
| _(empty)_ | Auto-detect from current branch (`gh pr view --json number`) |

## Process

### Step 1: Resolve the PR

```bash
# If no PR number given, detect from current branch:
gh pr view --json number,title,url --jq '{number: .number, title: .title, url: .url}'

# If PR number given:
gh pr view <number> --json number,title,url --jq '{number: .number, title: .title, url: .url}'
```

If no PR is found, tell the user and stop.

### Step 2: Fetch review comments

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --jq '.[] | {
  id: .id,
  path: .path,
  line: (.line // .original_line),
  author: .user.login,
  body: .body,
  created: .created_at
}'
```

Also fetch PR review body comments (top-level review summaries):

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[] | select(.body != "") | {
  id: .id,
  author: .user.login,
  state: .state,
  body: .body
}'
```

If no comments found, tell the user "No review comments found on PR #N" and stop.

### Step 3: Present the table

Display ALL comments in a numbered table for the user to review:

```
PR #134: feat: add prompt injection guard
https://github.com/owner/repo/pull/134

| # | File:Line | Author | Comment (summary) | Suggestion? |
|---|-----------|--------|-------------------|-------------|
| 1 | guard.go:78 | reviewer | Merge hits instead of picking by length | Yes |
| 2 | pipeline.go:91 | reviewer | Hardcoded English for blocked queries | No |
| 3 | search.go:91 | reviewer | Return value type instead of pointer | Yes |
...
```

For each comment:
- Summarize the feedback in ~10-15 words (not the full comment body)
- Note if it includes a code suggestion (`suggestion` block)
- Group by file if there are many comments

### Step 4: ASK the user (MANDATORY)

**DO NOT start coding. Ask the user first:**

```
Which comments should I address? Options:
- "all" — address every comment
- "1,3,5" — address specific numbers
- "skip" — skip, don't change anything
- "1,3,5 skip 2,4" — address some, explicitly skip others
```

Wait for the user's response before proceeding.

### Step 5: Address selected comments

For each comment the user selected:

1. **Read the file** at the referenced path and line
2. **Read the full comment body** (not just the summary) to understand the exact ask
3. **Apply the fix** — if a `suggestion` block exists, prefer using it as-is
4. **Verify the fix compiles** — run `go build ./...` (or equivalent for the language)

After ALL selected fixes are applied:

### Step 6: Run verification (MANDATORY)

**MUST run tests before committing.** Choose based on what changed:

| What changed | Verification command |
|-------------|---------------------|
| Go code | `go test -race ./path/to/changed/package/...` |
| Python scripts | `python3 scripts/<changed_script>.py` (if it has a test mode) |
| Any Go code | `go build ./...` (at minimum) |
| Search logic | `python3 scripts/eval_accuracy.py` if available |
| Project has `make test` | `make test` |

If the project has a `/regression` skill, suggest running it.

Report test results to the user. If tests fail, fix before committing.

### Step 7: Commit and push

Only after tests pass:

```bash
git add <changed files>
git commit -m "fix: address PR #N review comments — <brief summary>"
git push
```

## Rules

- **NEVER start coding without user approval** — Step 4 is mandatory
- **NEVER skip verification** — Step 6 is mandatory
- Present comments neutrally — don't pre-judge which are important
- If a comment is unclear or you disagree with it technically, flag it in the table with a note and let the user decide
- Keep the commit message concise — reference the PR number and summarize what changed
- If the PR has both inline comments and top-level review comments, show both
- Ignore bot comments that are just CI status reports (e.g., "Build passed", coverage reports)
