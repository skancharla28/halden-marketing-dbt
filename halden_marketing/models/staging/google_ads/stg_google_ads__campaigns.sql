-- One row per Google Ads campaign. The source `campaign` table is a daily performance report
-- (campaign x date x network x device) that repeats the campaign's attributes on every row, so this
-- keeps the latest row per campaign. Metrics from the same table belong in a separate daily model.
-- Google has no objective; advertising_channel_type (SEARCH, PERFORMANCE_MAX, VIDEO, DEMAND_GEN) is
-- the closest equivalent.
with campaign_report as (
    select * from {{ source('google_ads', 'campaign') }}
),

latest as (
    select *
    from campaign_report
    qualify row_number() over (
        partition by campaign_id
        order by segments_date desc, _airbyte_extracted_at desc
    ) = 1
)

select
    campaign_id,
    campaign_name,
    customer_id as account_id,
    campaign_status,
    campaign_serving_status as serving_status,
    campaign_advertising_channel_type as advertising_channel_type,
    campaign_advertising_channel_sub_type as advertising_channel_sub_type,
    campaign_bidding_strategy_type as bidding_strategy_type,
    campaign_budget_id,
    cast(campaign_start_date as date) as start_date,
    -- 2037-12-30 is Google's placeholder for "no end date"
    cast(nullif(campaign_end_date, '2037-12-30') as date) as end_date,
    _airbyte_extracted_at
from latest
