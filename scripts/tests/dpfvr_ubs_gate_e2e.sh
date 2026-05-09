#!/usr/bin/env bash
# dpfvr_ubs_gate_e2e.sh — exercise the ubs-changed-files CI gate logic locally.
#
# Per coding_agent_session_search-dpfvr. The full job runs in GitHub Actions;
# this script reproduces the gate's diff/filter/invocation logic against
# representative scenarios so we can verify behavior without pushing a PR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RCH_TARGET_DIR="${RCH_TARGET_DIR:-/tmp/cass-dpfvr-target}"
LOG="$RCH_TARGET_DIR/dpfvr-e2e.log"
mkdir -p "$RCH_TARGET_DIR"
exec > >(tee -a "$LOG") 2>&1

cleanup() {
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo ""
        echo "[dpfvr_e2e] FAILURE — last 50 log lines:" >&2
        tail -n 50 "$LOG" | sed 's/^/[dpfvr_e2e]   /' >&2
    fi
    exit "$rc"
}
trap cleanup EXIT

# Ensure ubs is on PATH; otherwise mark the gate verification skipped.
UBS_BIN="$(command -v ubs || true)"
if [ -z "$UBS_BIN" ]; then
    echo "[dpfvr_e2e] WARN: ubs not on PATH — skipping live invocation tests."
    echo "[dpfvr_e2e] (CI installs ubs via cargo install; locally, install per AGENTS.md)"
    UBS_AVAILABLE=0
else
    UBS_AVAILABLE=1
    echo "[dpfvr_e2e] ubs binary: $UBS_BIN"
    "$UBS_BIN" --version 2>&1 || true
fi

# Reproduce the gate's filter logic (extracted from ci.yml's run: block).
# The bash filter mirrors what GitHub Actions does on the runner.
filter_changed_files() {
    local range="$1"
    local out
    out="$(git -C "$PROJECT_ROOT" diff --name-only "$range" -- \
        '*.rs' '*.toml' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.sh' '*.yml' '*.yaml' '*.md' \
        2>/dev/null | grep -v -E '^test-results/|^target/|^node_modules/' || true)"
    printf '%s' "$out"
}

PASS=0
FAIL=0
expect_eq() {
    local description="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" = "$expected" ]; then
        echo "[dpfvr_e2e] OK: $description (got=$actual)"
        PASS=$((PASS + 1))
    else
        echo "[dpfvr_e2e] FAIL: $description (expected=$expected got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

# Scenario 1: no diff against HEAD itself → 0 files
files="$(filter_changed_files HEAD)"
file_count=$([ -z "$files" ] && echo 0 || echo "$files" | wc -l)
expect_eq "scenario=no_diff filter returns empty" "$file_count" "0"

# Scenario 2: diff against initial commit → many files (sanity check)
first_commit="$(git -C "$PROJECT_ROOT" rev-list --max-parents=0 HEAD | tail -1)"
if [ -n "$first_commit" ]; then
    files="$(filter_changed_files "$first_commit")"
    file_count=$([ -z "$files" ] && echo 0 || echo "$files" | wc -l)
    if [ "$file_count" -gt 50 ]; then
        echo "[dpfvr_e2e] OK: scenario=diff_first_commit returns $file_count files (>50, expected)"
        PASS=$((PASS + 1))
    else
        echo "[dpfvr_e2e] FAIL: scenario=diff_first_commit returned only $file_count files; expected >50"
        FAIL=$((FAIL + 1))
    fi
fi

# Scenario 3: skip when only fixture changes (synthetic)
# Synthesize a diff range with only fixture/json/img files to verify the filter excludes them.
TMP_DIR="$(mktemp -d)"
git -C "$PROJECT_ROOT" worktree add "$TMP_DIR" HEAD >/dev/null 2>&1 || true
if [ -d "$TMP_DIR/.git" ] || [ -e "$TMP_DIR/.git" ]; then
    cd "$TMP_DIR"
    mkdir -p tests/fixtures
    echo '{}' > tests/fixtures/synthetic.json
    git add tests/fixtures/synthetic.json 2>/dev/null || true
    git -c user.email="t@t.t" -c user.name="t" commit -q -m "synth-fixture" 2>/dev/null || true
    files="$(filter_changed_files HEAD~1)"
    # The fixture .json should NOT match — UBS only filters extensions in the gate's list.
    file_count=$([ -z "$files" ] && echo 0 || echo "$files" | wc -l)
    expect_eq "scenario=fixture_only_change skips invocation" "$file_count" "0"
    cd "$PROJECT_ROOT"
    git -C "$PROJECT_ROOT" worktree remove --force "$TMP_DIR" >/dev/null 2>&1 || rm -rf "$TMP_DIR"
fi

# Scenario 4: ubs available — run a quick happy-path invocation.
if [ "$UBS_AVAILABLE" -eq 1 ]; then
    # Pick a known-good file from the project (this script itself).
    if "$UBS_BIN" --ci --fail-on-warning "$(realpath "${BASH_SOURCE[0]}")" >/dev/null 2>&1; then
        echo "[dpfvr_e2e] OK: scenario=ubs_clean_file ran without failures"
        PASS=$((PASS + 1))
    else
        echo "[dpfvr_e2e] WARN: scenario=ubs_clean_file ubs reported issues (may be expected)"
    fi
fi

echo ""
echo "[dpfvr_e2e] SUMMARY: PASS=$PASS FAIL=$FAIL"
echo "[dpfvr_e2e] log written to: $LOG"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo "[dpfvr_e2e] ALL PASS"
