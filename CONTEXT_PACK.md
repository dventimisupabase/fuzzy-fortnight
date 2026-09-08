# CONTEXT PACK — Agentic PM Kickoff demo: build, verify, rehearse-ready
# Handoff: David → Claude Code | Event: TOMORROW NIGHT (hard deadline)

## 1. Mission

Stand up and verify the "Cartwheel" demo environment for an 8-minute live
demo at the Agentic PM Kickoff (PostHog SF, demos 7:00–7:40 pm). The demo
itself runs in Claude (claude.ai / desktop) with Supabase MCP + Linear
MCP — **your job is not to perform the demo**. Your job is to make the
environment provably ready: seeded, statistically verified against the
planted-pathology spec, branch pre-created, and a rehearsal report
produced with the exact numbers David will memorize.

The demo's arc, for context: a vague support report ("checkout feels
slow for some users") → agent investigates over read-only access → finds
a jsonb-accumulator anti-pattern on `app.carts.events` → files an
evidence-backed issue into Linear → (stretch) applies a normalization
fix on a Supabase branch. Your work makes each of those beats land
deterministically.

## 2. Deliverables (definition of done)

1. **Seeded demo project** — `01_setup.sql` applied cleanly to a fresh,
   disposable Supabase project.
2. **Verification report** — every acceptance criterion in §7 checked,
   with actual measured values, PASS/FAIL per criterion.
3. **`pm_agent` role** created per `02_pm_agent_role.sql` (generate a
   strong password; write it ONLY to a local untracked file
   `secrets.local.md`, never into any other artifact).
4. **Branch `checkout-fix` pre-created** and `03_fix_migration.sql`
   validated against it end-to-end (then reset the branch to clean state,
   or recreate it, so the live stretch runs against unfixed data).
5. **`REHEARSAL_REPORT.md`** — format in §10. This is the primary
   handoff artifact back to David.

## 3. Environment & access

- Supabase demo project: **[DAVID: paste project ref + how to connect —
  Supabase MCP configured in Claude Code, or a psql connection string]**
- The project is disposable and demo-only. No real data exists or should
  exist in it. Still: treat `main` as "prod" for discipline — schema
  changes beyond `01_setup.sql`/`02_pm_agent_role.sql` go on branches.
- Linear: not needed for your tasks (the Linear filing is a live-demo
  step). Do not create Linear issues.
- Working directory contains the six package files listed in §4.

## 4. File manifest

| File                   | Role                                  | May you edit it?                                                 |
|------------------------|---------------------------------------|------------------------------------------------------------------|
| `01_setup.sql`         | Schema + seed with planted pathology  | Yes, if verification fails — document every change in the report |
| `02_pm_agent_role.sql` | Read-only investigation role          | Only the password                                                |
| `03_fix_migration.sql` | Known-good stretch fix (branch only)  | Yes, if it fails on the branch — document                        |
| `talk_track.md`        | Minute-by-minute script               | **No**                                                           |
| `demo_prompts.md`      | The 5 frozen demo prompts + fallbacks | **No** (see §8)                                                  |
| `hook_slide.html`      | Opening visual                        | No                                                               |
| `roundtable_prep.md`   | Q&A prep                              | No                                                               |

## 5. The planted pathology (spec)

Ground truth the seed is supposed to produce:

- 5,000 users; power users are `id % 25 = 0` → exactly 200 (4.0%).
- Power users' carts: 2,000–6,000 jsonb events; others: 5–50.
- Event objects include an `md5` session string specifically to blunt
  TOAST/lz4 compression so `pg_column_size(events)` stays large. Target:
  largest cart rows ≥ 500 KB compressed; ideally ~1 MB+.
- `request_logs` `/api/checkout` durations seeded as
  `60 + rand*40 + n_events * (1.0 + rand*0.4)` ms →
  normal cohort ≈ 70–160 ms; power cohort ≈ 2,000–8,500 ms. Bimodal with
  a clean gap; nothing between ~200 ms and ~2,000 ms.
- Red herring: `region` assigned independently of power status → slow
  cohort's region mix must be statistically indistinguishable from the
  population (eyeball proportions; no formal test needed).
- Other endpoints uniformly 20–140 ms (background noise, all healthy).

The demo's forensic chain — verify each link exists in the data:
bimodal latency → cohort identifiable → region/plan flat → cart event
count correlates → `pg_column_size` smoking gun → normalization fix.

## 6. Task sequence

1. Read all seven package files first. Then connect and confirm the
   project is empty/fresh.
2. Apply `01_setup.sql`. Record wall-clock time (David needs to know if
   re-seeding mid-day is feasible).
3. Run the full verification suite (§7). If any criterion fails, tune
   the seed minimally (e.g., adjust event-count ranges or the latency
   coefficient), re-seed, re-verify. Iterate until all PASS. Every
   change → report.
4. Apply `02_pm_agent_role.sql` with a generated password. As
   `pm_agent`: confirm `SELECT` works on all five app tables, confirm an
   `INSERT` fails, confirm `statement_timeout` is `10s`.
5. Create branch `checkout-fix`. Apply `03_fix_migration.sql` on it.
   Verify: `cart_events` count == sum of pre-migration
   `jsonb_array_length(events)`; carts row sizes collapsed; the §7
   index-scan check passes. **Then restore the branch to pre-fix state**
   (recreate it fresh from main) so the live stretch is real. Record how
   long branch creation + migration took — David's go/no-go for the
   stretch depends on it.
6. Dry-run the *data side* of the five frozen prompts in
   `demo_prompts.md`: for each, write and run the SQL you'd expect a
   competent agent to produce, and confirm the data supports the
   expected conclusion. You are testing the environment, not the agent.
7. Write `REHEARSAL_REPORT.md` (§10).

## 7. Acceptance criteria (all must PASS)

Run against `main` post-seed:

- **A1 — Bimodality:** `/api/checkout` p50 ≤ 160 ms AND p96 ≥ 2,000 ms
  AND zero requests in (300, 1500) ms.
- **A2 — Cohort size:** users with any checkout ≥ 2,000 ms = 200 ± 5,
  i.e. ~4% of users.
- **A3 — Smoking gun:** `max(pg_column_size(events)) ≥ 500 KB`; the top
  200 carts by column size are exactly the power users.
- **A4 — Red herring is flat:** slow-cohort region shares within ±6
  percentage points of population shares for all four regions; same for
  plan.
- **A5 — Correlation:** among slow users, min `jsonb_array_length ≥
  2,000`; among fast users, max ≤ 50. No overlap.
- **A6 — Noise floor:** all non-checkout endpoints max ≤ 150 ms.
- **A7 — Role safety:** `pm_agent` read-only + timeout verified (§6.4).
- **A8 — Fix works (on branch):** event counts preserved exactly; avg
  cart row size < 200 bytes post-fix; `EXPLAIN` on
  `select * from app.cart_events where cart_id = $1 order by created_at
  desc limit 20` shows an index scan on
  `cart_events_cart_id_created_at_idx`.
- **A9 — Live-query latency:** each verification query in this section
  completes in < 3 s (the live demo must feel instant).

## 8. Guardrails

- **Never** run `03_fix_migration.sql` (or any DDL beyond the two setup
  scripts) against `main`. The unfixed state on main IS the demo.
- **Do not reword the five demo prompts.** If dry-running (§6.6) reveals
  a prompt is likely to mislead an agent (e.g., ambiguous table
  reference), put a *suggested* revision in the report under "Proposed
  prompt changes" — David decides. Frozen means frozen.
- No credentials in any committed/reported file. `secrets.local.md` only.
- Don't "improve" the schema (no extra indexes on carts.events, no
  constraint hardening). Realistic mediocrity is the point — the flaws
  are the content.
- If something is ambiguous, choose the interpretation that maximizes
  demo determinism and note the decision in the report. Do not block
  waiting for answers unless data would be destroyed.

## 9. Known risks & contingencies

- **Seed too slow / times out** (SQL-editor limits): fall back to psql;
  or split the carts insert into batches by user id range. Keep it one
  transaction per batch.
- **TOAST compression stronger than expected** (A3 fails): increase
  events per power cart, or add a second `md5` field per event. Prefer
  the smallest change that passes.
- **Latency gap too narrow** (A1 fails): raise the per-event coefficient
  from 1.0 to 1.5 in the request_logs insert.
- **Branch creation slow (> ~3 min):** report the measured time
  prominently; recommendation logic: > 3 min → David pre-creates at
  6 pm; > 10 min or flaky → recommend cutting the stretch entirely.
- **jsonb_agg memory pressure on tiny instances:** if the carts insert
  fails, batch power users separately (200 rows) from normal users.

## 10. REHEARSAL_REPORT.md format

```
# Rehearsal report — Cartwheel demo environment
Status: READY | READY WITH CAVEATS | NOT READY

## The three numbers (for David to memorize)
- p99 checkout latency: ____ ms
- Users affected: ____ (____%)
- Largest cart row: ____ (pg_column_size, pretty)

## Acceptance criteria
A1..A9 table: criterion | measured value | PASS/FAIL

## Timings
- Seed wall-clock: ____
- Branch create: ____   Migration on branch: ____
- Stretch go/no-go recommendation: ____

## Changes made to package files (diff-level, with rationale)

## Proposed prompt changes (NOT applied — David decides)

## Anything that surprised you
```

## 11. Working style notes

- Verify by measurement, not by assumption — every claim in the report
  carries the query that produced it (the demo's own standard applies to
  its construction).
- Smallest change that passes acceptance; no speculative robustness.
- The deadline is real. A READY-WITH-CAVEATS report by mid-day beats a
  perfect one at 5 pm.
