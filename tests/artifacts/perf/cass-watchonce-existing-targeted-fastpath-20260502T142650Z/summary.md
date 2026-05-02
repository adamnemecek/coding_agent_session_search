# cass watch-once existing-path targeted checkpoint fast path

Workload:

```text
/data/tmp/cass_perf_opt_target/profiling/cass index --watch-once \
  /home/ubuntu/.codex/sessions/2025/12/17/rollout-2025-12-17T16-36-28-019b2e3e-3972-7390-b77f-a90f83498bff.jsonl \
  --data-dir /home/ubuntu/<run_id> --json --progress-interval-ms 5000
```

Seed: `/home/ubuntu/cass-post-tokenizer-hotspot-20260502T035907Z`

## Result

| Run | JSON elapsed_ms | wall | max RSS KB | FS inputs | Notes |
| --- | ---: | ---: | ---: | ---: | --- |
| `cass-watchonce-existing-profile-20260502T134112Z` | 105550 | 1:46.88 | 28246664 | 31778840 | baseline on `01a44183` |
| `cass-watchonce-existing-targeted-fastpath-20260502T142650Z` | 49944 | 0:50.14 | 15633088 | 31693400 | this patch |

The JSON output is behavior-equivalent after deleting volatile `elapsed_ms`, `data_dir`, and `db_path`.

The original run spent 39.235s and 26.051s inside `fingerprint_messages`, plus 39.276s in the first aggregate `compute_storage_fingerprint`. The final run emits no `CASS_PREP_PROFILE` fingerprint lines and enters the watch-once callback at 2.501s. The remaining cost is now inside the explicit-path reindex/ingest path.

An intermediate `MAX(id)`-only run (`cass-watchonce-existing-max-fingerprint-20260502T141040Z`) was rejected as insufficient: it still took 105294ms and kept the slow message fingerprint scans.
