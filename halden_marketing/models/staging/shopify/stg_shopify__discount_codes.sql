-- One row per discount code. The discount itself (type, value, limits) is on the price rule:
-- join price_rule_id to stg_shopify__price_rules. Automatic discounts have no code and aren't here.
select
    id as discount_code_id,
    price_rule_id,
    code as discount_code,
    usage_count,
    created_at,
    updated_at,
    shop_url,
    _airbyte_extracted_at
from {{ source('shopify', 'discount_codes') }}
