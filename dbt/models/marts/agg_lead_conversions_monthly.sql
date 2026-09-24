-- Task 3: leads, conversions and conversion rate per vertical, source and lead month.
-- A conversion counts at its last touch, the lead that closed the customer journey (last-touch attribution, the
-- default). The first_touch_ columns count it at the lead that opened the journey, for comparison. Both add up to
-- all attributed conversions. The month is the month of the lead: a conversion counts in the month of its lead,
-- and the numbers of a recent month can still grow.

with lead_conversions as (
    select * from {{ ref('mart_lead_conversions') }}
),

-- The data has no export date; the latest signing date is the last day it covers.
data_cutoff as (
    select max(signed_date) as cutoff_date
    from lead_conversions
)

select
    lead_conversions.vertical,
    lead_conversions.source,
    lead_conversions.lead_month,
    count(*) as leads,
    count(*) filter (where lead_conversions.is_last_touch) as conversions,
    count(*) filter (where lead_conversions.is_last_touch) / count(*) as conversion_rate,
    -- Value: the annual net premium of the active contracts. Divided by the leads, it gives the active premium
    -- per lead.
    coalesce(
        sum(lead_conversions.premium)
            filter (where lead_conversions.is_last_touch and lead_conversions.contract_status = 'active'),
        0
    ) as active_premium,
    count(*) filter (where lead_conversions.is_first_touch) as first_touch_conversions,
    count(*) filter (where lead_conversions.is_first_touch) / count(*) as first_touch_conversion_rate,
    coalesce(
        sum(lead_conversions.premium)
            filter (where lead_conversions.is_first_touch and lead_conversions.contract_status = 'active'),
        0
    ) as first_touch_active_premium,
    -- Complete once every lead of the month is at least attribution_window_days old at the data cutoff
    last_day(lead_conversions.lead_month) + {{ var('attribution_window_days') }}
        <= data_cutoff.cutoff_date as is_complete
from lead_conversions
cross join data_cutoff
group by
    lead_conversions.vertical,
    lead_conversions.source,
    lead_conversions.lead_month,
    data_cutoff.cutoff_date
