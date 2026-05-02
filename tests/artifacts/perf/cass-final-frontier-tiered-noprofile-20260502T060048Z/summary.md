# CASS lexical rebuild final-frontier tiered publish perf slice

Date: 2026-05-02

## Workload

- Command shape: `cass index --watch-once <nonexistent> --data-dir <seeded-data-dir> --json --progress-interval-ms 10000`
- Seed database: `/home/ubuntu/cass-post-tokenizer-hotspot-20260502T035907Z/agent_search.db*`
- Corpus: 51,214 conversations / 4,711,686 messages
- Binary: `/tmp/cass_perf_opt_target/profiling/cass`

## Baseline

Artifact: `tests/artifacts/perf/cass-final-default-summary-merge8-seeded-20260502T053345Z`

- `elapsed_ms`: 90,863
- Wall time: 1:31.67
- Full corpus reached: 34,624 ms
- Phase returned to preparing: 85,259 ms
- Max RSS: 60,317,720 KB
- File system outputs: 26,406,672 KB

## Final candidate

Artifact: `tests/artifacts/perf/cass-final-frontier-tiered-noprofile-20260502T060048Z`

- `elapsed_ms`: 45,932
- Wall time: 0:47.33
- Full corpus reached: 34,523 ms
- Phase returned to preparing: 42,329 ms
- Max RSS: 60,555,364 KB
- File system outputs: 17,469,360 KB

## Delta

- Total `elapsed_ms`: 49.4% faster (`90,863 -> 45,932`)
- Wall time: 48.4% faster (`91.67s -> 47.33s`)
- Full-corpus handoff: unchanged (`34.624s -> 34.523s`)
- Post-handoff tail: 84.4% faster (`56.239s -> 8.806s`, measured as `elapsed_ms - full-corpus handoff`)
- RSS: essentially unchanged (`60,317,720 KB -> 60,555,364 KB`)
- File system outputs: 33.8% lower (`26,406,672 KB -> 17,469,360 KB`)

## Interpretation

The previous slice made final publish federated, but the rebuild still compacted
the residual final frontier down to the eager merge fan-in before publish. That
was foreground compaction on the critical path. The new policy treats the final
frontier as a bounded tiered publish: publish up to 32 already-validated
artifacts directly as one federated bundle, and only pay worker reduction for
larger frontiers.

## Behavior proof

- Ordering preserved: yes. Final artifacts are still sorted by shard range before publish.
- Document set preserved: yes. The same validated artifacts are published; they are just not remerged when the residual frontier is bounded.
- Query smoke: `function` on the candidate and baseline both returned `total_matches=241394` with the same top 5 hits.
- Fallback: frontiers above `LEXICAL_REBUILD_FINAL_FRONTIER_FEDERATED_SHARD_LIMIT` still use the old worker reduction path.

## Verification

- `cargo test -q lexical_rebuild_final_frontier_reduction_only_runs_above_federated_publish_cap --lib`
- `cargo test -q rebuild_tantivy_from_db_publishes_bounded_final_frontier_without_reduction --lib`
- `cargo test -q reduce_staged_lexical_final_merge_frontier_via_workers_reduces_large_frontier_to_single_artifact --lib`
- `cargo fmt --check`
- `cargo check --all-targets`
- `cargo clippy --all-targets -- -D warnings`
- Search smoke against baseline and candidate data dirs for `function`
