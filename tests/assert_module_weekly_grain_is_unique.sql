select
    module_tag,
    answer_week,
    count(*) as rows_in_group
from{{ref('mart_ama_module_weekly')}}
group by module_tag, answer_week
having count(*) > 1