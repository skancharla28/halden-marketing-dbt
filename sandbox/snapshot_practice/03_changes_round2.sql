-- !! BEFORE running this file, snapshot round 1's changes (see 02_changes_round1.sql).
--
-- Snapshot practice, step 3: a second round, to build longer histories. Run the snapshot again after.

-- F) BFCM over: Evergreen budget back to $660/day -> its third version.
update mkt_raw.sandbox_facebook_marketing.campaigns
set daily_budget = 66000, updated_time = now()
where name = 'PROS | ASC | Evergreen';

-- G) The new fall campaign gets more budget -> its second version.
update mkt_raw.sandbox_facebook_marketing.campaigns
set daily_budget = 75000, updated_time = now()
where name = 'PROS | Fall Launch 2026';

-- H) The deleted campaign comes back (restored in Ads Manager) -> a new current version after
--    the deleted one.
insert into mkt_raw.sandbox_facebook_marketing.campaigns
select * replace (now() as updated_time)
from mkt_raw.facebook_marketing.campaigns
where name = 'RT | DPA | Viewed 30d';
