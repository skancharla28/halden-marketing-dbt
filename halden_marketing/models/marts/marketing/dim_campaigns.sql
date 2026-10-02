-- One row per ad campaign across Meta, Google Ads, TikTok and LinkedIn, with current attributes.
-- Business classification (channel, tactic, initiative) comes from the campaign_attributes seed.
with campaigns as (
    select * from {{ ref('int_ad_campaigns__unioned') }}
),

attributes as (
    select * from {{ ref('campaign_attributes') }}
)

select
    campaigns.campaign_key,
    campaigns.platform,
    campaigns.campaign_id,
    campaigns.campaign_name,
    campaigns.account_id,

    attributes.channel,
    attributes.campaign_tactic,
    attributes.initiative_name,
    attributes.initiative_name = 'Always-on' as is_always_on,

    campaigns.campaign_status,
    campaigns.platform_campaign_status
from campaigns
left join attributes
    on campaigns.platform = attributes.platform
    and campaigns.campaign_id = attributes.campaign_id
