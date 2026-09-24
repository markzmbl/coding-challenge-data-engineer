-- Task 3: one row per customer journey: the touchpoints (leads) of one customer in one vertical.
-- The touchpoints of a conversion form one journey, its conversion path (mart_lead_conversions). The other leads of
-- a customer and vertical form journeys too: a new journey starts after more than attribution_window_days without
-- a touchpoint.

with lead_conversions as (
    select * from {{ ref('mart_lead_conversions') }}
),

-- The data has no export date; the latest signing date is the last day it covers.
data_cutoff as (
    select max(signed_date) as cutoff_date
    from lead_conversions
),

unconverted_gaps as (
    select
        *,
        datediff(
            'day',
            lag(lead_date) over (partition by email, vertical order by lead_date, lead_id),
            lead_date
        ) as days_since_previous_touch
    from lead_conversions
    where not is_converted
),

-- Numbered per customer and vertical: the first lead, and every lead after a longer gap, opens a new journey
unconverted as (
    select
        *,
        sum(
            case
                when days_since_previous_touch is null then 1
                when days_since_previous_touch > {{ var('attribution_window_days') }} then 1
                else 0
            end
        ) over (partition by email, vertical order by lead_date, lead_id) as journey_number
    from unconverted_gaps
),

touchpoints as (
    select
        'conversion ' || conversion_id as journey_key,
        lead_id,
        email,
        vertical,
        source,
        lead_date,
        conversion_id,
        signed_date,
        contract_status,
        premium
    from lead_conversions
    where is_converted

    union all

    select
        'leads ' || email || ' ' || vertical || ' ' || journey_number as journey_key,
        lead_id,
        email,
        vertical,
        source,
        lead_date,
        null as conversion_id,
        null as signed_date,
        null as contract_status,
        null as premium
    from unconverted
)

select
    first(touchpoints.lead_id order by touchpoints.lead_date, touchpoints.lead_id) as journey_id,
    any_value(touchpoints.email) as customer_email,
    any_value(touchpoints.vertical) as vertical,
    min(touchpoints.lead_date) as first_touch_date,
    date_trunc('month', min(touchpoints.lead_date))::date as journey_month,
    max(touchpoints.lead_date) as last_touch_date,
    count(*) as touchpoints,
    string_agg(touchpoints.source, ' > ' order by touchpoints.lead_date, touchpoints.lead_id) as path,
    first(touchpoints.source order by touchpoints.lead_date, touchpoints.lead_id) as first_touch_source,
    last(touchpoints.source order by touchpoints.lead_date, touchpoints.lead_id) as last_touch_source,
    max(touchpoints.conversion_id) is not null as is_converted,
    max(touchpoints.conversion_id) as conversion_id,
    max(touchpoints.signed_date) as signed_date,
    max(touchpoints.contract_status) as contract_status,
    max(touchpoints.premium) as premium,
    datediff('day', min(touchpoints.lead_date), max(touchpoints.signed_date)) as days_to_convert,
    -- Complete once converted, or once the last touch is at least attribution_window_days old at the data cutoff
    max(touchpoints.conversion_id) is not null
        or max(touchpoints.lead_date) + {{ var('attribution_window_days') }}
            <= any_value(data_cutoff.cutoff_date) as is_complete
from touchpoints
cross join data_cutoff
group by touchpoints.journey_key
