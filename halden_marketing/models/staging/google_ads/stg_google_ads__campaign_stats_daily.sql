-- One row per Google Ads campaign per day per network per device, from the `campaign` report.
-- This is the only Google report covering all campaigns: Performance Max campaigns have no ad groups,
-- so ad_group / ad-level reports miss their spend. Cost is in micros (1,000,000 = 1 USD).
select
    campaign_id,
    customer_id as account_id,
    segments_date as date_day,
    segments_ad_network_type as ad_network_type,
    segments_device as device,

    metrics_impressions as impressions,
    metrics_clicks as clicks,
    cast(metrics_cost_micros / 1000000.0 as decimal(14, 2)) as spend,
    metrics_video_views as video_views,

    metrics_conversions as platform_conversions,
    cast(metrics_conversions_value as decimal(14, 2)) as platform_conversion_value,
    metrics_view_through_conversions as view_through_conversions,

    _airbyte_extracted_at
from {{ source('google_ads', 'campaign') }}
