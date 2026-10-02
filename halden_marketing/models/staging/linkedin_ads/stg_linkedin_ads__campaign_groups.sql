-- One row per LinkedIn campaign group: a folder of campaigns that works like a business initiative
-- (e.g. 'Corporate Gifting'). Join to stg_linkedin_ads__campaigns on campaign_group_id.
select
    id as campaign_group_id,
    name as campaign_group_name,
    cast(regexp_extract(account, '(\d+)$', 1) as bigint) as account_id,
    status as campaign_group_status,
    totalBudget as total_budget,
    test as is_test,
    to_timestamp(cast((runSchedule->>'start') as bigint) / 1000) as started_at,
    to_timestamp(cast((runSchedule->>'end') as bigint) / 1000) as stopped_at,
    created as created_at,
    lastModified as updated_at,
    _airbyte_extracted_at
from {{ source('linkedin_ads', 'campaign_groups') }}
