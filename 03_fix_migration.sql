-- ============================================================
-- STRETCH ENDING — run on a Supabase BRANCH, never on the demo "prod".
-- Normalizes the jsonb accumulator into app.cart_events.
--
-- In the live demo you don't paste this by hand: you ask the agent
-- to propose and apply it on the branch. This file is your known-good
-- reference (and your fallback if the agent's version drifts).
-- ============================================================

begin;

create table app.cart_events (
  id         bigint generated always as identity primary key,
  cart_id    bigint not null references app.carts(id),
  type       text not null,
  item_id    bigint,
  payload    jsonb,
  created_at timestamptz not null default now()
);

create index cart_events_cart_id_created_at_idx
  on app.cart_events (cart_id, created_at);

-- Backfill from the accumulator.
insert into app.cart_events (cart_id, type, item_id, payload, created_at)
select
  c.id,
  e->>'type',
  nullif(e->>'item_id','')::bigint,
  e,
  coalesce(nullif(e->>'ts','')::timestamptz, c.updated_at)
from app.carts c
cross join lateral jsonb_array_elements(c.events) e;

-- Slim the hot row. (In a real rollout: dual-write window first,
-- then drop. On a branch we can be decisive.)
alter table app.carts drop column events;

commit;

-- ------------------------------------------------------------
-- On-branch verification queries (the "prod untouched" beat):
-- ------------------------------------------------------------
-- 1) Events preserved:
--    select count(*) from app.cart_events;            -- ~1M
-- 2) Cart rows are now tiny:
--    select pg_size_pretty(avg(pg_column_size(c.*))::bigint)
--    from app.carts c;
-- 3) The checkout access pattern is indexed:
--    explain analyze
--    select * from app.cart_events
--    where cart_id = 25 order by created_at desc limit 20;
-- Honest framing for the room: "I can't replay production traffic
-- on a branch, but the megabyte payload checkout was dragging around
-- is gone, and the access pattern is now an index scan."
