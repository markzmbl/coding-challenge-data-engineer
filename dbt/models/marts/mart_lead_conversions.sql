-- Task 2: one row per lead, with the contract the lead is a touchpoint of.
-- A lead is a touchpoint of a contract if it comes from the same person (e-mail) and the same vertical as the
-- lead the contract names, and was created within attribution_window_days before signing. Every contract marks
-- its first and its last touch.

with leads as (
    select * from {{ ref('stg_leads') }}
),

conversions as (
    select * from {{ ref('stg_conversions') }}
),

-- A lead_id can occur more than once (Task 1, section 8). The copies are merged into one row:
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
),

lead_details as (
    select
        lead_id,
        lead_date,
        email,
        coalesce(vertical, 'unknown') as vertical,
        coalesce(source, 'unknown') as source,
        coalesce(region, 'unknown') as region
    from leads_merged
),

-- conversions.csv has no vertical: the lead a contract names gives it its vertical. Contracts without a valid
-- lead_id (Task 1, section 9) have none, so they cannot be attributed and are left out.
contracts as (
    select
        conversions.conversion_id,
        conversions.lead_id as linked_lead_id,
        conversions.email,
        conversions.signed_date,
        conversions.status,
        conversions.premium,
        linked_leads.vertical
    from conversions
    inner join lead_details as linked_leads
        on conversions.lead_id = linked_leads.lead_id
),

-- Touchpoints: the linked lead, and every other lead of the same person and vertical from the attribution
-- window before signing. With an unknown vertical, only the linked lead counts.
candidate_touches as (
    select
        contracts.conversion_id,
        contracts.signed_date,
        lead_details.lead_id,
        lead_details.lead_id = contracts.linked_lead_id as is_linked_lead
    from contracts
    inner join lead_details
        on lead_details.lead_id = contracts.linked_lead_id
        or (
            lead_details.email = contracts.email
            and lead_details.vertical = contracts.vertical
            and contracts.vertical != 'unknown'
            and lead_details.lead_date
                between contracts.signed_date - {{ var('attribution_window_days') }} and contracts.signed_date
        )
),

-- A lead counts for one contract at most: a linked lead for its own contract, any other lead for the earliest
-- contract after it.
touches as (
    select
        conversion_id,
        lead_id
    from candidate_touches
    where is_linked_lead
        or lead_id not in (select linked_lead_id from contracts)
    qualify is_linked_lead
        or row_number() over (partition by lead_id order by signed_date, conversion_id) = 1
),

-- First and last touch: the earliest and the latest touchpoint, ordered by lead date, then lead_id
touch_order as (
    select
        touches.conversion_id,
        touches.lead_id,
        row_number() over (
            partition by touches.conversion_id
            order by lead_details.lead_date, touches.lead_id
        ) = 1 as is_first_touch,
        row_number() over (
            partition by touches.conversion_id
            order by lead_details.lead_date desc, touches.lead_id desc
        ) = 1 as is_last_touch
    from touches
    inner join lead_details
        on touches.lead_id = lead_details.lead_id
)

select
    lead_details.lead_id,
    lead_details.lead_date,
    date_trunc('month', lead_details.lead_date)::date as lead_month,
    lead_details.vertical,
    lead_details.source,
    lead_details.region,
    lead_details.email,
    touch_order.conversion_id is not null as is_converted,
    touch_order.conversion_id,
    coalesce(touch_order.is_first_touch, false) as is_first_touch,
    coalesce(touch_order.is_last_touch, false) as is_last_touch,
    contracts.signed_date,
    contracts.status as contract_status,
    contracts.premium,
    datediff('day', lead_details.lead_date, contracts.signed_date) as days_to_sign
from lead_details
left join touch_order
    on lead_details.lead_id = touch_order.lead_id
left join contracts
    on touch_order.conversion_id = contracts.conversion_id
