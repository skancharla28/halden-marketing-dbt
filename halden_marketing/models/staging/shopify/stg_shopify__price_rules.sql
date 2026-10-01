-- One row per price rule: the discount behind one or more discount codes.
-- Source `value` is a negative string (e.g. '-30.0'); discount_value flips it to a positive number,
-- read as a percent or an amount depending on value_type. ends_at loads as an all-null integer column.
select
    id as price_rule_id,
    title as price_rule_title,
    value_type,
    -cast(value as decimal(12, 2)) as discount_value,
    target_type,
    target_selection,
    allocation_method,
    customer_selection,
    once_per_customer as is_once_per_customer,
    usage_limit,
    starts_at,
    cast(ends_at as timestamp with time zone) as ends_at,
    created_at,
    updated_at,
    shop_url,
    _airbyte_extracted_at
from {{ source('shopify', 'price_rules') }}
