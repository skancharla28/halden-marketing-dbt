select
    id as customer_id,
    cast(default_address->>'id' as bigint) as address_id,
    default_address->>'address1' as address1,
    default_address->>'city' as city,
    default_address->>'province' as province,
    default_address->>'province_code' as province_code,
    default_address->>'country' as country,
    default_address->>'country_code' as country_code,
    default_address->>'zip' as zip,
    _airbyte_extracted_at
from {{ source('shopify', 'customers') }}
where default_address is not null
