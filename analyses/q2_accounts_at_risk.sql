-- Q2 — Customer Success: account health risk.
-- "Which workspaces show signs of deteriorating experience? Define your own
-- 'risk score' and justify the signals you chose."
--
-- Reads mart_workspace_risk, restricted to accounts whose two windows are
-- comparable. Rating counts sit next to the rates because a 45-point fall on 11
-- ratings and a 53-point fall on 56 ratings are not the same finding.
--
-- Expected: ws_0041 at -53.3 and ws_0051 at -45.8 are flagged; the next account
-- falls by 12.9. Any threshold between 15 and 45 points selects the same two.

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
