# Initial prompt for Claude Code (copy-paste)

Read CONTEXT_PACK.md in this directory in full before doing anything
else — it is the contract for this task. Then read the six package files
it lists in §4.

Mission summary: verify and battle-test the "Cartwheel" demo environment
for a live 8-minute demo TOMORROW NIGHT. Seed the fresh Supabase demo
project with 01_setup.sql, verify every acceptance criterion in §7
against the planted-pathology spec in §5 (tuning the seed minimally and
re-verifying if anything fails), set up the pm_agent read-only role,
validate the stretch migration end-to-end on a `checkout-fix` branch and
then restore that branch to clean pre-fix state, dry-run the data side
of the five frozen demo prompts, and produce REHEARSAL_REPORT.md exactly
in the §10 format — including the three numbers I need to memorize and a
go/no-go recommendation on the stretch ending based on measured branch
timings.

Hard rules, non-negotiable: never run the fix migration or any other DDL
against main (the broken state on main IS the demo); do not reword the
five prompts in demo_prompts.md — put suggested changes in the report
instead; credentials go only in secrets.local.md.

Connection details for the Supabase project: [PASTE PROJECT REF /
CONNECTION STRING / OR "use the Supabase MCP already configured"].

Work autonomously through §6's task sequence; make judgment calls per
§8's last bullet and log them in the report rather than stopping to ask.
Report back when REHEARSAL_REPORT.md is written or if you hit a
data-destroying ambiguity.
