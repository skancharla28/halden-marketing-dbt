-- One row per campaign per day across Meta, Google Ads, TikTok and LinkedIn: spend and delivery.
-- Campaign attributes are copied in from dim_campaigns so the table can be queried on its own.
-- Only additive metrics are stored; compute ratios (CTR, CPC, CPM, ROAS) after aggregating.
with performance as (
    select * from {{ ref('int_ad_performance__campaign_daily') }}
),

campaigns as (
    select * from {{ ref('dim_campaigns') }}
)

select
    performance.date_day,
    performance.campaign_key,

    performance.platform,
    campaigns.channel,
    performance.campaign_id,
    campaigns.campaign_name,
    campaigns.campaign_tactic,
    campaigns.initiative_name,
    campaigns.is_always_on,

    performance.spend,
    performance.impressions,
    performance.clicks,
    performance.platform_conversions,
    performance.platform_conversion_value
from performance
left join campaigns
    on performance.campaign_key = campaigns.campaign_key
