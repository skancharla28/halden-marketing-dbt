select
    id as customer_id,
    email_marketing_consent->>'state' as consent_state,
    email_marketing_consent->>'opt_in_level' as opt_in_level,
    cast(email_marketing_consent->>'consent_updated_at' as timestamptz) as consent_updated_at,
    email_marketing_consent->>'state' = 'subscribed' as is_subscribed,
    _airbyte_extracted_at
from {{ source('shopify', 'customers') }}
where email_marketing_consent is not null
