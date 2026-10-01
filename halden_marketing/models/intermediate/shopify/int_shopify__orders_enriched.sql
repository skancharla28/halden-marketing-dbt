-- One row per order: order attributes + line item counts + refund/return summary.
-- Refunds are attributed back to the order (not the refund date), which is what ROAS needs.
with orders as (
    select * from {{ ref('stg_shopify__orders') }}
),

order_lines as (
    select
        order_id,
        count(*) as line_count,
        sum(quantity) as units_ordered,
        sum(case when is_gift_card then gross_amount - discount_amount else 0 end) as gift_card_sales
    from {{ ref('stg_shopify__order_lines') }}
    group by order_id
),

refunds as (
    select
        order_id,
        count(*) as refund_count,
        min(refunded_at) as first_refunded_at,
        max(refunded_at) as last_refunded_at,
        sum(refunded_quantity) as units_refunded,
        sum(refunded_subtotal) as refunded_subtotal,
        sum(refunded_tax) as refunded_tax,
        sum(refunded_amount) as refunded_amount,
        string_agg(distinct return_reason, ', ' order by return_reason) as return_reasons
    from {{ ref('stg_shopify__order_refunds') }}
    group by order_id
),

joined as (
    select
        orders.*,

        order_lines.line_count,
        order_lines.units_ordered,
        order_lines.gift_card_sales,

        coalesce(refunds.refund_count, 0) as refund_count,
        refunds.first_refunded_at,
        refunds.last_refunded_at,
        date_diff('day', orders.created_at, refunds.first_refunded_at) as days_to_first_refund,
        coalesce(refunds.units_refunded, 0) as units_refunded,
        coalesce(refunds.refunded_subtotal, 0) as refunded_subtotal,
        coalesce(refunds.refunded_tax, 0) as refunded_tax,
        coalesce(refunds.refunded_amount, 0) as refunded_amount,
        refunds.return_reasons
    from orders
    left join order_lines
        on orders.order_id = order_lines.order_id
    left join refunds
        on orders.order_id = refunds.order_id
)

select
    *,
    subtotal_price - refunded_subtotal as net_sales,
    total_price - refunded_amount as net_total_price,
    refund_count > 0 as has_refund,
    units_refunded > 0 and units_refunded >= units_ordered as is_fully_refunded,
    units_refunded > 0 and units_refunded < units_ordered as is_partially_refunded,
    not is_test and not is_cancelled and not is_wholesale as is_marketing_eligible
from joined
