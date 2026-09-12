with answers as(
    select * from {{ref('stg_ama_events')}}
),

feedback as(
    select * from {{ref('stg_ama_feedback')}}
),

workspaces as(
    select * from {{ref('stg_workspaces')}}
),

joined as(
    select
        answers.event_id,
        answers.user_id,
        answers.workspace_id,
        answers.module_tag,
        answers.answer_week,
        answers.created_at as answered_at,
        answers.response_latency_ms,
        answers.response_tokens,
        answers.retrieved_chunks,
        answers.is_cached,
        answers.clean_delivery,
        feedback.thumbs_raw,
        feedback.reason_tag,
        feedback.feedback_at,
        coalesce(feedback.valid_thumb, false) as has_valid_rating,
        coalesce(feedback.is_positive, false) as positive_rating,
        workspaces.country,
        workspaces.plan,
        workspaces.firm_size_bucket,
        workspaces.workspace_id is null as has_unknown_workspace
    from answers
    left join feedback
        on answers.event_id = feedback.event_id
    left join workspaces
        on answers.workspace_id = workspaces.workspace_id
)

select * from joined