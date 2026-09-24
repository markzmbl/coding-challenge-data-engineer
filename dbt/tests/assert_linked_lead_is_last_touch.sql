-- The lead a contract names is normally its last touch. This returns the contracts where another lead of the
-- same person and vertical came later, but still before signing (Task 1, section 9). Such a contract is
-- attributed by the rule (all touchpoints of its journey), not by its lead_id alone; the test watches how
-- often that happens.

{{ config(warn_if=">0", error_if=">1") }}  -- baseline: 1 contract (5030)

select
    lead_conversions.conversion_id,
    conversions.lead_id as linked_lead_id,
    lead_conversions.lead_id as last_touch_lead_id
from {{ ref('mart_lead_conversions') }} as lead_conversions
inner join {{ ref('stg_conversions') }} as conversions
    on lead_conversions.conversion_id = conversions.conversion_id
where lead_conversions.is_last_touch
    and lead_conversions.lead_id != conversions.lead_id
