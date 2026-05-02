# cass watch-once missing-path fast path

## Scenario

`cass index --watch-once <missing path> --data-dir <valid populated data dir> --json`

The data dir was reflinked from `/home/ubuntu/cass-post-tokenizer-hotspot-20260502T035907Z`
and includes a valid canonical DB plus a valid lexical index. The explicit
watch-once path does not exist. Expected output is a successful zero-result
watch-once response.

## Baseline

Artifact: `tests/artifacts/perf/cass-watchonce-missing-profile-20260502T124110Z/`

- Git SHA: `56280c141fe16e3892d786c4c615e6c57b73f5fe`
- JSON `elapsed_ms`: `79150`
- `/usr/bin/time` wall: `1:19.56`
- Max RSS: `13,921,544 KB`
- File system inputs: `31,765,552`
- CASS prep profile:
  - `compute_storage_fingerprint`: `47,320 ms`
  - later `fingerprint_messages`: `27,027 ms`
- Output: `success=true`, `conversations=0`, `messages=0`

## Candidate

Artifact: `tests/artifacts/perf/cass-watchonce-missing-fastpath-current-20260502T133535Z/`

- Git SHA: `56280c141fe16e3892d786c4c615e6c57b73f5fe` plus local fast-path patch
- JSON `elapsed_ms`: `600`
- `/usr/bin/time` wall: `0:00.70`
- Max RSS: `842,932 KB`
- File system inputs: `24,776`
- Output: `success=true`, `conversations=0`, `messages=0`

Normalized output comparison:

```bash
diff -u \
  <(jq 'del(.elapsed_ms,.data_dir,.db_path)' tests/artifacts/perf/cass-watchonce-missing-profile-20260502T124110Z/index.out.json) \
  <(jq 'del(.elapsed_ms,.data_dir,.db_path)' tests/artifacts/perf/cass-watchonce-missing-fastpath-current-20260502T133535Z/index.out.json)
```

Result: no diff.

## Opportunity Matrix

| Hotspot | Impact | Confidence | Effort | Score | Evidence |
|---|---:|---:|---:|---:|---|
| Message fingerprinting before explicit absent watch-once path handling | 5 | 5 | 1 | 25.0 | baseline stderr CASS_PREP_PROFILE lines |

## Isomorphism Proof

- Ordering preserved: yes. No paths exist, so no conversations can be scanned or indexed.
- Tie-breaking unchanged: N/A. No search/index results are produced.
- Floating-point: N/A.
- RNG seeds: unchanged.
- Golden output: normalized JSON is identical except `elapsed_ms`, `data_dir`, and `db_path`.
- Guard rails: shortcut is disabled for `--watch`, `--full`, `--force-rebuild`, `--semantic`, `--build-hnsw`, empty watch-once path lists, existing paths, mixed existing/missing batches, paths whose existence check returns an error, missing/unreadable/non-current canonical DBs, missing lexical indexes, schema-mismatched lexical indexes, and lexical indexes that cannot be opened for summary.
