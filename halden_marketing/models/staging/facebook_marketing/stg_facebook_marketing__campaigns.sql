-- One row per Meta campaign. daily_budget is null when the budget is set on the ad sets
-- (e.g. retargeting campaigns). campaign_id equals utm_id on Meta landing URLs.
select
    id as campaign_id,
    name as campaign_name,
    account_id,
    objective,
    status as campaign_status,
    effective_status,
    bid_strategy,
    smart_promotion_type,
    daily_budget / 100.0 as daily_budget,
    start_time as started_at,
    stop_time as stopped_at,
    created_time as created_at,
    updated_time as updated_at,
    _airbyte_extracted_at
from {{ source('facebook_marketing', 'campaigns') }}
