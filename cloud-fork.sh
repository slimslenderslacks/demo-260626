#!/usr/bin/env bash
#
# cloud-fork.sh — Fan out PR analysis across cloud sandboxes.
#
# Finds the 6 most recent PRs in docker/sandboxes (via the local gh CLI),
# then opens a tmux session named "demo" with 6 tiled panes. Each pane runs
# a Claude session inside a cloud sandbox analyzing one of those PRs.
#
# Usage:
#   cloud-fork.sh                   Launch the analysis session.
#   cloud-fork.sh -s <sandbox-id>   Use a specific cloud sandbox (default below,
#                                   or set the SBX_SANDBOX env var).
#   cloud-fork.sh --ps              List the processes running in the sandbox.
#                                   Honors -s / SBX_SANDBOX too.
#   cloud-fork.sh --kill            Tear down: kill the tmux session AND the
#                                   remote claude analyses in the sandbox.
#                                   Honors -s / SBX_SANDBOX too.
#   cloud-fork.sh -h                Show this help.

set -euo pipefail

REPO="docker/sandboxes"
SESSION="demo"
NUM_PRS=6

# Cloud sandbox to run the analyses in. Override with --sandbox/-s <id> or the
# SBX_SANDBOX env var; the value below is just the default.
SANDBOX="${SBX_SANDBOX:-sbx_001kvxxm48mwhcjjq7dcacynads}"
MODE="launch"   # set to "kill" by --kill

# Initial detached session size. Must be big enough to tile NUM_PRS panes,
# otherwise split-window fails with "no space for new pane". 80x24 (the
# default for a detached session) only fits ~4 tiled panes.
INIT_W=250
INIT_H=60

# --- Preflight ---------------------------------------------------------------

command -v gh   >/dev/null 2>&1 || { echo "error: gh CLI not found"   >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "error: tmux not found"      >&2; exit 1; }
command -v sbx  >/dev/null 2>&1 || { echo "error: sbx CLI not found"   >&2; exit 1; }

# --- Teardown ----------------------------------------------------------------

# Kill the local tmux session and the remote analyses. Killing the tmux panes
# only terminates the local `sbx exec` clients — the `claude` processes keep
# running inside the cloud sandbox — so we also pkill them there.
kill_all() {
    echo "Killing tmux session '$SESSION' ..." >&2
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    echo "Killing remote claude analyses in $SANDBOX ..." >&2
    # Match on the unique prompt text so we only kill these PR analyses (and
    # not any unrelated claude session in the sandbox). Also sweep up any
    # go build/vet jobs the analyses may have spawned. `sbx exec` returns
    # non-zero when the process tree it attached to is torn down by the
    # pkill; that's expected, so don't let it abort the script.
    sbx --cloud exec "$SANDBOX" sh -c "pkill -9 -f 'analysis of the PR docker/sandboxes'; pkill -9 -f 'go build'; pkill -9 -f 'go vet'" || true

    echo "Verifying ..." >&2
    sbx --cloud exec "$SANDBOX" sh -c \
        "(pgrep -af 'analysis of the PR docker/sandboxes|go build|go vet' | grep -v pgrep) || echo ALL_CLEAR"
}

# List the processes currently running in the sandbox. Tries a few ps variants
# so it works whether the image ships full procps or busybox.
ps_all() {
    echo "Processes in $SANDBOX:" >&2
    sbx --cloud exec "$SANDBOX" sh -c \
        "ps -ef 2>/dev/null || ps aux 2>/dev/null || ps"
}

# --- Parse arguments ---------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kill|-k)
            MODE="kill"
            shift
            ;;
        --ps)
            MODE="ps"
            shift
            ;;
        --sandbox|-s)
            [[ $# -ge 2 ]] || { echo "error: $1 requires a sandbox id" >&2; exit 1; }
            SANDBOX="$2"
            shift 2
            ;;
        --sandbox=*|-s=*)
            SANDBOX="${1#*=}"
            shift
            ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "error: unknown argument '$1' (try --help)" >&2
            exit 1
            ;;
    esac
done

echo "Using sandbox: $SANDBOX" >&2

if [[ "$MODE" == "kill" ]]; then
    kill_all
    exit 0
fi

if [[ "$MODE" == "ps" ]]; then
    ps_all
    exit 0
fi

# Command template run in each pane. %s is replaced with a PR number. Built
# after arg parsing so it picks up any --sandbox override.
#
# We run Claude's interactive TUI (NOT `-p` print mode): the prompt is passed
# as the initial query, and each pane shows the live, human-readable session
# as Claude works. Print mode (`-p`) either buffers silently until done, or
# with stream-json dumps raw JSON events — neither is watchable in a demo.
CMD_TEMPLATE='sbx --cloud exec -it '"$SANDBOX"' claude --dangerously-skip-permissions "do an analysis of the PR docker/sandboxes#%s"'

# --- Find the most recent PRs ------------------------------------------------

echo "Fetching the $NUM_PRS most recent PRs from $REPO ..." >&2
mapfile -t PRS < <(gh pr list --repo "$REPO" --limit "$NUM_PRS" \
    --state all --json number --jq '.[].number')

if [[ ${#PRS[@]} -eq 0 ]]; then
    echo "error: no PRs found in $REPO" >&2
    exit 1
fi

echo "Analyzing PRs: ${PRS[*]}" >&2

# --- Build the tmux session --------------------------------------------------

# Start fresh: kill any existing "demo" session.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Window 0, pane 0 runs the first PR. Create the session large enough to
# tile all panes.
first_cmd=$(printf "$CMD_TEMPLATE" "${PRS[0]}")
tmux new-session -d -s "$SESSION" -n analysis -x "$INIT_W" -y "$INIT_H" "$first_cmd"

# Keep panes visible after their command exits, so completed (or failed)
# analyses don't vanish. remain-on-exit is a WINDOW option, so it must be set
# with -w against the window (setting it on the session is a silent no-op and
# lets dead panes close, which collapses the whole server once all are gone).
tmux set-option -w -t "$SESSION":analysis remain-on-exit on

# Add one pane per remaining PR, re-tiling after each split so each
# split has room.
for pr in "${PRS[@]:1}"; do
    cmd=$(printf "$CMD_TEMPLATE" "$pr")
    if ! tmux split-window -t "$SESSION":analysis "$cmd"; then
        echo "warning: could not add pane for PR #$pr (window too small)" >&2
        break
    fi
    tmux select-layout -t "$SESSION":analysis tiled
done

# Final tiled layout across all panes.
tmux select-layout -t "$SESSION":analysis tiled

# Dismiss the one-time "Bypass Permissions mode" acceptance dialog that the
# interactive TUI shows on first run (option 2 = "Yes, I accept"). Give the
# TUI a moment to render before sending the keystroke.
sleep 5
for pane in $(tmux list-panes -t "$SESSION":analysis -F '#{pane_index}'); do
    tmux send-keys -t "$SESSION":analysis."$pane" 2 Enter
done

echo "tmux session '$SESSION' is ready with ${#PRS[@]} tiled panes." >&2
echo "Attach with: tmux attach -t $SESSION" >&2

# Attach automatically when run interactively.
if [[ -t 1 ]]; then
    tmux attach -t "$SESSION"
fi
