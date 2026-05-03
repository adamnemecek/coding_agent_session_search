# CASS Lexical Rebuild Eager Merge Fan-In 8

Timestamp: 2026-05-03T19:06:15Z

## Compared Change

- Candidate: `LexicalRebuildShardMergeCoordinator::EAGER_MERGE_FAN_IN = 8`
- Baseline: streamed message-count planner at `3020bf4c`
- Workload: `cass index --watch-once /home/ubuntu/.codex/sessions/2026/05/02/rollout-2026-05-02T18-41-41-019deada-cd88-74e3-b215-90094437fbc0.jsonl --data-dir <fresh copy> --json --progress-interval-ms 5000 --color=never`
- Binary: `/data/tmp/cass-target-summary-footprints-20260503/profiling/cass`
- Environment: `CASS_RESPONSIVENESS_DISABLE=1 CASS_PREP_PROFILE=1`, guarded by `timeout 140s`

## Result

| Metric | Baseline fan-in 4 | Fan-in 8 |
| --- | ---: | ---: |
| Exit status | 0 | 0 |
| CLI elapsed | 77156 ms | 56848 ms |
| Wall time | 1:18.76 | 0:58.15 |
| `plan_lexical_shards` | 2702 ms | 2786 ms |
| Peak RSS | 40636436 KB | 40547200 KB |
| File system outputs | 22266016 | 14641104 |

## Notes

- The perf sample from `cass-lexical-perf-record-20260503T184343Z` showed the remaining CPU concentrated in staged Tantivy merge workers, especially `tantivy::indexer::merger::IndexMerger::write`.
- Raising eager merge fan-in from 4 to 8 reduces repeated merge levels while keeping the final federated frontier under the existing cap.
- The measured workload improved by roughly 20.3 seconds CLI elapsed and 20.6 seconds wall-clock.
- File system outputs dropped by roughly 34%, consistent with fewer intermediate merge artifacts.

## Evidence Files

- `fanin8.stderr.txt`: CASS progress and `CASS_PREP_PROFILE` timings.
- `fanin8.time.txt`: `/usr/bin/time -v` resource summary.
- `fanin8.out.json`: final robot JSON output.
