---
name: research-pr
description: Research a pull request — gather the diff, linked issues, CI status, and prior discussion, then summarize what the PR does and what to scrutinize. Use when asked to research, investigate, or review a PR.
---

# research-pr

Research a pull request and produce a summary.md file in the root of workspace.

## Steps

1. Identify the target PR (number, URL, or current branch).
2. Gather context with `gh`:
   - `gh pr view <pr> --json title,body,author,files,additions,deletions,labels`
   - `gh pr diff <pr>` for the actual changes
   - `gh pr checks <pr>` for CI status
   - Linked issues and prior review comments.
3. Summarize:
   - **What it does** — one paragraph.
   - **Key changes** — bullet list by file/area.
   - **Risks / things to scrutinize** — correctness, tests, scope.
   - **CI status** — passing/failing and why.
   - **Issues** - identify an issues that are either closed or related issues that remain open

## Output

A short markdown report the reviewer can read in under a minute, ending
with a clear recommendation (approve / request changes / needs discussion).
