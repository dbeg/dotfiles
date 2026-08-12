# AGENTS.md

## Think Before Coding

If multiple interpretations of a request exist, present them - don't pick one silently.

## Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## Goal-Driven Execution

State success criteria before multi-step work, and prefer a failing test as the
criterion where one is practical:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Track the steps with the todo tooling rather than restating a plan inline. If
you're stuck or going in circles, stop and ask.

## Git

- Use conventional commits: `type(scope): subject`, <72 chars, lowercase, no trailing period; body wrapped at 80; write the *why*.
- Add a `Co-Authored-By:` trailer to commit messages when you materially authored the work; skip it for mechanical edits. Your judgment call.
- NEVER push unless I explicitly ask. Leave work on the branch for me to review locally.
- Never discard, commit, or revert changes you did not make (checkout/restore/reset/clean/stash on my work, rm on files you didn't create). Exception: gitignored/build artifacts.
- Prefix editor-opening git commands with `GIT_EDITOR=true`.
- Clone over SSH (`git@github.com:...`), never HTTPS.

## Worktrees

- Use `wt switch --create <branch>` for isolated feature work (worktrunk handles naming).
- Never run the merge/squash-to-trunk command without my explicit approval, and never push the result.

## Pull requests

- Don't open PRs unless I ask.
- When I ask: one-line conventional-commit-style title; body is a few sentences of prose — why the change exists, what it fixes, review context. A list of edited files is not useful.
- Never edit a PR you did not open.
- Base branch: check `.wt-base-branch` in the main working directory, else `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, else ask.

## Tooling

- Temp files and extractions go in `/tmp/opencode` — your scoped, permissioned temp dir (allow-listed in opencode.jsonc). Create a unique subdirectory per task (`mkdir -p /tmp/opencode && mktemp -d /tmp/opencode/XXXXXX`). Never use the working or home directory.
- Prefer `rg` over `grep`.
- Prefer mise-managed tooling for dev CLIs. Never install dev tooling globally (`npm install -g`, `brew install` for a tool mise tracks, curl'd binaries). Prompt the user to add recurring tools in the global or project mise config.
- Run tools via the mise shims already on PATH. Use `mise exec <tool>@<ver> -- <cmd>` to pin a one-off version; respect the project/mise default rather than hardcoding one.
