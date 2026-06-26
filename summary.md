# PR #3491 — "Static mcp" (docker/sandboxes)

**Status:** ✅ MERGED 2026-06-16 by `rcjsuen` · Author: `slimslenderslacks` (Jim Clark)
**Base:** `main` ← `static-mcp` · **+1840 / −157** across 22 files · **CI: all green**

## What it does

Introduces `--static-mcp`, a creation-time flag that pins a sandbox to a fixed set of
MCP servers and disables dynamic discovery — replacing the old `--mcp` flag. The MCP
gateway now *always* starts when `SBX_MCP_URL` is set. Passing `--static-mcp a,b,c`
selects **static mode** (no discovery, pre-loaded set, `mcp-find`/`mcp-add` hidden);
omitting it leaves the sandbox in the default **dynamic mode** (catalog searchable,
discovery tools exposed). It also splits `sbx mcp` into **register** (`sbx mcp add`)
and **attach-to-running-sandbox** (`sbx mcp load --sandbox`), the latter propagating to
connected agents live via `tools/list_changed` with no agent restart.

## Key changes by area

- **CLI** (`run.go`, `create.go`, `agent.go`, `mcp_setup.go`): `--static-mcp` as a
  deduplicated/validated comma list; field rename `mcpServers → staticMCPServers`;
  hard error if `--static-mcp` is passed when re-attaching an existing sandbox; unknown
  server names error rather than silently skip.
- **Live attach** (`mcp.go`): `sbx mcp add` = register-only; `sbx mcp load --sandbox` =
  attach a registered server (remote via `cp.AddServer`, local-stdio via
  `Gateway.AddBackend`) to a running gateway.
- **Gateway plumbing** (`sandboxd/.../mcp_gateway.go` +565, `mcp_gateway_store.go`,
  `sandboxlib/runtime/mcp.go`): static/dynamic mode threaded through `provisionCPGateway`
  into `DiscoveryMode`/`SessionMode`; new `/mcp/gateway/servers` live-add endpoint.
- **Tests**: substantial new unit coverage — `mcp_gateway_static_test.go` (+538),
  `mcp_setup_test.go` (+119), `mcp_gateway_test.go` (+138), `mcp_load_test.go` (+44).
- **Docs**: `mcp-runbook.md` / `mcp-integration*.md` refreshed; CLI yaml regen.
- **Dependency**: bumps `github.com/docker/mcpruntime` to a published pseudo-version
  (`v0.0.0-20260614213328-e8967776666f`). The local `replace => ../mcpruntime`
  directive that earlier reviews flagged was removed before merge.

## Review history & resolved findings

Long review cycle (Jun 10–16) with Copilot + 3 human members (`kgprs`, `saucow`,
`rcjsuen`). Substantive issues raised **and fixed during the PR**:
- ✅ Local `replace ../mcpruntime` in go.mod removed (was a CI/reproducibility blocker).
- ✅ Static mode now **persisted to gateway state** so re-attach / daemon-restart restores
  static mode (originally it silently flipped to dynamic on re-attach).
- ✅ Live-add now writes through to the persisted store (not memory-only).
- ✅ `--static-mcp all` removed (a "fixed set" + a moving `all` were contradictory).
- ✅ Name-mismatch validation, error-wrapping on failed propagation, doc/example fixes.
- ✅ **Policy seam verified clean** (`saucow`): static set + live-add both route tool
  calls through the gateway-level Cedar policy interceptor — no enforcement bypass. This
  was the one thing that could have blocked; it was clean.

## Risks / things to scrutinize (open at merge — non-blocking follow-ups)

1. **Degraded-create loses the pin** (`kgprs`/`saucow`, medium): the persisted static set
   is the *connected* set, not the *requested* set. If the Hub token can't be resolved at
   create time (a tolerated condition), a `--static-mcp notion,atlassian` sandbox persists
   an empty/local-only `PreConnect`, so the next re-attach silently demotes to **dynamic**
   — defeating the hardening it was added for. Reviewers approved with this as a follow-up.
2. **`sbx mcp rm` of a pinned server** (`kgprs`): the restore path hard-errors (400) on a
   since-removed name, and run.go only `slog.Warn`s on re-attach → sandbox quietly runs
   with **no MCP gateway at all**. Suggested graceful degrade not yet done.
3. **Doc/comment drift**: a couple of comments still claim behavior the code doesn't do
   (e.g. "full catalog searchable" in dynamic mode actually excludes local-stdio; static
   validator "accepts both names" when it rejects divergent ones).
4. **Cloud guard flag name** (Copilot, run.go:174): worth confirming the cloud-only
   rejection list was rekeyed from `mcp` → `static-mcp` so `--static-mcp --cloud` isn't
   silently accepted. The PR body says `cloud_dispatch_cloud.go` was updated; verify the
   test covers it.

## CI status

All ~60 checks **pass** (unit, integration on linux/darwin/windows, full E2E matrix,
CodeQL, Semgrep, poutine, zizmor, build-binaries). Only `skipping` entries are
conditional build jobs. Note the `otto:failed` label on the PR — stale/automation label,
not reflected in the actual check runs.

## Recommendation

**Already merged — retrospective: sound merge.** Clean CLI→sandboxd→CP layering, hard-error
validation over silent skips, strong test coverage, and the security-critical policy seam
was independently verified. Two member approvals (`rcjsuen`, `saucow`). The open items are
genuine but correctly triaged as **non-blocking degraded-path follow-ups** — file
follow-up issues for (1) requested-vs-connected persistence and (2) `sbx mcp rm` of a
pinned server, since both can silently strip MCP from a sandbox the user explicitly hardened.
