with answers as(
    select *
    from {{ref('int_ama_answers')}}
),

weekly as(
    select
        answer_week,
        count(*) as total_answers,
        count(distinct cast(answered_at as date)) as days_with_answers,
        sum(case when clean_delivery then 1 else 0 end) as clean_answers,
        sum(case when has_valid_rating then 1 else 0 end) as rated_answers,
        sum(case when clean_delivery and has_valid_rating then 1 else 0 end) as rated_clean_answers,
        sum(case when clean_delivery and positive_rating then 1 else 0 end) as positive_clean_answers
    from answers
    group by answer_week
),

with_rates as(
    select *,
        round(100.0 * clean_answers / nullif(total_answers, 0), 1) as clean_delivery_rate_percentage,
        round(100.0 * positive_clean_answers / nullif(rated_clean_answers, 0), 1) as accepted_rate_on_clean_percentage,
        round(100.0 * rated_answers / nullif(total_answers, 0), 1) as rating_coverage_percentage
    from weekly
)

select
    answer_week,
    total_answers,
    days_with_answers,
    clean_answers,
    rated_clean_answers,
    positive_clean_answers,
    clean_delivery_rate_percentage,
    accepted_rate_on_clean_percentage,
    rating_coverage_percentage,
    round(clean_delivery_rate_percentage * accepted_rate_on_clean_percentage / 100.0, 1) as ama_quality_score
from with_rates
order by answer_week