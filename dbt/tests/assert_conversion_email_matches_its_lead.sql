-- A contract and the lead it names must belong to the same person: their e-mail addresses have to match
-- (Task 1, section 9). A mismatch would attribute a conversion to someone else's customer journey.
-- Returns a row, and so fails, for every contract whose lead has another e-mail address.

select
    conversions.conversion_id,
    conversions.email,
    leads.lead_id,
    leads.email as lead_email
from {{ ref('stg_conversions') }} as conversions
inner join {{ ref('stg_leads') }} as leads
    on conversions.lead_id = leads.lead_id
where conversions.email != leads.email
