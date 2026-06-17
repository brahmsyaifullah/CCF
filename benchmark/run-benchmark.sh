#!/usr/bin/env bash
# =============================================================================
# CCF Benchmark — Sequential Data Collector
# =============================================================================
# Collects raw panelist responses for each benchmark task, SEQUENTIALLY.
# Does NOT do judgment/synthesis — that's the AI orchestrator's job via
# /fusion-benchmark or /fusion-benchmark-report slash commands.
#
# Usage:
#   ./run-benchmark.sh                    # collect all tasks, all panelists
#   ./run-benchmark.sh 01                 # just task 01
#   ./run-benchmark.sh 01 03              # tasks 01 and 03
#   ./run-benchmark.sh --list             # list available tasks + panelists
#
# Output: benchmark/results/raw-<task>-<panelist>.md
# =============================================================================
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_DIR="$BENCH_DIR/tasks"
RESULTS_DIR="$BENCH_DIR/results"
FUSION_HOME="${CLAUDE_HOME:-$HOME/.claude}/fusion"
FUSION_CALL="$FUSION_HOME/fusion-call"
PANEL_JSON="$FUSION_HOME/panel.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[BENCH]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[BENCH]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[BENCH]${NC} $*" >&2; }
err()  { echo -e "${RED}[BENCH]${NC} $*" >&2; }

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
if [[ ! -x "$FUSION_CALL" ]]; then
    err "fusion-call not found at: $FUSION_CALL"
    err "Is CCF installed? Run the install script first."
    exit 1
fi

if [[ ! -f "$PANEL_JSON" ]]; then
    err "panel.json not found at: $PANEL_JSON"
    exit 1
fi

if [[ ! -d "$TASKS_DIR" ]]; then
    err "Tasks directory not found: $TASKS_DIR"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# -----------------------------------------------------------------------------
# Get enabled panelists
# -----------------------------------------------------------------------------
get_panelists() {
    jq -r '.panel[] | select(.enabled == true) | .name' "$PANEL_JSON"
}

PANELIST_COUNT=$(get_panelists | wc -l)
if [[ "$PANELIST_COUNT" -eq 0 ]]; then
    err "No enabled panelists in panel.json"
    err "Enable at least one: edit $PANEL_JSON"
    exit 1
fi

# -----------------------------------------------------------------------------
# Get available tasks
# -----------------------------------------------------------------------------
get_tasks() {
    find "$TASKS_DIR" -name '*.md' -type f | sort
}

# -----------------------------------------------------------------------------
# List mode
# -----------------------------------------------------------------------------
if [[ "${1:-}" == "--list" ]]; then
    echo "Available tasks:"
    get_tasks | while read -r f; do
        local_name=$(basename "$f")
        echo "  $local_name"
    done
    echo ""
    echo "Enabled panelists ($PANELIST_COUNT):"
    get_panelists | while read -r p; do
        model=$(jq -r --arg name "$p" '.panel[] | select(.name==$name) | .model' "$PANEL_JSON")
        echo "  $p ($model)"
    done
    echo ""
    echo "Results dir: $RESULTS_DIR"
    exit 0
fi

# -----------------------------------------------------------------------------
# Resolve which tasks to run
# -----------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    mapfile -t TASK_FILES < <(get_tasks)
else
    TASK_FILES=()
    for arg in "$@"; do
        # Match by number prefix (01, 02, etc.)
        matched=$(find "$TASKS_DIR" -name "${arg}-*.md" -o -name "0${arg}-*.md" 2>/dev/null | sort | head -1)
        if [[ -z "$matched" ]]; then
            # Try exact filename
            matched="$TASKS_DIR/$arg"
        fi
        if [[ -f "$matched" ]]; then
            TASK_FILES+=("$matched")
        else
            warn "Task not found: $arg (skipping)"
        fi
    done
fi

if [[ ${#TASK_FILES[@]} -eq 0 ]]; then
    err "No tasks to run."
    exit 1
fi

# -----------------------------------------------------------------------------
# Main loop — sequential
# -----------------------------------------------------------------------------
TOTAL_TASKS=${#TASK_FILES[@]}
TOTAL_CALLS=$((TOTAL_TASKS * PANELIST_COUNT))
COMPLETED=0
FAILED=0

log "CCF Benchmark Data Collection"
log "Tasks: $TOTAL_TASKS | Panelists: $PANELIST_COUNT | Total calls: $TOTAL_CALLS"
log "Mode: tasks SEQUENTIAL, panelists PARALLEL within each task"
log "Results: $RESULTS_DIR"
echo ""

START_TS=$(date +%s)
TASK_NUM=0

for task_file in "${TASK_FILES[@]}"; do
    task_name=$(basename "$task_file" .md)
    task_bench_id="${task_name%%-*}"  # e.g. "01" from "01-bug-fix"
    TASK_NUM=$((TASK_NUM + 1))

    log "=============================================="
    log "Task $TASK_NUM/$TOTAL_TASKS: $task_name  (launching $PANELIST_COUNT panelists in parallel)"
    log "=============================================="

    # Read the task prompt ONCE — every panelist gets the identical prompt
    PROMPT=$(cat "$task_file")

    # Launch every enabled panelist for THIS task concurrently.
    pids=(); pnames=(); pfiles=()
    while IFS= read -r panelist; do
        [[ -z "$panelist" ]] && continue

        model=$(jq -r --arg name "$panelist" '.panel[] | select(.name==$name) | .model' "$PANEL_JSON")
        output_file="$RESULTS_DIR/raw-${task_bench_id}-${panelist}.md"

        # Write header
        {
            echo "# Raw Panelist Response — Task ${task_bench_id} — ${panelist}"
            echo ""
            echo "> Model: ${model}"
            echo "> Panelist: ${panelist}"
            echo "> Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "> Mode: parallel-per-task data collection (no judgment)"
            echo ""
            echo "---"
            echo ""
        } > "$output_file"

        # Background the call; record its exit code to a sidecar .rc file.
        { "$FUSION_CALL" "$panelist" "$PROMPT" >> "$output_file" 2>&1; echo $? > "$output_file.rc"; } &
        pids+=("$!"); pnames+=("$panelist"); pfiles+=("$output_file")
        log "  -> launched $panelist ($model) [pid $!]"
    done < <(get_panelists)

    # Wait for ALL panelists of this task before moving to the next task.
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done

    # Tally results for this task from the sidecar files.
    for i in "${!pnames[@]}"; do
        panelist="${pnames[$i]}"; output_file="${pfiles[$i]}"
        rc=$(cat "$output_file.rc" 2>/dev/null || echo 1); rm -f "$output_file.rc"
        bytes=$(wc -c < "$output_file" 2>/dev/null || echo 0)
        if [[ "$rc" -ne 0 ]]; then
            err "  $panelist: FAILED (exit $rc)"; FAILED=$((FAILED + 1))
            { echo ""; echo "> ERROR: fusion-call exited $rc"; } >> "$output_file"
        elif [[ "$bytes" -lt 50 ]]; then
            warn "  $panelist: suspiciously short response (${bytes}B) — may have failed"; FAILED=$((FAILED + 1))
        else
            ok "  $panelist: OK (${bytes}B)"
        fi
        COMPLETED=$((COMPLETED + 1))
    done

    # Courtesy pause between TASKS (not between panelist calls within a task).
    if [[ $TASK_NUM -lt $TOTAL_TASKS ]]; then
        sleep 3
    fi

    echo ""
done

END_TS=$(date +%s)
TOTAL_DUR=$((END_TS - START_TS))

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
log "=============================================="
log "Benchmark data collection complete"
log "=============================================="
log "Tasks:     $TOTAL_TASKS"
log "Panelists: $PANELIST_COUNT"
log "Calls:     $COMPLETED total, $FAILED failed"
log "Duration:  ${TOTAL_DUR}s"
log "Results:   $RESULTS_DIR"
echo ""
if [[ $FAILED -gt 0 ]]; then
    warn "$FAILED call(s) failed. Check the raw-*.md files for details."
fi

ok "Next step: Run /fusion-benchmark-report in Claude Code to judge and grade"
ok "           the collected responses, or compare them manually with grade.md"
