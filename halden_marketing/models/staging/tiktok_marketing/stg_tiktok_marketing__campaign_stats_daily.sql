-- One row per TikTok campaign per day. Metrics arrive as strings inside the `metrics` JSON.
-- The date comes from dimensions.stat_time_day: the stat_time_day column is a timestamp at midnight
-- in the account timezone (America/New_York) stored as UTC, which can shift dates when cast.
-- total_complete_payment_rate is TikTok's (oddly named) purchase value.
with reports as (
    select * from {{ source('tiktok_marketing', 'campaigns_reports_daily') }}
)

select
    campaign_id,
    advertiser_id as account_id,
    cast((dimensions->>'stat_time_day') as date) as date_day,

    cast((metrics->>'impressions') as bigint) as impressions,
    cast((metrics->>'clicks') as bigint) as clicks,
    cast((metrics->>'reach') as bigint) as reach,
    cast((metrics->>'spend') as decimal(14, 2)) as spend,

    cast((metrics->>'complete_payment') as double) as platform_conversions,
    cast((metrics->>'total_complete_payment_rate') as decimal(14, 2)) as platform_conversion_value,

    _airbyte_extracted_at
from reports
