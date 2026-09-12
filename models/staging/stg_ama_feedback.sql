with source as(
    select * from {{source('lexroom_raw', 'raw_feedback_ama')}}
),

deduplicated as(
    select distinct * from source
),

typed as(
    select
        deduplicated.feedback_id,
        deduplicated.event_id,
        deduplicated.user_id,
        deduplicated.thumbs as thumbs_raw,
        deduplicated.thumbs in (-1, 1) as valid_thumb,
        case
            when deduplicated.thumbs = 1 then true
            when deduplicated.thumbs = -1 then false
        end as is_positive,
        nullif(trim(coalesce(deduplicated.reason_tag, '')), '') as reason_tag,
        nullif(trim(coalesce(deduplicated.free_text, '')), '') as free_text,
        deduplicated.created_at as feedback_at
    from deduplicated
)

select * from typed