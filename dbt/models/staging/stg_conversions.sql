-- One row per contract from conversions.csv, cleaned and typed.

with raw_conversions as (
    select * from {{ source('raw', 'conversions') }}
),

cleaned as (
    select
        cast(trim(conversion_id) as integer) as conversion_id,
        cast(nullif(trim(lead_id), '') as integer) as lead_id,
        lower(nullif(trim(email), '')) as email,
        {{ parse_decimal('premium') }} as premium,
        {{ parse_date_by_shape('signed_date') }} as signed_date,
        -- 'ACTIVE' is a casing variant, 'aktiv' the German spelling (notebook 01, section 5)
        case lower(trim(status))
            when 'aktiv' then 'active'
            else lower(trim(status))
        end as status
    from raw_conversions
)

-- Rows that are identical after cleaning are export duplicates (notebook 01, section 7)
select distinct *
from cleaned
