with violations as(
    select
        'mart_ama_module_weekly' as mart_name,
        module_tag || ' ' || cast(answer_week as varchar) as offending_row
    from{{ref('mart_ama_module_weekly')}}
    where positive_answers > rated_answers
        or rated_answers > answers
    
    union all

    select
        'mart_ama_quality_weekly' as mart_name,
        cast(answer_week as varchar) as offending_row
    from {{ ref('mart_ama_quality_weekly') }}
    where positive_clean_answers > rated_clean_answers
       or rated_clean_answers > clean_answers
       or clean_answers > total_answers
)

select * from violations