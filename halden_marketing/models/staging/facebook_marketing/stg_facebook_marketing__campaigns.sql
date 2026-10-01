select
    id as campaign_id,
    name as campaign_name,
    account_id,
    objective,
    status,
    effective_status,
    daily_budget / 100.0 as daily_budget,
    created_time,
    updated_time,
    _airbyte_extracted_at
from {{ source('facebook_marketing', 'campaigns') }}
