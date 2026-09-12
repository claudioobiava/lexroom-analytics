-- Q2 — Customer Success: which workspaces show signs of deteriorating experience.

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
    is_flagged_for_review
from {{ ref('mart_workspace_risk') }}
where has_comparable_windows
order by acceptance_change_points
limit 10
