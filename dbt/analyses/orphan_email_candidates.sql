-- Could the contracts without a valid lead_id be attributed by e-mail alone? Evidence for the Task 2 decision to
-- leave them out: without their lead they have no vertical, so the rule (same person and vertical) cannot be
-- applied. This counts, per such contract, the leads of the same e-mail from the attribution window before
-- signing, and how many of them are already touchpoints of another contract.
--
-- Run: dbt show --select orphan_email_candidates --limit 20

with lead_conversions as (
    select * from {{ ref('mart_lead_conversions') }}
),

orphans as (
    select *
    from {{ ref('stg_conversions') }}
    where conversion_id not in (
        select conversion_id from lead_conversions where conversion_id is not null
    )
),

candidates as (
    select
        orphans.conversion_id,
        orphans.status,
        lead_conversions.lead_id,
        lead_conversions.is_converted
    from orphans
    left join lead_conversions
        on orphans.email = lead_conversions.email
        and lead_conversions.lead_date
            between orphans.signed_date - {{ var('attribution_window_days') }} and orphans.signed_date
)

select
    conversion_id,
    status,
    count(lead_id) as leads_in_window,
    count(lead_id) filter (where is_converted) as already_touchpoints_of_another_contract
from candidates
group by conversion_id, status
order by conversion_id
