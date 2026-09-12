with weeks_ranked as(
    select
        answer_week,
        row_number() over (order by answer_week desc) as weeks_back
    from (select distinct answer_week from {{ ref('int_ama_answers') }})
),

windowed as(
    select
        answers.workspace_id,
        answers.has_valid_rating,
        answers.positive_rating,
        case when weeks_ranked.weeks_back <= 4 then 'recent' else 'prior' end as comparison_window
    from {{ ref('int_ama_answers') }} as answers
    inner join weeks_ranked
        on answers.answer_week = weeks_ranked.answer_week
    where weeks_ranked.weeks_back <= 8
),

scoped as(
    select
        'a. all accounts' as scope,
        comparison_window,
        has_valid_rating,
        positive_rating
    from windowed

    union all

    select
        'b. excluding ws_0041',
        comparison_window,
        has_valid_rating,
        positive_rating
    from windowed
    where workspace_id <> 'ws_0041'

    union all

    select
        'c. excluding ws_0041 and ws_0051',
        comparison_window,
        has_valid_rating,
        positive_rating
    from windowed
    where workspace_id not in ('ws_0041', 'ws_0051')
),

counted as(
    select
        scope,
        sum(case when comparison_window = 'prior'  and has_valid_rating then 1 else 0 end) as prior_rated,
        sum(case when comparison_window = 'prior'  and positive_rating  then 1 else 0 end) as prior_positive,
        sum(case when comparison_window = 'recent' and has_valid_rating then 1 else 0 end) as recent_rated,
        sum(case when comparison_window = 'recent' and positive_rating  then 1 else 0 end) as recent_positive
    from scoped
    group by scope
),

rates as(
    select
        *,
        1.0 * prior_positive  / nullif(prior_rated, 0) as prior_rate,
        1.0 * recent_positive / nullif(recent_rated, 0) as recent_rate
    from counted
),

with_error as(
    select
        *,
        sqrt(
            prior_rate  * (1 - prior_rate)  / nullif(prior_rated, 0)
          + recent_rate * (1 - recent_rate) / nullif(recent_rated, 0)
        ) as standard_error
    from rates
)

select
    scope,
    prior_rated,
    recent_rated,
    round(100 * prior_rate, 1) as prior_acceptance_rate_percentage,
    round(100 * recent_rate, 1) as recent_acceptance_rate_percentage,
    round(100 * (recent_rate - prior_rate), 2) as change_points,
    round(100 * standard_error, 2) as standard_error_points,
    round(abs(recent_rate - prior_rate) / nullif(standard_error, 0), 2) as standard_errors_from_zero
from with_error
order by scope