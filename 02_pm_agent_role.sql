-- ============================================================
-- pm_agent: read-only role for the investigation phase.
-- One line in the talk track: "the agent is on a read-only role
-- with a statement timeout — it can look, it can't touch."
--
-- CHANGE THE PASSWORD before running.
-- If you demo via Supabase MCP in read-only mode instead, you can
-- skip this file — but running the investigation as pm_agent is a
-- nice on-screen proof point (SELECT current_user).
-- ============================================================

create role pm_agent login password 'CHANGE_ME_before_demo';

grant usage on schema app to pm_agent;
grant select on all tables in schema app to pm_agent;
alter default privileges in schema app grant select on tables to pm_agent;

-- Belt and suspenders: read-only transactions, bounded queries.
alter role pm_agent set default_transaction_read_only = on;
alter role pm_agent set statement_timeout = '10s';

-- Verify (as pm_agent):
--   select current_user;                          -- pm_agent
--   insert into app.users (email, region)
--     values ('x@x.com','eu-central');            -- must FAIL (read-only)
