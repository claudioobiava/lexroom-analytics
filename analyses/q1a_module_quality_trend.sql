-- Q1A — Product: weekly quality trend per module over the last 8 weeks.

with last_eight_weeks as(

    select answer_week
    from (select distinct answer_week from {{ ref('mart_ama_module_weekly') }})
    order by answer_week desc
    limit 8
)

select
    weekly.module_tag,
    weekly.answer_week,
    weekly.answers,
    weekly.rated_answers,
    weekly.acceptance_rate_percentage,
    weekly.has_minimum_sample
from {{ ref('mart_ama_module_weekly') }} as weekly
inner join last_eight_weeks
    on weekly.answer_week = last_eight_weeks.answer_week
order by weekly.module_tag, weekly.answer_week
