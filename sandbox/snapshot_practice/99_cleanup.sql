-- Snapshot practice: clean up. The practice history is fake, so drop it before snapshotting the
-- real source (run `dbt snapshot` without --vars afterwards to start real history).

drop table if exists mkt_analytics.snapshots.snap_facebook_marketing__campaigns;
drop schema if exists mkt_raw.sandbox_facebook_marketing cascade;
