-- !! BEFORE running this file, take the first snapshot (see 01_setup.sql). If you don't, the snapshot
-- !! never sees the original values: these edits become "version 1" and there is no history to show.
-- !! Check: select count(*) from mkt_analytics.snapshots.snap_facebook_marketing__campaigns;  -- expect 16
--
-- Snapshot practice, step 2: simulate a round of edits in Meta Ads Manager.
-- Each change demonstrates a different snapshot behavior. Afterwards, run the snapshot again:
--   dbt snapshot --select snap_facebook_marketing__campaigns --vars "{facebook_marketing_schema: sandbox_facebook_marketing}"
-- then inspect with 04_inspect.sql.

-- A) Budget increase ahead of BFCM: $660 -> $900/day. updated_time moves, so the snapshot closes the
--    old version and opens a new one.
update mkt_raw.sandbox_facebook_marketing.campaigns
set daily_budget = 90000, updated_time = now()
where name = 'PROS | ASC | Evergreen';

-- B) Campaign paused. Status change -> new version.
update mkt_raw.sandbox_facebook_marketing.campaigns
set status = 'PAUSED', effective_status = 'PAUSED', stop_time = now(), updated_time = now()
where name = 'PROS | Broad | Men | Conv';

-- C) Silent edit: budget changes but updated_time does NOT. The timestamp strategy only looks at
--    updated_time, so this change is MISSED. (The 'check' strategy would catch it.)
update mkt_raw.sandbox_facebook_marketing.campaigns
set daily_budget = 45000
where name = 'PROS | Broad | Women | Conv';

-- D) New campaign launched: copy of the spring launch with a new id. Appears as a new row.
insert into mkt_raw.sandbox_facebook_marketing.campaigns
select * replace (
    999000000000000001 as id,
    'PROS | Fall Launch 2026' as name,
    'ACTIVE' as status,
    'ACTIVE' as effective_status,
    now() as created_time,
    now() as start_time,
    null as stop_time,
    now() as updated_time
)
from mkt_raw.sandbox_facebook_marketing.campaigns
where name = 'PROS | Spring Launch 2026';

-- E) Campaign deleted. With hard_deletes: new_record, the snapshot closes it and adds a row with
--    dbt_is_deleted = true.
delete from mkt_raw.sandbox_facebook_marketing.campaigns
where name = 'RT | DPA | Viewed 30d';
