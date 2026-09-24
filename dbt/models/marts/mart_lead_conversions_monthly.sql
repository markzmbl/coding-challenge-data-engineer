-- Task 3: conversion KPIs per vertical, source and lead month.
-- The month is the month the lead came in: a conversion counts in the month of its lead, so a rate never
-- exceeds 100 %, and the numbers of a recent month can still grow while its leads convert.

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
    count(*) filter (where lead_conversions.is_converted) as conversions,
    count(*) filter (where lead_conversions.is_converted) / count(*) as conversion_rate,
    -- The conversions split by the contract's status today (active + pending + cancelled = conversions).
    -- There is no status history, so a past month changes when one of its contracts is cancelled later.
    count(*) filter (where lead_conversions.contract_status = 'active') as active_contracts,
    count(*) filter (where lead_conversions.contract_status = 'pending') as pending_contracts,
    count(*) filter (where lead_conversions.contract_status = 'cancelled') as cancelled_contracts,
    -- Complete once every lead of the month is at least conversion_window_days old at the data cutoff
    last_day(lead_conversions.lead_month) + {{ var('conversion_window_days') }}
        <= data_cutoff.cutoff_date as is_complete
from lead_conversions
cross join data_cutoff
group by
    lead_conversions.vertical,
    lead_conversions.source,
    lead_conversions.lead_month,
    data_cutoff.cutoff_date
