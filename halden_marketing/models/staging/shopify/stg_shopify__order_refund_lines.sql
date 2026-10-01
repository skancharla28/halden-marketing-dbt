-- One row per refunded order line, unnested from order_refunds.refund_line_items.
-- subtotal_amount is net of the line's discount; order_line_id joins to stg_shopify__order_lines.
with refunds as (
    select * from {{ source('shopify', 'order_refunds') }}
),

lines as (
    select
        refunds.id as refund_id,
        refunds.order_id,
        refunds.created_at as refunded_at,
        line.value as refund_line
    from refunds,
        json_each(refunds.refund_line_items) as line
)

select
    cast((refund_line->>'id') as bigint) as refund_line_id,
    refund_id,
    order_id,
    cast((refund_line->>'line_item_id') as bigint) as order_line_id,
    cast((refund_line->>'quantity') as integer) as quantity,
    cast((refund_line->>'subtotal') as decimal(12, 2)) as subtotal_amount,
    cast((refund_line->>'total_tax') as decimal(12, 2)) as tax_amount,
    (refund_line->>'restock_type') as restock_type,
    cast((refund_line->>'location_id') as bigint) as location_id,
    refunded_at
from lines
