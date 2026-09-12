-- Q3 — Leadership: a North Star metric for AMA quality.
-- "Propose a single composite metric that reflects AMA quality over time.
-- Define it precisely (formula, grain, window). Show its trend for the last 8
-- weeks."
--
-- Reads mart_ama_quality_weekly. The score is the product of the two components
-- next to it, divided by 100, so any row can be checked by hand. Coverage is
-- outside the formula and says how much weight the week can carry: the final
-- week rests on 20 ratings.

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
