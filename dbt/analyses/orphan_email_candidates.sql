-- Could the conversions without a known lead be linked by e-mail instead? Evidence for the Task 2 decision
-- to leave them out of mart_lead_conversions (open question from notebook 01, section 9).
--
-- Every lead with the same e-mail is a candidate. A candidate is plausible if the contract was signed within
-- the time span seen for the conversions that do have a lead.
--
-- Run: dbt show --select orphan_email_candidates --limit 20

with orphans as (
    select conversions.*
    from {{ ref('stg_conversions') }} as conversions
    left join {{ ref('mart_lead_conversions') }} as leads
        on conversions.conversion_id = leads.conversion_id
    where leads.conversion_id is null
),

sign_window as (
    select
        min(days_to_sign) as min_days,
        max(days_to_sign) as max_days
    from {{ ref('mart_lead_conversions') }}
    where is_converted
),

candidates as (
    select
        orphans.conversion_id,
        orphans.status,
        leads.lead_id,
        datediff('day', leads.lead_date, orphans.signed_date) as days_to_sign
    from orphans
    left join {{ ref('mart_lead_conversions') }} as leads
        on orphans.email = leads.email
)

select
    conversion_id,
    status,
    count(lead_id) as leads_with_same_email,
    count_if(days_to_sign between min_days and max_days) as plausible_leads
from candidates
cross join sign_window
group by all
order by conversion_id
