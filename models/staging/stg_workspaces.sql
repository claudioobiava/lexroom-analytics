with source as(
    select * from {{source('lexroom_raw', 'raw_workspaces')}}
)

select workspace_id,
    coalesce(source.country, 'unknown') as country,
    source.country is null as missing_country,
    source.plan,
    source.firm_size_bucket,
    source.signup_date
from source