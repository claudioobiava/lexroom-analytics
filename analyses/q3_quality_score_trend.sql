-- Q3 — Leadership: the AMA Quality Score and its trend over the last 8 weeks.

with last_eight_weeks as (

    select answer_week
    from (select distinct answer_week from {{ ref('mart_ama_quality_weekly') }})
    order by answer_week desc
    limit 8

)

select
    weekly.answer_week,
    weekly.days_with_answers,
    weekly.total_answers,
    weekly.clean_delivery_rate_percentage,
    weekly.accepted_rate_on_clean_percentage,
    weekly.rating_coverage_percentage,
    weekly.ama_quality_score
from {{ ref('mart_ama_quality_weekly') }} as weekly
inner join last_eight_weeks
    on weekly.answer_week = last_eight_weeks.answer_week
order by weekly.answer_week
