with answers as(
    select *
    from{{ref('int_ama_answers')}}
    where not has_unknown_workspace
),

weeks_ranked as(
    select
        answer_week,
        row_number() over (order by answer_week desc) as weeks_back
    from (select distinct answer_week from answers)
),

windowed as(
    select
        answers.workspace_id,
        answers.country,
        answers.plan,
        answers.firm_size_bucket,
        answers.has_valid_rating,
        answers.positive_rating,
        case when weeks_ranked.weeks_back <= 4 then 'recent' else 'prior' end as comparison_window
    from answers
    inner join weeks_ranked
        on answers.answer_week = weeks_ranked.answer_week
    where weeks_ranked.weeks_back <= 8
),

by_workspace as(
    select
        workspace_id,
        country,
        plan,
        firm_size_bucket,
        sum(case when comparison_window = 'prior'  and has_valid_rating then 1 else 0 end) as prior_rated_answers,
        sum(case when comparison_window = 'prior'  and positive_rating  then 1 else 0 end) as prior_positive_answers,
        sum(case when comparison_window = 'recent' and has_valid_rating then 1 else 0 end) as recent_rated_answers,
        sum(case when comparison_window = 'recent' and positive_rating  then 1 else 0 end) as recent_positive_answers
    from windowed
    group by workspace_id, country, plan, firm_size_bucket

),

with_rates as(

    select *,
        round(100.0 * prior_positive_answers  / nullif(prior_rated_answers, 0), 1)  as prior_acceptance_rate_percentage,
        round(100.0 * recent_positive_answers / nullif(recent_rated_answers, 0), 1) as recent_acceptance_rate_percentage
    from by_workspace

),

with_change as(

    select *,
        round(recent_acceptance_rate_percentage - prior_acceptance_rate_percentage, 1) as acceptance_change_points,
        prior_rated_answers  >= {{ var('min_rated_answers_per_window') }}
            and recent_rated_answers >= {{ var('min_rated_answers_per_window') }} as has_comparable_windows
    from with_rates

)

select
    workspace_id,
    country,
    plan,
    firm_size_bucket,
    prior_rated_answers,
    recent_rated_answers,
    prior_acceptance_rate_percentage,
    recent_acceptance_rate_percentage,
    acceptance_change_points,
    has_comparable_windows,
    has_comparable_windows
        and acceptance_change_points <= -{{ var('acceptance_drop_threshold_points') }} as is_flagged_for_review
from with_change
order by acceptance_change_points