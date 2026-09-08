# Demo prompts, expected outputs, and the safety net

Run these verbatim in rehearsal. If rehearsal output differs materially,
tune the prompt wording *before* the event, then freeze it.

---

## Prompt 1 — Triage

> Support just sent me this: "a few customers say checkout feels slow?
> can't repro, no pattern I can see." Can you check whether this is real?
> We keep request timings in the database.

**Expected:** finds `app.request_logs`, filters `/api/checkout`, computes
distribution (avg/median/p95/p99 or a histogram). Reports a bimodal
pattern: ~100ms majority, a minority at 2,000–7,000ms. Other endpoints
healthy.

**Success criterion:** the word-level takeaway "real, but only for a
subset" appears. If it only reports an average, follow up: "what does the
distribution look like?"

## Prompt 2 — Who

> So it's real for a subset. Characterize the slow users — is it region,
> plan, tenure, something else? Rule things out explicitly.

**Expected:** joins slow requests to `users` — region flat (the planted
red herring), plan flat. Then correlates with cart data and lands on:
slow users' carts have 2,000–6,000 events vs. 5–50 for everyone else.
Roughly 4% of users affected.

**Success criterion:** explicit rule-outs + the cart-size correlation.

## Prompt 3 — Why

> What's structurally wrong with those carts? Look at how the data is
> actually stored.

**Expected:** inspects `carts.events` (jsonb array), runs
`pg_column_size` / `jsonb_array_length`, finds ~0.5–1.5MB rows. Names
the anti-pattern: an append-only jsonb accumulator on a hot row —
rewritten on every update, deserialized on every checkout.

**Success criterion:** row-size numbers on screen + a causal sentence
linking payload size to checkout latency.

## Prompt 4 — The artifact

> Write this up as an engineering-ready issue: symptom, blast radius,
> root cause, the evidence queries you ran, proposed fix (normalize
> events into a separate table), and suggested priority. Then file it
> in Linear in [TEAM NAME].

**Expected:** structured issue with real numbers from prompts 1–3, filed
via Linear MCP. Have the Linear team name memorized.

**Success criterion:** the issue lands in Linear and you open it on
screen. **This is the demo's money shot — rehearse this step twice.**

## Prompt 5 — Stretch (branch fix)

> Create a Supabase branch and apply the fix there: a normalized
> cart_events table, backfill from the accumulator, drop the jsonb
> column. Then verify: event count preserved, cart row sizes, and that
> fetching a cart's recent events uses an index.

**Expected:** branch created, migration applied (reference version:
`03_fix_migration.sql`), verification queries shown.

**Timing risk:** branch creation can take a couple of minutes. Mitigation:
**pre-create the branch during setup** and change the prompt to "apply
the fix on the `checkout-fix` branch." Decide at rehearsal, not live.

---

## The safety net (three tiers)

1. **Golden transcript.** The night before, run the entire conversation
   start to finish in a separate Claude chat. Keep that tab open during
   the demo. Any live failure → switch tabs: "I pre-ran this exact
   conversation — here's what it found."
2. **Screenshots.** Screenshot each golden-transcript step into a folder
   (or slides) ordered 01–05. Survives wifi death entirely.
3. **The numbers in your head.** Memorize three: p99 checkout latency,
   % of users affected, size of the biggest cart row. Worst case you
   tell the story with zero pixels.

## Rehearsal checklist (do this tomorrow morning, not at 5pm)

- [ ] Fresh Supabase demo project; run `01_setup.sql`; sanity-check the
      two queries at the bottom of that file.
- [ ] (Optional) `02_pm_agent_role.sql` — change the password first.
- [ ] Connect Supabase MCP (read-only) + Linear MCP in a **clean Claude
      project/chat with all other connectors disabled** — extra tools
      cause tool-choice wobble and slower runs.
- [ ] Pre-create the `checkout-fix` branch if doing the stretch.
- [ ] Full dry run, timed, prompts verbatim. Note where the clock is at
      each beat vs. talk_track.md.
- [ ] Build the golden transcript + screenshots from that dry run.
- [ ] Second dry run of Prompt 4 only (the Linear filing).
- [ ] Phone hotspot tested as backup network.
- [ ] Font size cranked; notifications off; only two tabs open (live
      chat + golden transcript).
