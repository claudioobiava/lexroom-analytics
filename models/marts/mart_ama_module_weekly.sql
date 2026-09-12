with answers as (
    select * from {{ref('int_ama_answers')}}
),

weekly as(
    select
        module_tag,
        answer_week,
        count(*) as answers,
        sum(case when has_valid_rating then 1 else 0 end) as rated_answers,
        sum(case when positive_rating then 1 else 0 end) as positive_answers
    from answers
    group by module_tag, answer_week
)

select
    module_tag,
    answer_week,
    answers,
    rated_answers,
    positive_answers,
    round(100.0 * positive_answers / nullif(rated_answers, 0), 1) as acceptance_rate_percentage,
    rated_answers >= {{var('min_rated_answers_weekly')}} as has_minimum_sample
from weekly
order by module_tag, answer_week