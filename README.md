# Lexroom AMA analytics

A dbt project answering three questions about AMA from the five raw extracts provided. Seven models over three layers, with the metric definitions, the tests and the owner of each question declared in the project.

## Setup

Python 3.11 and DuckDB. No warehouse and no credentials.

```bash
pip install dbt-core==1.12.4 dbt-duckdb==1.11.0

cd lexroom-analytics
dbt build
dbt docs generate && dbt docs serve
```

`profiles.yml` is in the project root and dbt reads it from the working directory. The CSVs are read in place from `data/`, so `dbt build` works from a clean clone.

To run one of the `/analyses` queries: `dbt compile`, then take the resolved SQL from `target/compiled/lexroom_analytics/analyses/`, paste it into `query.sql` and run `python check.py`.

## Models

| Model | Grain |
|---|---|
| `stg_ama_events` | one row per AMA answer |
| `stg_ama_feedback` | one row per feedback submission |
| `stg_workspaces` | one row per workspace |
| `int_ama_answers` | one row per AMA answer, with its feedback and account attached |
| `mart_ama_module_weekly` | one row per module per week |
| `mart_workspace_risk` | one row per workspace, recent four weeks vs the four before |
| `mart_ama_quality_weekly` | one row per week, whole platform |

`raw_users` is declared as a source but no model reads it: role and deletion status did not change any of the three answers.

## Answers

Queries are in `/analyses`, owners in `models/_exposures.yml`.

**Q1 — Product.** Acceptance falls from 74.6% to 64.6% between the two four-week windows, but two accounts out of eighty carry seven of those ten points. With `ws_0041` and `ws_0051` removed the residual fall is 3.0 points on 408 recent ratings, which is 1.2 standard errors and not distinguishable from chance.

This says the drop is account-specific. It does not say the 71–74% level is good. And nothing can be said about `amministrativo`, which is below the reliability floor in every week of the period.

**Q2 — Customer Success.** The risk score is the change in acceptance rate between the two windows, for accounts with at least ten ratings in both. `ws_0041` (DE, enterprise) falls 53.3 points on 166 then 56 ratings, `ws_0051` (IT, enterprise) falls 45.8 points on 26 then 11. The next account falls 12.9. Any threshold between 15 and 45 points selects the same two.

**Q3 — Leadership.** The proposed North Star is:

```
AMA Quality Score = P(clean delivery) × P(accepted | clean and rated)
```

Out of 100 answers, how many arrive without a technical defect and get a thumbs up. Grain is one row per week, whole platform; the window is the calendar week, Monday to Sunday, in UTC. It runs between 76.5 and 63.0 across the eleven weeks. The second component is measured on rated clean answers, so reading the score as a statement about all answers assumes the two behave alike. Full definition in `def_ama_quality_score`.

## Design decisions

**Definitions live in one model.** `has_valid_rating`, `positive_rating` and `has_unknown_workspace` are defined once in `int_ama_answers`. The marts differ in grain and scope, never in what a rating is. `models/_metric_definitions.md` records for each definition where it lives, who consumes it, and why it is not re-derived downstream.

**The North Star is a product, not a weighted sum.** Weights would have to be invented; a product of two probabilities needs none.

**The module mapping is a seed.** `seeds/module_tag_mapping.csv` holds the raw value, the canonical value and the reason. Every normalisation is reviewable without reading SQL.

**Thresholds are dbt variables**, not literals inside a WHERE clause.

**`created_at` becomes `answered_at`** at the intermediate layer, because `created_at` means something different in each of the five raw tables.

**The DuckDB session timezone is pinned to UTC.** `date_trunc('week', ...)` uses the session timezone, and 85 of 11,000 events change week between UTC and Europe/Rome.

**Window boundaries come from ranking weeks, not date arithmetic**, which keeps the SQL portable to BigQuery.

**Counts are published next to every rate**, so a 45-point fall on 11 ratings is not read as the same finding as a 53-point fall on 56.

**Two relationship tests warn instead of failing.** Eight answers point to a missing workspace and fifty feedback rows to a missing event. Both are set to warn at today's level and fail above it (`>10`, `>60`), so they track whether a known problem grows.

## Trade-offs

- Rate-based metrics use the 27% of answers that receive a valid vote, while clean delivery is measured on all of them. Rated and unrated answers can be compared on observable attributes, but nothing in the data establishes how the unrated ones would have been voted, so every rate here carries that assumption.
- `mart_workspace_risk` needs ratings in both windows, so it cannot see an account that goes quiet. Its exposure is marked `maturity: low`.
- Clean delivery is between 98.4% and 100.0% in all eleven weeks, so the composite currently tracks acceptance closely. The delivery component is there so a technical regression cannot hide, not because it explains anything today.
- The reliability floor of 20 rated answers still leaves a 95% interval of about ±19 points. Raising it to 30 cost 7 readable module-weeks out of 48 for roughly 3.5 points of precision, so the floor keeps coverage and the counts are published next to the rates.
- The last week rests on 20 ratings. Its 50.0% is noise.

## Known data issues

| Issue | Count | Handling |
|---|---:|---|
| Answers referencing a workspace that does not exist | 8 | Flagged, excluded only from the account mart |
| Feedback referencing an event that does not exist | 50 | Cannot join to an answer, so they never enter a count |
| `thumbs` outside 1 and −1 | 16 | Values −2, 0 and 2 are not counted as ratings; `is_positive` is NULL rather than false |
| `module_tag` spelled `civil` | 85 | Mapped to `civile` in the seed; it appears in all three countries, so not a localisation |
| `response_latency_ms` of exactly 900000 or 45000 | 33 | Treated as missing, flagged |
| Negative `response_latency_ms` | 33 | Treated as missing, flagged separately |
| `retrieved_chunks = 0` on a non-cached answer | 54 | Flagged; 12 cached answers with zero chunks are excluded from the flag |

Missing workspace country is replaced with `unknown` and flagged. Exact duplicate rows are removed in staging with `SELECT DISTINCT`.

119 of 11,000 answers trigger at least one flag, one triggers two. The flags encode the assumptions below, not confirmed facts about the system.

## Assumptions to confirm

Each of these is already built into the models. Each needs ten minutes with the team.

1. **Rating scale.** `thumbs` is −2, 0 or 2 on 16 rows. Assumed to be outside the documented contract rather than an undocumented scale.
2. **Module identity.** `module_tag` is `civil` on 85 answers in all three countries. Assumed a typo for `civile` rather than a separate module.
3. **Orphaned feedback.** Fifty feedback rows reference events that are not in the extract. Assumed to be events that did not land, rather than retry duplicates.
4. **Latency values.** Latency is exactly 900000 or 45000 on 33 answers. Assumed not to be real measurements, so treated as missing rather than as very slow answers.

## What I left out

- The optional DORA metric on `raw_engineering_prs.csv`. The brief says to skip it past three hours, and it would have been past.
- A staging model for `raw_users`.
- The cause of the volume decline. Weekly answers fall from 1,875 at the peak to 102 in the final week. The extract covers eleven complete calendar weeks, which rules out a truncated final week but does not establish that event collection is complete, so the decline could still be partly an ingestion effect. Separating the two was outside the three questions.
- A dashboard, which the brief says is not evaluated.
- Working notes. The hypothesis-by-hypothesis write-ups I produced while investigating data quality are not in the repository; their conclusions are in "Known data issues" and "Assumptions to confirm".

## What I would do next

1. Add a usage signal to `mart_workspace_risk` so a silent account is visible next to a complaining one. This is the largest gap.
2. Compare rated and unrated answers on observable attributes, to see whether the 27% sample looks like the rest.
3. Publish confidence intervals next to the rates and use them to replace the fixed reliability floor.
4. Review the two warn thresholds on a schedule; they are set to today's observed levels, which is a starting point rather than a standard.
5. Confirm the four assumptions above and record each decision in the seed or the definitions file.

## Time spent

About four and a half hours against the three suggested. The overrun is in the data-quality work: six hypotheses tested and documented before any model was written. Keeping to three hours I would still have built the mapping seed, the defect flags and the shared definitions, and cut the write-ups, the standard-error check and the threshold sensitivity analysis, keeping only their conclusions. The one thing I would not cut is the check that attributes the Q1 drop to two accounts, because without it the obvious answer to Q1 is wrong.

## AI tools

I used Claude throughout, as the brief allows. The architecture, the model grains, the hypotheses to test and the decisions about scope are mine, including several where I overruled it. Claude worked on the operational side: drafting SQL to my specification, reviewing what I had written, catching errors, and arguing with me about design. I ran every query myself, and every figure in this document was checked against the database before it was written down. ChatGPT was used to review and edit this write-up.