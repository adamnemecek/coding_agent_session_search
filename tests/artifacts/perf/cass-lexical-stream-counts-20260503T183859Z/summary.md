# CASS Lexical Rebuild Planner Streamed Message Counts

Timestamp: 2026-05-03T18:38:59Z

## Compared Change

- Current code path: `3020bf4c perf(storage/lexical-rebuild): stream message counts instead of GROUP BY`
- Prior baseline: `b97033a2 perf(storage): reject slow summary footprint scan`
- Workload: `cass index --watch-once /home/ubuntu/.codex/sessions/2026/05/02/rollout-2026-05-02T18-41-41-019deada-cd88-74e3-b215-90094437fbc0.jsonl --data-dir <fresh copy> --json --progress-interval-ms 5000 --color=never`
- Binary: `/data/tmp/cass-target-summary-footprints-20260503/profiling/cass`
- Environment: `CASS_RESPONSIVENESS_DISABLE=1 CASS_PREP_PROFILE=1`, guarded by `timeout 140s`

## Result

| Metric | Baseline (`b97033a2`) | Streamed counts (`3020bf4c`) |
| --- | ---: | ---: |
| Exit status | 0 | 0 |
| CLI elapsed | 115116 ms | 77156 ms |
| Wall time | 1:56.69 | 1:18.76 |
| `plan_lexical_shards` | 42825 ms | 2702 ms |
| Peak RSS | 54747148 KB | 40636436 KB |

## Notes

- The streamed-count path removed roughly 40.1 seconds from shard planning on the large rebuild fixture.
- The full workload improved by roughly 37.9 seconds wall-clock despite concurrent machine load in the 16-24 load-average range during indexing.
- Peak RSS dropped by roughly 14.1 GB.
- After this change, the remaining visible time is dominated by the lexical rebuild packet/build/merge/publish path rather than startup shard planning.

## Evidence Files

- `summary-fast.stderr.txt`: CASS progress and `CASS_PREP_PROFILE` timings.
- `summary-fast.time.txt`: `/usr/bin/time -v` resource summary.
- `summary-fast.out.json`: final robot JSON output.
