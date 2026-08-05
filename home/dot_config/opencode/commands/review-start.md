---
description: Analyze a commit, branch, PR, or local diffs for bugs and quality issues (plan mode only)
---

**This command is for plan mode only.** Do not post any inline comments or make
any write calls to the GitHub API. Read-only calls (`gh pr view`, `gh pr diff`,
`gh api` GET requests) are expected. Present all findings in the chat.
When analysis is complete, tell the user to switch to build mode and run
`/review-submit` when ready to post.

Use TodoWrite for visual tracking of the overall review, tool calls, next steps, etc.

---

Input: $ARGUMENTS

---

## Determining What to Review

Based on the input provided, determine which type of review to perform:

1. **No arguments (default)**: Review all uncommitted changes
   - Run: `git diff` for unstaged changes
   - Run: `git diff --cached` for staged changes
   - Run: `git status --short` to identify untracked (net new) files

2. **Commit hash** (40-char SHA or short hash): Review that specific commit
   - Run: `git show $ARGUMENTS`

3. **Branch name**: Compare current branch to the specified branch
   - Run: `git diff $ARGUMENTS...HEAD`

4. **PR URL or number** (contains "github.com" or "pull" or looks like a PR
   number): Review the pull request
   - Run: `gh pr view $ARGUMENTS --json number,title,author,headRefOid,baseRefName`
     to get PR context. Note the PR author's login, and retain `headRefOid` —
     `/review-submit` needs it as the review's `commit_id`.
   - Run: `gh pr diff $ARGUMENTS` to get the diff
   - Fetch existing inline review thread comments:
     ```sh
     gh api repos/{owner}/{repo}/pulls/<number>/comments --paginate \
       --jq '.[] | {user: .user.login, path, line, body}'
     ```
   - Fetch issue-style PR comments:
     ```sh
     gh api repos/{owner}/{repo}/issues/<number>/comments --paginate \
       --jq '.[] | {user: .user.login, body}'
     ```
   - Fetch review summary bodies. These are a separate endpoint from the two
     above and are easy to miss — findings with no natural line anchor
     (missing tests, architectural notes, CI observations) live here, so
     skipping this means re-raising them on every run:
     ```sh
     gh api repos/{owner}/{repo}/pulls/<number>/reviews --paginate \
       --jq '.[] | select(.body != "") | {user: .user.login, body}'
     ```
   - The `{owner}`/`{repo}` placeholders resolve from the current directory. If
     the PR lives in a different repo, pass `-R OWNER/REPO` explicitly.
   - Filter out any comments or review bodies where `user` matches the PR
     author's login — these are not considered "already raised" issues
   - Retain the remaining comments and review bodies as the **external
     reviewer comments** list for use during analysis

Use best judgement when processing input.

---

## Gathering Context

**Diffs alone are not enough.** After getting the diff, read the entire file(s)
being modified to understand the full context. Code that looks wrong in
isolation may be correct given surrounding logic — and vice versa.

- Use the diff to identify which files changed
- Use `git status --short` to identify untracked files, then read their full
  contents
- Read the full file to understand existing patterns, control flow, and error
  handling
- Check for existing style guide or conventions files (CONVENTIONS.md,
  AGENTS.md, .editorconfig, etc.)

---

## What to Look For

**Bugs** - Your primary focus.
- Logic errors, off-by-one mistakes, incorrect conditionals
- If-else guards: missing guards, incorrect branching, unreachable code paths
- Edge cases: null/empty/undefined inputs, error conditions, race conditions
- Security issues: injection, auth bypass, data exposure
- Broken error handling that swallows failures, throws unexpectedly or returns
  error types that are not caught

**Structure** - Does the code fit the codebase?
- Does it follow existing patterns and conventions?
- Are there established abstractions it should use but doesn't?
- Excessive nesting that could be flattened with early returns or extraction

**Performance** - Only flag if obviously problematic.
- O(n²) on unbounded data, N+1 queries, blocking I/O on hot paths

**Behavior Changes** - If a behavioral change is introduced, raise it
(especially if it's possibly unintentional).

**Test Coverage** - Note any changed behavior that lacks a corresponding
new or updated test. Flag missing coverage for edge cases explicitly
introduced by the diff.

**Already Raised** - When reviewing a PR, compare each finding against the
external reviewer comments list. If a finding semantically overlaps with an
existing comment — same conceptual concern, same file, or same code location,
even if worded differently or pointing to a nearby line — tag it as
**already raised** and record which reviewer raised it (`@username`). Use
judgment: "already raised" means the concern has genuinely been surfaced, not
just that a comment exists in the same file.

---

## Before You Flag Something

**Be certain.** If you're going to call something a bug, you need to be
confident it actually is one.

- Only review the changes — do not review pre-existing code that wasn't modified
- Don't flag something as a bug if you're unsure — investigate first
- Don't invent hypothetical problems — if an edge case matters, explain the
  realistic scenario where it breaks
- If you need more context to be sure, use the tools below to get it

**Don't be a zealot about style.** When checking code against conventions:

- Verify the code is *actually* in violation. Don't complain about else
  statements if early returns are already being used correctly.
- Some "violations" are acceptable when they're the simplest option.
- Excessive nesting is a legitimate concern regardless of other style choices.
- Don't flag style preferences as issues unless they clearly violate established
  project conventions.

---

## Tools

Use these to inform your review:

- **Explore agent** - Find how existing code handles similar problems. Check
  patterns, conventions, and prior art before claiming something doesn't fit.
- **Web Search** - Research best practices if you're unsure about a pattern.

If you're uncertain about something and can't verify it with these tools, say
"I'm not sure about X" rather than flagging it as a definite issue.

---

## Output

Present findings in the chat:

1. Summarize what was reviewed (PR title, branch, commit, or "local changes")
2. List findings grouped by severity — bugs first, then structure, then minor
3. For each finding: explain the issue, the realistic scenario where it breaks,
   and a suggested fix if obvious
4. If there is a bug, be direct and clear about why it is a bug — but frame as
   a question where possible ("Could this return null if the list is empty?")
5. Clearly communicate severity. Do not overstate.
6. AVOID flattery. Do not give comments that are not helpful to the reader.

When done, remind the user:
> Switch to build mode and run `/review-submit [approve|request-changes]`
> (default is a neutral comment) to post the review to GitHub.
> If you reviewed local diffs rather than a PR, have the target PR
> number or URL ready.

---

## Output: Already Raised by Other Reviewers

After the severity-grouped findings, add a separate section for any findings
tagged as already raised:

```
### Already Raised by Other Reviewers

These issues were found during analysis but have already been noted by other
reviewers. They will be posted to GitHub with an attribution label.

- [Issue summary] — already noted by @reviewer ([file or thread reference])
```

Always include this section in the chat output even if it means repeating
findings — the user needs full visibility. Keep the "already raised" findings
out of the severity-grouped sections so the distinction is clear.
