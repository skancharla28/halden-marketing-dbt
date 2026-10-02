-- Snapshot practice: inspect the history. Run after each `dbt snapshot`.

-- Every version of the campaigns that changed (unchanged campaigns have a single version).
select
    name,
    status,
    daily_budget / 100.0 as daily_budget_usd,
    dbt_valid_from,
    dbt_valid_to,
    dbt_is_deleted
from mkt_analytics.snapshots.snap_facebook_marketing__campaigns
where id in (
    select id from mkt_analytics.snapshots.snap_facebook_marketing__campaigns
    group by id having count(*) > 1
)
order by name, dbt_valid_from;

-- The silent edit (change C): the snapshot still shows the old $400 budget, the sandbox shows $450.
select 'snapshot (current version)' as where_from, daily_budget / 100.0 as daily_budget_usd
from mkt_analytics.snapshots.snap_facebook_marketing__campaigns
where name = 'PROS | Broad | Women | Conv' and dbt_valid_to is null
union all
select 'sandbox source', daily_budget / 100.0
from mkt_raw.sandbox_facebook_marketing.campaigns
where name = 'PROS | Broad | Women | Conv';

-- Point-in-time question: what was each campaign's budget at a given moment?
-- Replace the timestamp with one between your snapshot runs.
select name, status, daily_budget / 100.0 as daily_budget_usd
from mkt_analytics.snapshots.snap_facebook_marketing__campaigns
where dbt_valid_from <= now() - interval 1 minute
    and (dbt_valid_to > now() - interval 1 minute or dbt_valid_to is null)
    and coalesce(dbt_is_deleted, 'False') <> 'True'  -- dbt-duckdb stores this flag as text
order by name;
