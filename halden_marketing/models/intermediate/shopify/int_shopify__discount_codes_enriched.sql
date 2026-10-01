-- One row per discount code: code + its price rule + business type (discount_code_types seed)
-- + usage from orders. Order stats cover all orders using the code, including test/wholesale;
-- filter int_shopify__orders_enriched on is_marketing_eligible for marketing analysis.
with discount_codes as (
    select * from {{ ref('stg_shopify__discount_codes') }}
),

price_rules as (
    select * from {{ ref('stg_shopify__price_rules') }}
),

code_types as (
    select * from {{ ref('discount_code_types') }}
),

order_usage as (
    select
        discount_code,
        count(*) as order_count,
        sum(total_discounts) as total_discount_amount,
        sum(net_sales) as net_sales,
        min(created_at) as first_used_at,
        max(created_at) as last_used_at
    from {{ ref('int_shopify__orders_enriched') }}
    where discount_code is not null
    group by discount_code
)

select
    discount_codes.discount_code_id,
    discount_codes.discount_code,
    code_types.code_type,
    discount_codes.price_rule_id,

    price_rules.value_type,
    price_rules.discount_value,
    case when price_rules.value_type = 'percentage' then price_rules.discount_value end as discount_pct,
    price_rules.is_once_per_customer,
    price_rules.usage_limit,
    price_rules.starts_at,
    price_rules.ends_at,

    discount_codes.usage_count,
    coalesce(order_usage.order_count, 0) as order_count,
    coalesce(order_usage.total_discount_amount, 0) as total_discount_amount,
    coalesce(order_usage.net_sales, 0) as net_sales,
    order_usage.first_used_at,
    order_usage.last_used_at,

    discount_codes.created_at
from discount_codes
left join price_rules
    on discount_codes.price_rule_id = price_rules.price_rule_id
left join code_types
    on discount_codes.discount_code = code_types.discount_code
left join order_usage
    on discount_codes.discount_code = order_usage.discount_code
