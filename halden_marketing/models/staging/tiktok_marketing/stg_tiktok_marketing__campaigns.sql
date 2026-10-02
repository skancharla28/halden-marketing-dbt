-- One row per TikTok campaign. campaign_id equals utm_id on TikTok clicks. TikTok has no campaign
-- start date; created_at is the closest equivalent.
select
    campaign_id,
    campaign_name,
    advertiser_id as account_id,
    objective_type as objective,
    campaign_type,
    operation_status as campaign_status,
    secondary_status,
    budget_mode,
    budget,
    is_smart_performance_campaign,
    is_search_campaign,
    create_time as created_at,
    modify_time as updated_at,
    _airbyte_extracted_at
from {{ source('tiktok_marketing', 'campaigns') }}
