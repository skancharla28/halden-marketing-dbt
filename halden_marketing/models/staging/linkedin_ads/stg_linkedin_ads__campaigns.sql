-- One row per LinkedIn campaign. campaign_id equals utm_id on LinkedIn clicks, so this level (not the
-- campaign group) lines up with other platforms' campaigns. Account and group are URNs
-- (urn:li:sponsoredAccount:<id>); runSchedule holds epoch milliseconds.
select
    id as campaign_id,
    name as campaign_name,
    cast(regexp_extract(account, '(\d+)$', 1) as bigint) as account_id,
    cast(regexp_extract(campaignGroup, '(\d+)$', 1) as bigint) as campaign_group_id,
    objectiveType as objective,
    status as campaign_status,
    type as campaign_type,
    costType as cost_type,
    format as ad_format,
    optimizationTargetType as optimization_target_type,
    cast((dailyBudget->>'amount') as decimal(12, 2)) as daily_budget,
    (dailyBudget->>'currencyCode') as daily_budget_currency,
    offsiteDeliveryEnabled as is_offsite_delivery_enabled,
    audienceExpansionEnabled as is_audience_expansion_enabled,
    to_timestamp(cast((runSchedule->>'start') as bigint) / 1000) as started_at,
    to_timestamp(cast((runSchedule->>'end') as bigint) / 1000) as stopped_at,
    created as created_at,
    lastModified as updated_at,
    _airbyte_extracted_at
from {{ source('linkedin_ads', 'campaigns') }}
