-- One row per refund. Line-level detail is in stg_shopify__order_refund_lines.
-- Refunded amounts are summed from refund_line_items: orders.current_subtotal_price is unreliable
-- for orders containing gift cards.
with refunds as (
    select * from {{ source('shopify', 'order_refunds') }}
)

select
    id as refund_id,
    order_id,
    created_at as refunded_at,
    processed_at,
    note as refund_note,
    nullif(trim(regexp_replace(note, '^Return\s*-\s*', '')), '') as return_reason,
    restock as is_restocked,

    coalesce((
        select sum(cast((line.value->>'quantity') as integer))
        from json_each(refund_line_items) as line
    ), 0) as refunded_quantity,
    coalesce((
        select sum(cast((line.value->>'subtotal') as decimal(12, 2)))
        from json_each(refund_line_items) as line
    ), 0) as refunded_subtotal,
    coalesce((
        select sum(cast((line.value->>'total_tax') as decimal(12, 2)))
        from json_each(refund_line_items) as line
    ), 0) as refunded_tax,
    coalesce((
        select sum(cast((tx.value->>'amount') as decimal(12, 2)))
        from json_each(transactions) as tx
        where (tx.value->>'kind') = 'refund'
            and (tx.value->>'status') = 'success'
    ), 0) as refunded_amount,
    (transactions->0->>'gateway') as refund_gateway,

    shop_url,
    _airbyte_extracted_at
from refunds
