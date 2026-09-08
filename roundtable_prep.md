# Roundtable prep — the four questions you'll almost certainly get

Format for each: the **20-second answer** (lead with this, it's the
soundbite), then **depth on demand** if the moderator lets it breathe.
The roundtable is 20 minutes across four companies — expect to field
one or two of these, so make the soundbite count.

---

## Q1. "Is it actually safe to point an AI at my production database?"

(Someone WILL ask this. It's also your best question — you've spent
months on exactly this.)

**20-second answer:**
"Treat the agent like a new hire, not like magic. Mine ran on a
read-only role with a statement timeout — it can look, it can't touch,
and every query it ran is visible on screen. When it was time to change
something, that happened on a branch, not on prod. Least privilege,
observable, revocable. That's not AI policy, that's just database
hygiene we've had for thirty years."

**Depth on demand:**
- Tiered access: investigation on read-only (optionally against a read
  replica so even pathological queries can't affect prod load); writes
  only through branches/migrations with human review.
- PII: restrict the role to masked views or non-sensitive schemas; the
  latency investigation tonight never needed a single email address —
  most diagnostic questions don't.
- The failure mode isn't the agent going rogue; it's over-granting
  because it's convenient. Same as humans.

## Q2. "How do I trust what it found? What if it hallucinated?"

**20-second answer:**
"You don't trust it — you check it, and it makes checking cheap. Every
claim in that demo arrived with the query that produced it. The issue it
filed included the evidence queries, so any engineer can re-run them.
That's a higher standard of receipts than most human analysis I've seen.
The rule: agents should show their work, and conclusions without
runnable evidence don't ship."

**Depth on demand:**
- Distinguish two error types: wrong SQL (visible, re-runnable, cheap to
  catch) vs. wrong *interpretation* (the human's job to sniff-test —
  which is exactly the PM skill that matters now).
- The verification asymmetry is the whole game: finding the answer took
  the agent minutes; checking it takes a human seconds.

## Q3. "So do PMs need to learn SQL now?"

**20-second answer:**
"No — that's the point of what you just watched; nobody typed a line of
SQL. But the skill underneath SQL matters more than ever: knowing what
question to ask, knowing what a suspicious answer smells like, knowing
when 'average latency is fine' is hiding a bimodal distribution. Call it
data literacy without the syntax tax. The queue to the analyst
disappears; the judgment doesn't."

**Depth on demand:**
- The support message and the filed issue are the same information at
  two levels of precision. The PM's job is managing that gradient —
  agents just move you along it faster.
- Anecdote if useful: in astrophysics the instrument matters less than
  knowing your selection effects — what your data *can't* show you.
  Same skill here.

## Q4. "Honestly — what's left of the PM role?" (the event's title question)

**20-second answer:**
"Everything except the waiting. Look at what the agent didn't do
tonight: it didn't decide slow checkout mattered, didn't decide it was
worth fixing this sprint, didn't decide what 'fixed' means, and didn't
weigh it against everything else on the roadmap. It collapsed the
distance between noticing something and knowing what it is — from days
to minutes. The judgment jobs are all still there. There are just fewer
places left to hide from them."

**Depth on demand:**
- The uncomfortable, honest version: the parts of PM work that were
  secretly analyst work, or secretly ticket-formatting work, do shrink.
  If your value was being the person who could get the data, that moat
  is gone. If your value was knowing what the data means for the
  product, your leverage just multiplied.
- Prediction worth saying out loud: the PM artifact shifts from "the
  spec" to "the question." Agents are only as good as what they're
  asked.

---

## Bonus rapid-fire (one-liners, in case they come up)

- **"What about cost?"** — "The investigation you watched cost less than
  the coffee for the meeting where you'd have scheduled the analysis."
- **"Does this work on my stack?"** — "It's Postgres and MCP — the demo
  is Supabase-flavored, the pattern isn't proprietary."
- **"What breaks first at scale?"** — "Access control sloppiness, not
  model quality. Get the roles right before you get the prompts right."
- **"Why did it find that so fast?"** — "Because databases are honest.
  The evidence was sitting in request logs and row sizes the whole time;
  nobody had time to look. Now looking is cheap."

## Delivery notes

- If a question goes to the whole panel, go SECOND or THIRD, not first —
  react to what PostHog/Linear say and position against it ("...and the
  reason the agent can do what Sid described is that it can reach ground
  truth").
- If someone asks a hostile "this will kill jobs" question, don't argue
  the macro. Bring it back to the demo: "what disappeared tonight was a
  three-day wait, not a person."
- Keep one stat from the demo loaded for reuse: "4% of users, 30x the
  latency, found in 90 seconds" is your portable proof.
