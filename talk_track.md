# Talk track — "Where good issues come from" (8:00, hard cut 7:30)

**Thesis line (memorize):** *Agents don't replace the PM — they collapse the
distance between noticing something and knowing what it is.*

---

## 0:00–0:45 — Hook

On screen: a fake Slack message (make it a slide or a pinned note):

> **#support** — hey, a few customers say checkout feels slow?
> can't repro on my machine. no pattern I can see. 🤷

Say:

> "Sid just showed you what agents do once a good issue exists. I want to
> back up one step and show you where good issues come from — because this
> ⬆ is what PMs actually get. No repro, no pattern, pure vibes. Normally
> this goes to the analyst queue, or to a very grumpy engineer. Tonight it
> goes to an agent with database access."

## 0:45–1:30 — Setup (fast)

On screen: Claude with Supabase MCP connected to "Cartwheel."

> "Cartwheel is a boring e-commerce app on Supabase — users, products,
> carts, orders, request logs. Claude is connected through the Supabase
> MCP server on a **read-only role with a statement timeout** — it can
> look, it can't touch. That one sentence is what makes this safe enough
> to hand to a PM."

Do NOT tour the schema. The agent will discover it — that's the point.

## 1:30–5:15 — The investigation (3 prompts)

**Prompt 1 (triage — is it real?)** Paste the support message + ask the
agent to check whether it's real. Expected on screen: it finds
`request_logs`, pulls checkout latency distribution, reports it's
**bimodal** — most requests ~100ms, a slice at 2–7 seconds.

> Beat: "So it's real. Not 'slow for everyone' — slow for *someone*.
> That's already better than the ticket."

**Prompt 2 (who?)** Ask it to characterize the slow users. Expected: it
segments by region and plan (both flat — say out loud: "there goes
everyone's first guess"), then finds the slow users all have carts with
thousands of events.

> Beat: "It ruled out geography before I finished the sentence. The
> correlation it *did* find: cart size."

**Prompt 3 (why?)** Ask what's structurally wrong with those carts.
Expected: it inspects `carts.events`, runs `pg_column_size`, finds
megabyte rows — a **jsonb accumulator**: every click appended to one
column, rewritten on every update, dragged through checkout every time.

> Beat — your credibility moment, keep it to ~20 seconds: "I've seen this
> exact anti-pattern take down real production databases. It usually takes
> a specialist a day to find. That took ninety seconds."

## 5:15–6:45 — The artifact (the PM payoff)

**Prompt 4:** Ask for an evidence-backed issue: symptom, blast radius
(% of users, who they are), root cause, evidence queries, proposed fix,
suggested priority — **filed into Linear**.

> As it lands: "And now it drops into Sid's world — except this issue
> arrives with receipts. The engineer who picks it up starts at the fix,
> not at 'can't repro.'"

**⏱ 6:45 DECISION POINT — check the clock.**
- Behind schedule → skip to Close. The demo is already complete.
- On time → stretch ending.

## 6:45–7:30 — Stretch: the fix, on a branch

**Prompt 5:** Ask the agent to apply the normalization on a **Supabase
branch** — new `cart_events` table, backfill, drop the accumulator —
then verify: events preserved, cart rows tiny, access pattern indexed.

> "Production untouched. The fix exists, verified, on a branch, before
> the standup where someone would have said 'we should look into that.'"

## 7:30 — Close (hard cut, even mid-stretch)

> "So — what happens to the PM role? The judgment didn't go anywhere:
> deciding this matters, deciding it's worth fixing now, deciding what
> 'fixed' means — still you. What's gone is the waiting. **Agents don't
> replace the PM — they collapse the distance between noticing something
> and knowing what it is.** Happy to go deeper in the roundtable."

---

## Delivery notes

- **Narrate during agent thinking time.** The prompts run 20–60s each;
  those gaps are where your beats live. Never stand silent watching a
  spinner.
- **Read the agent's output selectively.** Point at one number per step
  (the p99, the % of users, the row size). Don't read paragraphs aloud.
- **If a prompt goes sideways**, don't debug live — switch to the golden
  transcript tab (see demo_prompts.md) with: "I pre-ran this exact
  conversation this afternoon — here's what it found." Zero shame, keep
  momentum.
- Total live prompts: 4 (5 with stretch). Resist adding more.
