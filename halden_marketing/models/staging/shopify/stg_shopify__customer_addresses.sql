-- One row per address in the customer's `addresses` JSON array.
select
    customers.id as customer_id,
    cast(address.value->>'id' as bigint) as address_id,
    address.value->>'address1' as address1,
    address.value->>'city' as city,
    address.value->>'province' as province,
    address.value->>'province_code' as province_code,
    address.value->>'country' as country,
    address.value->>'country_code' as country_code,
    address.value->>'zip' as zip,
    cast(address.value->>'default' as boolean) as is_default,
    customers._airbyte_extracted_at
from {{ source('shopify', 'customers') }} as customers,
    json_each(customers.addresses) as address
