# Agentic PM Kickoff — Supabase demo package

**Concept:** "Where good issues come from." A vague support report
("checkout feels slow for some users") → an agent with read-only database
access investigates → evidence-backed issue filed into Linear → (stretch)
fix applied and verified on a Supabase branch, prod untouched.

**Slot:** ~8 min, third demo, right after Linear. Hard cut at 7:30.

## Files

| File | What it is |
|---|---|
| `01_setup.sql` | Schema + seed data with the planted pathology (jsonb accumulator on `app.carts.events`). Run once on a fresh demo project. |
| `02_pm_agent_role.sql` | Optional read-only `pm_agent` role — the safety proof point. Change the password. |
| `03_fix_migration.sql` | Known-good reference for the stretch fix. Run only on a branch. |
| `talk_track.md` | Minute-by-minute script with beats and the hard-cut line. |
| `demo_prompts.md` | The 5 exact prompts, expected outputs, 3-tier fallback plan, rehearsal checklist. |

## The plant (so you can speak to it fluently)

- 5,000 users; ~200 "power users" (`id % 25 = 0`).
- Power users' carts: 2,000–6,000 jsonb events (~0.5–1.5 MB rows,
  md5 session strings defeat TOAST compression). Everyone else: 5–50.
- `request_logs` checkout latency is seeded as a function of cart event
  count → bimodal distribution (~100ms vs 2–7s).
- Red herring: `region` is assigned independently of power-user status,
  so the agent gets to rule it out on screen.

## Setup order

1. Create a fresh Supabase project (demo-only — this is disposable).
2. Run `01_setup.sql` (30–90s). Run the sanity queries at the bottom.
3. Optionally run `02_pm_agent_role.sql`.
4. Connect Supabase MCP (read-only) and Linear MCP in a clean chat.
5. Follow the rehearsal checklist in `demo_prompts.md`.

## Platform recommendation

Present from **Claude (desktop app or claude.ai) with Supabase MCP +
Linear MCP** rather than Claude Code. Reasons: the audience is PMs — the
message "this is the same Claude you already use, no terminal required"
IS the demo; the chat UI reads better on a projector; and the Linear MCP
callback lands harder from the same surface. Keep Claude Code in your
back pocket for a roundtable answer about deeper workflows.
