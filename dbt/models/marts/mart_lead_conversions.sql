-- Task 2: one row per lead, with its contract if the lead converted.
-- For the marketing team: which leads converted, through which channel, how fast and with which premium.

with leads as (
    select * from {{ ref('stg_leads') }}
),

conversions as (
    select * from {{ ref('stg_conversions') }}
),

-- A lead_id can occur more than once (notebook 01, section 7). The copies are merged into one row:
-- a value the copies agree on is kept, contradicting values become unknown.
-- email and created_at are identical in all copies.
leads_merged as (
    select
        lead_id,
        max(email) as email,
        min(created_at) as lead_date,
        case when count(distinct vertical) = 1 then max(vertical) end as vertical,
        case when count(distinct source) = 1 then max(source) end as source,
        case when count(distinct region) = 1 then max(region) end as region
    from leads
    group by lead_id
)

select
    leads_merged.lead_id,
    leads_merged.lead_date,
    date_trunc('month', leads_merged.lead_date)::date as lead_month,
    coalesce(leads_merged.vertical, 'unknown') as vertical,
    coalesce(leads_merged.source, 'unknown') as source,
    coalesce(leads_merged.region, 'unknown') as region,
    leads_merged.email,
    conversions.conversion_id is not null as is_converted,
    conversions.conversion_id,
    conversions.signed_date,
    conversions.status as contract_status,
    conversions.premium,
    datediff('day', leads_merged.lead_date, conversions.signed_date) as days_to_sign
from leads_merged
left join conversions
    on leads_merged.lead_id = conversions.lead_id
