# Rehearsal report — Cartwheel demo environment
Status: READY

Core investigation (Prompts 1-4) is fully verified and solid, and is
the entire demo tonight. Updated 2026-09-09: David has cut Prompt 5
(the branch-fix stretch) from tonight's run of show entirely, based on
firsthand experience that Supabase branch creation/access is too high
in average latency, variance, and outright-failure rate for live use,
stretch slot or not. The `checkout-fix` branch is left alone (not
deleted) but plays no part in tonight's demo. Only remaining item is
housekeeping (deleting two stale Supabase projects), which David is
handling manually and doesn't block the demo.

**Environment (put this where you can find it, not just in your head):**
Supabase org `supabase-demo` (Enterprise plan), project **cartwheel-demo-2**,
ref `gbdrmmptjvxlmxmcblqe`. Pre-created branch **checkout-fix**, ref
`rwfbdnnfbwlhvocregxy`, clean/unfixed, ready for the live stretch.
Full connection details and the `pm_agent` password are in
`secrets.local.md` (untracked, local only).

## The three numbers (for David to memorize)
- p99 checkout latency: **6,634 ms** (~6.6s)
- Users affected: **200** (4.0%)
- Largest cart row: **627 kB** (642,551 bytes, pg_column_size)

## Acceptance criteria

| #  | Criterion                                                                                              | Measured value                                                                                                                                                                                              | Result                                    |
|----|--------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|
| A1 | Bimodality: p50≤160ms, p96≥2000ms, 0 requests in (300,1500)ms                                          | p50=114ms, p96=4,499ms, gap_count=0                                                                                                                                                                         | PASS                                      |
| A2 | Cohort size: 200±5 users with any checkout ≥2000ms                                                     | 200 exactly                                                                                                                                                                                                 | PASS                                      |
| A3 | Smoking gun: max pg_column_size ≥500KB; top 200 by size = exactly the power users                      | max=642,551B (627kB); 0 mismatches in top-200/power-user set                                                                                                                                                | PASS                                      |
| A4 | Red herring flat: slow-cohort region/plan shares within ±6pp of population                             | max diff: region 1.64pp, plan 1.04pp                                                                                                                                                                        | PASS                                      |
| A5 | Correlation: slow min events≥2000, fast max≤50, no overlap                                             | slow min=2,028, fast max=49, zero overlap                                                                                                                                                                   | PASS                                      |
| A6 | Noise floor: all non-checkout endpoints max ≤150ms                                                     | max=139ms across all 4 paths                                                                                                                                                                                | PASS                                      |
| A7 | Role safety: pm_agent read-only + 10s timeout                                                          | Verified via live psql session (Supavisor pooler): SELECT works on all 5 tables, INSERT fails ("cannot execute INSERT in a read-only transaction"), statement_timeout=10s, default_transaction_read_only=on | PASS                                      |
| A8 | Fix works on branch: counts preserved, avg row <200B, index scan on cart_events_cart_id_created_at_idx | Events: 951,158 = 951,158 exactly. Avg row size: 64 bytes post-fix+VACUUM FULL (see caveat below). EXPLAIN: "Index Scan Backward using cart_events_cart_id_created_at_idx", ~13ms                           | PASS (migration file amended — see below) |
| A9 | Live-query latency <3s                                                                                 | Heaviest verification queries: 3.3ms and 9.4ms via EXPLAIN ANALYZE; every query in the suite returned in single-digit-to-low-double-digit ms                                                                | PASS                                      |

## Timings
- Seed wall-clock: **~41 seconds** (final method: `01_setup.sql` applied via `apply_migration`, which is what makes it branch-replayable — see "surprised you" below for why this matters more than the raw-SQL number)
- Branch create: **3m23s and 4m17s** across two clean attempts (after fixing the migration-drift issue). Every attempt before that failed outright with an empty schema.
- Migration on branch: **~51 seconds** (create table + backfill ~951K rows + drop column), plus a VACUUM FULL that ran fast (not separately timed — clearly not the bottleneck next to the multi-minute branch creation)
- **Stretch go/no-go: CUT, decided by David on 2026-09-09.** My original measurement-based recommendation was GO-with-a-pre-created-branch (3-4+ min branch creation is infeasible live, but a pre-created branch plus ~55-60s to apply+verify the fix would have fit in a slightly extended stretch window). David overrode this with firsthand experience that Supabase branching has high variance and p95, and can fail outright — a risk this session's small sample size (two clean creates) couldn't see. The demo now ends after Prompt 4. `checkout-fix` stays pre-created and untouched (not deleted), in case a future event revisits the stretch.

## Changes made to package files (diff-level, with rationale)

**`01_setup.sql`** — two changes, both because the first seed failed acceptance:

1. Added a second `md5` field (`'trace'`) to each cart event object.
   *Why:* A3 failed on the first seed — max compressed cart size was
   408KB, short of the 500KB bar. TOAST/lz4 compresses the repetitive
   parts of the event JSON (keys, UA string, viewport) well; only the
   `session` md5 field resisted compression. A second incompressible
   md5 field pushed the max to 627-628KB. This is exactly §9's
   suggested contingency for this failure mode.

2. Power users now get 5 checkout attempts instead of 3
   (`case when user_id % 25 = 0 then 5 else 3 end`), framed as
   realistic retry behavior on a slow checkout.
   *Why:* A1 failed on the first seed — p96 was 166ms, not ≥2000ms.
   Root cause: with power users at *exactly* 4.0% of checkout
   requests, `percentile_disc(0.96)`'s rank (`ceil(0.96*N)`) landed
   exactly on the last normal-cohort value — an exact-tie edge case,
   not a "gap too narrow" problem. §9's suggested fix (raise the
   per-event coefficient to 1.5) would **not** have fixed this, since
   it only changes magnitude, not which cohort p96's rank falls into.
   Giving power users more checkout attempts (user *count* stays
   exactly 200, so A2 is untouched) breaks the tie by raising the slow
   fraction of *requests* to ~6.5%, giving p96 a comfortable margin.

**`03_fix_migration.sql`** — one change:

3. Added `vacuum full app.carts;` as its own statement after the
   `commit;` (VACUUM can't run inside a transaction block).
   *Why:* A8 failed on first run — the file's own suggested
   verification query (`avg(pg_column_size(c.*))`) reported ~20KB
   after the fix, looking like it hadn't worked. `DROP COLUMN` is
   metadata-only in Postgres; existing heap tuples keep their old
   physical bytes until a rewrite, and `pg_column_size` on a
   whole-row var reflects the actual on-disk tuple, not just the
   current column list. After VACUUM FULL, the same query correctly
   reports 64 bytes. Without this, running the live fix and then its
   own verification query would have shown a misleading number on
   screen.

**`demo_prompts.md`** — two changes, both decided by David at rehearsal
on 2026-09-09, not made unilaterally:

4. Prompt 4's `[TEAM NAME]` placeholder filled in as **Sandbox**. This
   is a real team in the connected Linear workspace (this is Supabase's
   actual internal Linear, not a fictional demo one), created for
   exactly this kind of throwaway/demo filing — using it avoids
   dropping a live-demo issue into a real product team's backlog.

5. Prompt 5 marked **cut for this event** entirely (not just
   reworded). *Why:* branch creation measured 3-4+ minutes in every
   attempt this session, and David independently confirmed from prior
   experience that Supabase branch creation has high variance/p95 and
   can fail outright — too flaky and slow for any live 8-minute demo
   slot, stretch or not. This supersedes an earlier, less conservative
   version of this same edit that had reworded Prompt 5 to target the
   pre-created branch instead of creating one; David's firsthand
   experience with branching flakiness overrode that. The
   `checkout-fix` branch stays pre-created in clean, unfixed state,
   untouched, for a possible future event.

No changes to `talk_track.md`, `hook_slide.html`, or `roundtable_prep.md`.

## Proposed prompt changes (NOT applied — David decides)

None outstanding — the two open items from the original rehearsal pass
(team name, Prompt 5 wording) were decided above.

## Anything that surprised you

- **Branches replay only tracked migrations, never live/raw-SQL
  data.** My first seed used raw SQL, not `apply_migration` — so the
  first branch came up with *no schema at all*. This would have
  broken Prompt 5 live regardless of plan tier. Fix: seed via
  `apply_migration` as the very first action on a fresh project.
- **An auto-generated `remote_schema` baseline migration** appeared
  after my first `apply_migration` call, capturing a snapshot that
  included `GRANT ... TO pm_agent` from an earlier raw-SQL role
  creation. Roles are cluster-level and don't exist on a fresh branch,
  so replaying that GRANT aborted the whole migration and the branch
  stayed empty. I tried surgically editing the recorded migration text
  directly in `supabase_migrations.schema_migrations` (with your
  sign-off) — that fixed the GRANT problem but exposed a second one:
  the seed migration's own `CREATE TABLE` statements then collided
  with tables `remote_schema` had already created. Rather than keep
  patching migration bookkeeping by hand, we rebuilt clean: seed
  migration first, on a truly fresh project, `pm_agent` created via
  raw SQL *after* (never migration-tracked). That's the project in
  `secrets.local.md` now.
- **`DROP COLUMN` doesn't physically shrink existing rows** in
  Postgres — metadata-only. Needed an added `VACUUM FULL` (see changes
  above), or the live fix would look like it failed on screen.
- **The Free-tier org can't branch at all** (`PaymentRequiredException`)
  — discovered only after fully seeding and verifying on it. Required
  switching Supabase accounts mid-session to the Enterprise `supabase-demo`
  org and redoing everything there.
- **Branch creation is too slow for live use, full stop** — 3-4+
  minutes every attempt, more than the entire 8-minute demo slot.
  Not a risk under pressure; a hard constraint. The stretch only works
  pre-created.
- **Two abandoned/broken Supabase projects are left behind with real
  recurring cost** — see the cleanup section in `secrets.local.md`.
  There's no `delete_project` MCP tool available to me, only
  `pause_project`, so I couldn't fully clean these up myself:
  - `bawqubebzqgurpphrdbg` (free tier, personal account) — needs
    manual deletion; I lost MCP access to that account when we
    switched.
  - `qpzikswotdimqnjflrap` (Enterprise org, $10/mo) — the broken
    migration-history attempt. Paused, but pausing may not stop
    billing — please delete from the dashboard.
- **RLS is disabled on all five `app` tables** (Supabase's advisor
  flags this as critical, since it means unrestricted anon/authenticated
  client-library access). Not demo-blocking — access here is only via
  MCP through `pm_agent`/service-role, never a client-side anon key —
  and enabling it without policies would lock everything out. Left
  alone per "don't improve the schema," but flagging since it's a real
  finding, not a plant.
- Prompt 1's naive "average" checkout latency is **432ms** — already
  the exact trap `demo_prompts.md`'s own fallback question anticipates
  ("what does the distribution look like?"). Good sign the safety net
  is well-calibrated to the real data.
