-- ============================================================
-- Cartwheel demo seed — Agentic PM Kickoff
-- Run once against a FRESH Supabase demo project (SQL editor or psql).
-- Takes ~30-90s depending on instance size (builds ~1M jsonb events).
--
-- Planted pathology: app.carts.events is a jsonb accumulator.
-- ~4% of users ("power users", id % 25 = 0) have 2,000-6,000 events
-- in their cart row (~0.5-1.5 MB each). Checkout latency in
-- app.request_logs scales with cart event count -> bimodal latency.
-- Red herring: region does NOT correlate with slowness.
-- ============================================================

select setseed(0.42);

create schema if not exists app;

-- ------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------
create table app.users (
  id          bigint generated always as identity primary key,
  email       text not null unique,
  region      text not null,
  plan        text not null default 'free',
  created_at  timestamptz not null default now()
);

create table app.products (
  id          bigint generated always as identity primary key,
  name        text not null,
  price_cents integer not null,
  created_at  timestamptz not null default now()
);

-- THE ANTI-PATTERN: events jsonb accumulator on the cart row.
create table app.carts (
  id          bigint generated always as identity primary key,
  user_id     bigint not null references app.users(id),
  status      text not null default 'active',
  events      jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table app.orders (
  id          bigint generated always as identity primary key,
  user_id     bigint not null references app.users(id),
  cart_id     bigint not null references app.carts(id),
  total_cents integer not null,
  created_at  timestamptz not null default now()
);

create table app.request_logs (
  id          bigint generated always as identity primary key,
  user_id     bigint,
  path        text not null,
  status_code integer not null default 200,
  duration_ms integer not null,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Seed: users (5,000), regions independent of power-user status
-- ------------------------------------------------------------
insert into app.users (email, region, plan, created_at)
select
  'user' || g || '@example.com',
  (array['us-west','us-east','eu-central','apac'])[1 + floor(random()*4)::int],
  case when random() < 0.25 then 'pro' else 'free' end,
  now() - (random() * interval '180 days')
from generate_series(1, 5000) g;

-- ------------------------------------------------------------
-- Seed: products (200)
-- ------------------------------------------------------------
insert into app.products (name, price_cents)
select 'Product ' || g, (500 + floor(random()*20000))::int
from generate_series(1, 200) g;

-- ------------------------------------------------------------
-- Seed: carts — one active cart per user.
-- Power users (id % 25 = 0, ~200 users): 2,000-6,000 events.
-- Everyone else: 5-50 events.
-- md5 session strings keep TOAST compression from hiding the bloat.
-- ------------------------------------------------------------
insert into app.carts (user_id, status, events, created_at, updated_at)
select
  u.id,
  'active',
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'type', (array['item_viewed','item_added','item_removed',
                     'coupon_tried','checkout_started'])[1 + floor(random()*5)::int],
      'ts', (now() - (random() * interval '30 days'))::text,
      'item_id', 1 + floor(random()*200)::int,
      'session', md5(random()::text),
      'trace', md5(random()::text || 'trace'),
      'client', jsonb_build_object(
        'ua', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        'viewport', jsonb_build_object(
          'w', 800 + floor(random()*1200)::int,
          'h', 600 + floor(random()*800)::int))
    ))
    from generate_series(1,
      case when u.id % 25 = 0
           then 2000 + floor(random()*4000)::int
           else 5    + floor(random()*45)::int
      end)
  ), '[]'::jsonb),
  u.created_at,
  now() - (random() * interval '2 days')
from app.users u;

-- ------------------------------------------------------------
-- Seed: orders (~40% of users have a past order)
-- ------------------------------------------------------------
insert into app.orders (user_id, cart_id, total_cents, created_at)
select c.user_id, c.id, (1000 + floor(random()*50000))::int,
       now() - (random() * interval '90 days')
from app.carts c
where random() < 0.4;

-- ------------------------------------------------------------
-- Seed: request logs.
-- Checkout latency = f(cart event count) -> the discoverable signal.
-- ------------------------------------------------------------
-- Checkout requests: 3 per user over the last 7 days.
insert into app.request_logs (user_id, path, status_code, duration_ms, created_at)
select
  c.user_id,
  '/api/checkout',
  200,
  round(60 + random()*40
        + jsonb_array_length(c.events) * (1.0 + random()*0.4))::int,
  now() - (random() * interval '7 days')
from app.carts c,
     generate_series(1, case when c.user_id % 25 = 0 then 5 else 3 end);

-- Background noise: other endpoints, all healthy.
insert into app.request_logs (user_id, path, status_code, duration_ms, created_at)
select
  u.id,
  (array['/api/products','/api/cart','/api/search','/'])[1 + floor(random()*4)::int],
  200,
  (20 + floor(random()*120))::int,
  now() - (random() * interval '7 days')
from app.users u, generate_series(1, 5);

-- ------------------------------------------------------------
-- Indexes so live demo queries are snappy
-- ------------------------------------------------------------
create index on app.request_logs (path, created_at);
create index on app.request_logs (user_id);
create index on app.carts (user_id);
create index on app.orders (user_id);

analyze app.users, app.products, app.carts, app.orders, app.request_logs;

-- ------------------------------------------------------------
-- Sanity checks (run manually; should confirm the plant)
-- ------------------------------------------------------------
-- Bimodal checkout latency:
--   select width_bucket(duration_ms, 0, 8000, 16) b, count(*),
--          min(duration_ms), max(duration_ms)
--   from app.request_logs where path = '/api/checkout'
--   group by 1 order by 1;
--
-- Bloated cart rows:
--   select id, user_id, jsonb_array_length(events) n,
--          pg_size_pretty(pg_column_size(events)::bigint) sz
--   from app.carts order by pg_column_size(events) desc limit 5;
