-- One row per customer: base attributes + default address + email consent.
-- Multi-address detail stays in stg_shopify__customer_addresses to avoid fan-out.
with customers as (
    select * from {{ ref('stg_shopify__customers') }}
),

default_addresses as (
    select * from {{ ref('stg_shopify__customer_default_addresses') }}
),

email_consents as (
    select * from {{ ref('stg_shopify__customer_email_consents') }}
),

address_counts as (
    select
        customer_id,
        count(*) as address_count
    from {{ ref('stg_shopify__customer_addresses') }}
    group by customer_id
)

select
    customers.customer_id,
    customers.email,
    customers.first_name,
    customers.last_name,
    customers.full_name,
    customers.customer_state,
    customers.tags,
    customers.currency,
    customers.verified_email,
    customers.tax_exempt,

    customers.accepts_marketing,
    customers.accepts_marketing_updated_at,
    customers.marketing_opt_in_level,
    email_consents.consent_state as email_consent_state,
    email_consents.opt_in_level as email_opt_in_level,
    email_consents.consent_updated_at as email_consent_updated_at,
    coalesce(email_consents.is_subscribed, false) as is_email_subscribed,

    default_addresses.address_id as default_address_id,
    default_addresses.city as address_city,
    default_addresses.province as address_province,
    default_addresses.province_code as address_province_code,
    default_addresses.country as address_country,
    default_addresses.country_code as address_country_code,
    default_addresses.zip as address_zip,
    coalesce(address_counts.address_count, 0) as address_count,

    customers.orders_count,
    customers.total_spent,
    customers.last_order_id,
    customers.last_order_name,
    customers.created_at,
    customers.updated_at,
    customers.shop_url
from customers
left join default_addresses
    on customers.customer_id = default_addresses.customer_id
left join email_consents
    on customers.customer_id = email_consents.customer_id
left join address_counts
    on customers.customer_id = address_counts.customer_id
