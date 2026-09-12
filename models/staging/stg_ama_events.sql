with source as (
    select * from {{source('lexroom_raw', 'raw_events_ama')}}
),

deduplicated as (
    select distinct * from source
),

resolved as (
    select
        deduplicated.event_id,
        deduplicated.user_id,
        deduplicated.workspace_id,
        lower(trim(deduplicated.module_tag)) as raw_module_tag,
        mapping.module_tag as module_tag,
        deduplicated.response_latency_ms as response_latency_ms_raw,
        deduplicated.response_tokens,
        deduplicated.retrieved_chunks,
        deduplicated.is_cached,
        deduplicated.created_at
    from deduplicated
    left join {{ref('module_tag_mapping')}} as mapping
    on lower(trim(deduplicated.module_tag)) = mapping.raw_module_tag
),

flagged as (
    select
        resolved.event_id,
        resolved.user_id,
        resolved.workspace_id,
        resolved.module_tag,
        resolved.raw_module_tag,
        resolved.response_tokens,
        resolved.retrieved_chunks,
        resolved.is_cached,
        resolved.created_at,
        resolved.response_latency_ms_raw,
        resolved.response_latency_ms_raw in (900000, 45000) as has_latency_sentinel,
        resolved.response_latency_ms_raw < 0 as has_negative_latency,
        resolved.retrieved_chunks = 0 and not resolved.is_cached as has_no_retrieved_sources,
        case
            when resolved.response_latency_ms_raw in (900000, 45000) then null
            when resolved.response_latency_ms_raw < 0 then null
            else resolved.response_latency_ms_raw
        end as response_latency_ms,
        cast(date_trunc('week', resolved.created_at) as date) as answer_week
    from resolved
)

select
    event_id,
    user_id,
    workspace_id,
    module_tag,
    raw_module_tag,
    response_latency_ms,
    response_latency_ms_raw,
    response_tokens,
    retrieved_chunks,
    is_cached,
    has_latency_sentinel,
    has_negative_latency,
    has_no_retrieved_sources,
    not (has_latency_sentinel or has_negative_latency or has_no_retrieved_sources) as clean_delivery,
    answer_week,
    created_at
from flagged