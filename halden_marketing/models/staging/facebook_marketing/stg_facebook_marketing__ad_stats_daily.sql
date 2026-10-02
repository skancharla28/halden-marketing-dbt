{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['ad_id', 'date_day'],
        on_schema_change='append_new_columns'
    )
}}

-- One row per Meta ad per day, from ads_insights (attribution setting 7d_click_1d_view, USD).
-- Incremental: each run reprocesses the last N days (var ad_stats_lookback_days, default 7) because
-- Meta keeps updating conversions for recent days as attribution windows close. Rows for those days
-- are deleted and re-inserted (delete+insert on ad_id + date_day). Full rebuild: --full-refresh.
-- actions / action_values list each purchase under several types (purchase, omni_purchase,
-- offsite_conversion.fb_pixel_purchase) with identical totals; only omni_purchase is used.
with insights as (
    select * from {{ source('facebook_marketing', 'ads_insights') }}
    {% if is_incremental() %}
    where date_start >= (
        select max(date_day) - interval '{{ var("ad_stats_lookback_days", 7) }} days' from {{ this }}
    )
    {% endif %}
)

select
    ad_id,
    adset_id,
    campaign_id,
    account_id,
    date_start as date_day,

    impressions,
    reach,
    clicks,
    inline_link_clicks as link_clicks,
    cast(spend as decimal(14, 2)) as spend,

    coalesce((
        select sum(cast((action.value->>'value') as double))
        from json_each(actions) as action
        where (action.value->>'action_type') = 'omni_purchase'
    ), 0) as platform_conversions,
    coalesce((
        select sum(cast((action_value.value->>'value') as decimal(14, 2)))
        from json_each(action_values) as action_value
        where (action_value.value->>'action_type') = 'omni_purchase'
    ), 0) as platform_conversion_value,

    _airbyte_extracted_at
from insights
