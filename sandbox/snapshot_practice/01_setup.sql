-- Snapshot practice, step 1: create a sandbox copy of the Meta campaigns table.
-- Run in MotherDuck. Never edit mkt_raw.facebook_marketing directly: Airbyte owns it and models read it.
--
-- Then, from halden_marketing/, take the first snapshot of the sandbox (every campaign = version 1):
--   dbt snapshot --select snap_facebook_marketing__campaigns --vars "{facebook_marketing_schema: sandbox_facebook_marketing}"

create schema if not exists mkt_raw.sandbox_facebook_marketing;

create or replace table mkt_raw.sandbox_facebook_marketing.campaigns as
from mkt_raw.facebook_marketing.campaigns;

select count(*) as campaigns from mkt_raw.sandbox_facebook_marketing.campaigns;  -- expect 16
