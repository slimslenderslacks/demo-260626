---
name: notion-report
description: Compile a change report and publish it to Notion. Gathers recent merged changes, writes a human-friendly summary, and posts it to a Notion page or database. Use when asked to generate or publish a change report to Notion.
---

# notion-report

Read a PR change report from summary.md in the root of the workspace. Summarize the work publish it the Notion page titled "AI Tools Weekly Pull Requests".

## Steps

1. read the PR summary in summary.md in the workspace root.
3. Write the report in a style that will be useful to our Product team:
   - **Headline** — the one or two changes that matter most.
   - **Highlights** — user-facing changes in plain language.
   - **Details** — grouped list with PR/commit links.
4. Publish to the "AI Tools Weekly Pull Requests" Notion page via the Notion MCP server (create or append to the
   target page/database).

## Output

A published Notion page (return its URL) plus a short confirmation of what
was posted and the window it covered.
