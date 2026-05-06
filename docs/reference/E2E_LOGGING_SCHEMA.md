# E2E Logging Schema

Unified JSONL schema for all E2E test runs across Rust, Shell scripts, and Playwright.

## Overview

All E2E test infrastructure emits structured JSONL logs to `test-results/e2e/`.
Each line is a self-contained JSON object representing a single event.

## Output Files

| Runner | Output File |
|--------|-------------|
| Rust E2E tests | `test-results/e2e/rust_e2e_<timestamp>.jsonl` |
| Shell scripts | `test-results/e2e/shell_<script>_<timestamp>.jsonl` |
| Playwright | `test-results/e2e/playwright_<timestamp>.jsonl` |

## Common Fields (All Events)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | string | yes | ISO-8601 timestamp with milliseconds |
| `event` | string | yes | Event type (see Event Types below) |
| `run_id` | string | yes | Unique identifier for this test run |
| `runner` | string | yes | `"rust"`, `"shell"`, or `"playwright"` |

## Event Types

### `run_start`

Emitted once at the beginning of a test run.

```json
{
  "ts": "2026-01-26T12:00:00.000Z",
  "event": "run_start",
  "run_id": "20260126_120000_abc123",
  "runner": "rust",
  "env": {
    "git_sha": "abc123def",
    "git_branch": "main",
    "os": "linux",
    "arch": "x86_64",
    "rust_version": "1.84.0",
    "node_version": "24.12.0",
    "cass_version": "0.5.0"
  },
  "config": {
    "test_filter": "e2e_*",
    "parallel": true,
    "fail_fast": false
  }
}
```

### `test_start`

Emitted when a single test begins.

```json
{
  "ts": "2026-01-26T12:00:01.000Z",
  "event": "test_start",
  "run_id": "20260126_120000_abc123",
  "runner": "rust",
  "test": {
    "name": "test_pages_export_basic",
    "suite": "e2e_pages",
    "file": "tests/e2e_pages.rs",
    "line": 42
  }
}
```

### `test_end`

Emitted when a single test completes.

```json
{
  "ts": "2026-01-26T12:00:05.500Z",
  "event": "test_end",
  "run_id": "20260126_120000_abc123",
  "runner": "rust",
  "test": {
    "name": "test_pages_export_basic",
    "suite": "e2e_pages",
    "file": "tests/e2e_pages.rs",
    "line": 42
  },
  "result": {
    "status": "pass",
    "duration_ms": 4500,
    "retries": 0
  }
}
```

**Status values:** `pass`, `fail`, `skip`, `flaky`

### `test_end` (failure)

```json
{
  "ts": "2026-01-26T12:00:10.000Z",
  "event": "test_end",
  "run_id": "20260126_120000_abc123",
  "runner": "rust",
  "test": {
    "name": "test_pages_export_encrypted",
    "suite": "e2e_pages",
    "file": "tests/e2e_pages.rs",
    "line": 87
  },
  "result": {
    "status": "fail",
    "duration_ms": 8000,
    "retries": 1
  },
  "error": {
    "message": "assertion failed: expected 200, got 500",
    "type": "AssertionError",
    "stack": "at tests/e2e_pages.rs:95\n  at ..."
  }
}
```

### `run_end`

Emitted once at the end of a test run with summary statistics.

```json
{
  "ts": "2026-01-26T12:05:00.000Z",
  "event": "run_end",
  "run_id": "20260126_120000_abc123",
  "runner": "rust",
  "summary": {
    "total": 25,
    "passed": 23,
    "failed": 1,
    "skipped": 1,
    "flaky": 0,
    "duration_ms": 300000
  },
  "exit_code": 1
}
```

### `log`

General log message (info, warn, error, debug).

```json
{
  "ts": "2026-01-26T12:00:02.500Z",
  "event": "log",
  "run_id": "20260126_120000_abc123",
  "runner": "shell",
  "level": "INFO",
  "msg": "Building cass binary...",
  "context": {
    "phase": "setup",
    "command": "cargo build --release"
  }
}
```

**Level values:** `DEBUG`, `INFO`, `WARN`, `ERROR`

### `phase_start` / `phase_end`

For multi-phase test runs (setup, execution, teardown).

```json
{
  "ts": "2026-01-26T12:00:00.500Z",
  "event": "phase_start",
  "run_id": "20260126_120000_abc123",
  "runner": "playwright",
  "phase": {
    "name": "global_setup",
    "description": "Building exports and starting preview server"
  }
}
```

### `artifact`

References to generated artifacts (screenshots, logs, exports).

```json
{
  "ts": "2026-01-26T12:00:10.000Z",
  "event": "artifact",
  "run_id": "20260126_120000_abc123",
  "runner": "playwright",
  "artifact": {
    "type": "screenshot",
    "name": "test-failed-1.png",
    "path": "test-results/e2e/screenshots/test-failed-1.png",
    "test_name": "encryption-password-flow"
  }
}
```

## Environment Object

The `env` object in `run_start` captures reproducibility metadata:

| Field | Type | Description |
|-------|------|-------------|
| `git_sha` | string | Current Git commit SHA (short) |
| `git_branch` | string | Current Git branch name |
| `os` | string | Operating system (`linux`, `darwin`, `windows`) |
| `arch` | string | CPU architecture (`x86_64`, `aarch64`) |
| `rust_version` | string? | Rust version if applicable |
| `node_version` | string? | Node.js version if applicable |
| `cass_version` | string | cass binary version |
| `ci` | bool | True if running in CI environment |

## Aggregation

The `scripts/tests/run_all.sh` runner (P6.14j) aggregates all JSONL files:

1. Concatenates all `*.jsonl` files into `test-results/e2e/combined.jsonl`
2. Generates `test-results/e2e/summary.md` with pass/fail table
3. Exits non-zero if any `run_end` has `exit_code != 0`

## Parsing Examples

```bash
# Count failures
jq -s '[.[] | select(.event == "test_end" and .result.status == "fail")] | length' test-results/e2e/*.jsonl

# Get failed test names
jq -r 'select(.event == "test_end" and .result.status == "fail") | .test.name' test-results/e2e/*.jsonl

# Total duration by runner
jq -s 'group_by(.runner) | map({runner: .[0].runner, total_ms: [.[] | select(.event == "run_end") | .summary.duration_ms] | add})' test-results/e2e/*.jsonl
```

## Backward Compatibility

Existing log formats in `test-logs/` and `target/e2e-cli/` remain unchanged.
This unified schema supplements (not replaces) those formats for CI integration.
