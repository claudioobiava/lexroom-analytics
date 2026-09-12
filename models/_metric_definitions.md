{% docs def_rated_answer %}

**Rated answer** — an AMA answer whose feedback carries a thumbs value inside the
documented contract (`1` or `-1`).

- **Defined in:** `int_ama_answers`, column `has_valid_rating`.
- **Consumed by:** all three marts.
- **Why it lives in one place:** 16 feedback rows carry values outside the
  contract (`-2`, `0`, `2`). Whether those count as ratings is a business
  decision, not a SQL detail. It is made once, here, so that Product, Customer
  Success and Leadership cannot arrive at three different denominators. A team
  that needs "ratings" reads this column; it does not re-derive them from
  `thumbs_raw`.
- **Not the same as:** an answer that has a feedback row. 16 answers have
  feedback and no valid rating.

{% enddocs %}


{% docs def_accepted_answer %}

**Accepted answer** — a rated answer whose thumbs value is `1`.

- **Defined in:** `int_ama_answers`, column `positive_rating`.
- **Consumed by:** all three marts.
- **Why it lives in one place:** an out-of-contract vote is not a negative vote.
  Not knowing the polarity and knowing it is negative are different states, and
  collapsing them would quietly depress every acceptance rate in the company.
  `stg_ama_feedback.is_positive` is therefore NULL for those rows, and only the
  intermediate layer decides to read that NULL as "not accepted".

{% enddocs %}


{% docs def_acceptance_rate %}

**Acceptance rate** — accepted answers divided by rated answers, as a percentage
rounded to one decimal.

    100 * accepted answers / rated answers

- **Denominator is rated answers, never all answers.** Only 26.9% of answers are
  rated. Dividing by all answers would produce a number that moves with how
  often people bother to vote, not with quality.
- **Defined in:** `mart_ama_module_weekly` (grain: module x week) and
  `mart_workspace_risk` (grain: workspace x comparison window). Same formula,
  two grains.
- **One deliberate variant exists.** `mart_ama_quality_weekly` publishes
  `accepted_rate_on_clean_percentage`, which applies the same formula to
  technically clean answers only. It is a different number and carries a
  different name on purpose — see `def_ama_quality_score`. Anyone comparing the
  two should expect them to differ.
- **Undefined, not zero, when there are no ratings.** A module-week with no
  votes returns NULL. Zero would read as "nobody liked it".

{% enddocs %}


{% docs def_clean_delivery %}

**Clean delivery** — an answer that reached the user without any of the three
technical defects found in the data.

An answer is *not* clean when any of these is true:

| Flag | Meaning | Answers |
|---|---|---|
| `has_latency_sentinel` | latency is exactly 900000 or 45000 ms | 33 |
| `has_negative_latency` | latency below zero | 33 |
| `has_no_retrieved_sources` | no sources retrieved, and the answer was not served from cache | 54 |

119 answers carry at least one defect; one carries two. 10,881 of 11,000 are
clean.

- **Defined in:** `stg_ama_events`, column `clean_delivery`.
- **Consumed by:** `mart_ama_quality_weekly`.
- **The cache exception is deliberate.** A cached answer legitimately retrieves
  no sources, so `retrieved_chunks = 0` only counts as a defect when
  `is_cached` is false. 12 answers fall in that exception.
- **Open question.** Whether 900000 and 45000 are timeouts, defaults or real
  latencies has not been confirmed with Engineering. See `QUESTIONS.md`. The
  flag is named for what was observed, not for a cause that was assumed.

{% enddocs %}


{% docs def_ama_quality_score %}

**AMA Quality Score** — the proposed North Star metric for AMA.

    AMA Quality Score = P(clean delivery) x P(accepted | clean and rated)

    = clean_delivery_rate_percentage * accepted_rate_on_clean_percentage / 100

- **Grain:** one row per week, whole platform.
- **Window:** calendar week, Monday to Sunday.
- **Reads as:** out of 100 answers, how many arrive with no technical defect
  *and* earn a thumbs up.
- **Why a product and not a weighted sum.** A weighted sum needs weights, and
  any weights chosen here would be indefensible. A product of two probabilities
  needs none: it is the chance an answer clears both gates.
- **Acceptance is measured on clean answers only.** An answer delivered broken
  that still gets a thumbs up must not lift the satisfaction component; its
  defect is already counted in the first one.
- **The score is computed from the two rounded components**, so anyone can
  reproduce it by hand from the two columns next to it.
- **Known limitation.** Clean delivery sits between 98.4% and 100.0% in all
  eleven weeks. On this data the composite tracks acceptance almost exactly. The
  delivery component is in the formula so that a technical regression cannot
  hide behind stable satisfaction, not because it is explaining anything today.
- **Context columns, outside the formula:** `rating_coverage_percentage` and
  `days_with_answers` say how much weight that week's score can carry.

{% enddocs %}


{% docs def_answer_week %}

**Answer week** — the Monday of the calendar week in which the answer was
produced, derived from the event timestamp in UTC.

- **Defined in:** `stg_ama_events`, column `answer_week`. Every weekly
  aggregate in the project groups on it; none re-truncates a timestamp.
- **UTC is not cosmetic.** 85 of 11,000 events change week between UTC and
  Europe/Rome. The DuckDB profile pins the session timezone so the boundary
  cannot drift with whoever runs the model.
- **Portability note.** DuckDB's `date_trunc('week', ...)` starts the week on
  Monday. BigQuery's `DATE_TRUNC(x, WEEK)` starts it on Sunday and would need
  `WEEK(MONDAY)` to reproduce these boundaries. Same code, different weeks, no
  error raised.

{% enddocs %}


{% docs def_comparison_windows %}

**Recent and prior windows** — the two four-week halves used to measure change.

The eight most recent weeks present in the data are split into the four most
recent (`recent`) and the four before them (`prior`).

- **Defined in:** `mart_workspace_risk`.
- **Built by ranking the distinct weeks, not by date arithmetic.** Ranking
  behaves identically on DuckDB and BigQuery; interval syntax does not.
- **The data holds eleven complete weeks**, 2 February to 19 April 2026. The
  comparison uses the most recent eight, as the brief asks. No week is partial.

{% enddocs %}