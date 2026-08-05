---
description: Submit a review to GitHub based on findings from /review-start (build mode only)
---

**This command is for build mode only.** It submits the review findings
already in context from `/review-start`. If you have no findings in context
(i.e. `/review-start` was not run in this session), stop and tell the user to
run `/review-start` first.

Use TodoWrite for visual tracking of the overall review, tool calls, next steps, etc.

---

Input: $ARGUMENTS (optional — `approve`, `request-changes`, or empty for neutral comment)

Default event: `COMMENT` if no argument is provided.

---

## Before Submitting

1. **Determine the target PR.**
   - If `/review-start` was run against a PR URL or number, use that PR.
   - If `/review-start` was run against local diffs, a branch, or a commit,
     ask the user for the target PR number or URL before proceeding.

2. **Confirm the event type.**
   - `approve` → `APPROVE`
   - `request-changes` → `REQUEST_CHANGES`
   - anything else or empty → `COMMENT`

3. **Get the head commit SHA.**
   - Reuse `headRefOid` from `/review-start` if it is in context.
   - Otherwise run `gh pr view <number> --json headRefOid --jq .headRefOid`.

---

## Submission Rules

These rules apply without exception:

- **Assemble the complete review payload before calling the API.** The review is
  submitted in a single atomic request — there is no pending-review state to
  build up incrementally.

- **Write the payload to a JSON file** under `/tmp/opencode/pr-review/`. Create
  the directory first — it is pruned automatically once empty, so do not assume
  it exists:

  ```sh
  mkdir -p /tmp/opencode/pr-review
  ```

  Write the payload to `/tmp/opencode/pr-review/<repo>-<number>.json`,
  substituting the real repo name and PR number (e.g. `my-service-42.json`),
  then submit it:

  ```sh
  gh api repos/{owner}/{repo}/pulls/<number>/reviews \
    --method POST --input /tmp/opencode/pr-review/<repo>-<number>.json
  ```

  Note that `gh` expands `{owner}` and `{repo}` **only in the API endpoint
  argument**. In `--input` the path is an ordinary filename — substitute the
  values yourself or the file will not be found.

  Use `-R OWNER/REPO` if the PR is not in the current directory.

  Payload shape:

  ```json
  {
    "commit_id": "<head sha>",
    "event": "COMMENT",
    "body": "Beep boop, ...",
    "comments": [
      { "path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "Could this return null?" }
    ]
  }
  ```

- **Post code-level feedback as inline comments** in the `comments` array,
  anchored to the nearest sensible file and line in the diff. Use the top-level
  `body` for findings that have no natural file/line anchor (architectural
  notes, missing tests, CI observations, etc.).

- **`line` must refer to a line present in the PR diff.** For multi-line
  comments use `start_line` plus `line`. `side` is `RIGHT` for added/context
  lines and `LEFT` for removed lines.

- **If the call returns `422`**, one or more comment anchors are invalid. The
  request is all-or-nothing, so nothing was posted — including the valid
  comments in the same payload.

  The error body will not tell you which comment failed. GitHub returns only:

  ```json
  {"message":"Unprocessable Entity","errors":["Line could not be resolved"],"status":"422"}
  ```

  No path, no line, no array index. So re-validate every anchor yourself
  against the diff: each `line` must fall inside a hunk range shown in
  `gh pr diff`, and each `path` must be a file the PR actually touches.
  Context lines outside a hunk will fail even though the file is in the diff.

  Move any finding you cannot confidently anchor into the top-level `body`,
  then resubmit. Do not retry blindly.

- **Prefix the review body with exactly:**
  > Beep boop, this review was co-authored by an agent and mistakes might have
  > been made. ✨

- **Postfix the review body with:**
  A topical (related to the content of the PR) inspirational quote or joke
  that is funny, a bit on the nose, like a pun or dad-joke.

- **Tone:** Keep it light and inquisitive. Frame feedback as questions or
  observations ("Could this cause X if Y?" / "I wonder if...") rather than
  directives or blame. Be direct about bugs, but never accusatory.

- **For findings tagged as already raised** (from `/review-start`): include them
  as inline comments anchored to the appropriate file/line, but prefix the
  comment body with:
  > _(Already raised by @username)_

  Do not factor already-raised findings into the review event decision
  (`APPROVE` / `REQUEST_CHANGES` / `COMMENT`) — only new findings should
  influence the verdict.

## After Submitting

- **Do not delete the payload file.** These are retained as a local audit trail
  of submitted reviews, and are pruned automatically by macOS after 3 days.
- Provide a link in the output to the PR
- Provide a summary of the actions and tool calls you performed
- Provide a very brief summary of the overall review
