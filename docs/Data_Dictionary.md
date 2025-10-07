# Data Dictionary — ATP Match–Player Panel

**Dataset (logical)**: `atp_match_player_panel`  
**Purpose**: provide a **longitudinal, consistent, and reproducible** dataset for sports analytics, with the unit of analysis **(match, player)**.  
**Scope**: data construction; the included modeling is a **validation baseline** (not a SOTA benchmark).  
**Granularity**: one row = *(match, player)* → **2 rows per match**  
**Primary key (PK)**: (`id`, `player_code`)  
**Time coverage**: **configurable** — depends on your scraping setup and parameters.  
*Examples*: 1990–present, 1999–2025, or any user-defined span. The coverage is up to the user. We recommend to cover all atp history if the budget is able to do it. 
**Snapshot date**: `2025-09-24` 
**Pipeline version**: `v0.1.0` 

---

## Temporal semantics & anti-leakage

All **rolling/progressive** metrics and temporal joins are computed in **strict chronological order** and **exclude the current match**.  
Examples:
- Rankings **as of t−1 day** relative to `tournament_start_dtm`.  
- Recent-form windows (5/10 matches) are **lagged**.  
- Elo and surface specialization are **pre-match**.

> **Guarantee**: the two rows of the same match (player & opponent) are **never split across folds** in validation (grouping by `id`).

---

## Conventions & units

- **Countries**: ISO-3 (`ESP`, `USA`, `ARG`, …).  
- **Height**: centimeters (`cm`) · **Weight**: kilograms (`kg`).  
- **Surface**: {`Clay`, `Grass`, `Hard`, `Carpet`} · **Indoor/Outdoor**: {`Indoor`, `Outdoor`}.  
- **Probabilities**: [0, 1] · **Percentages**: [0, 1] (not %).  
- **Elo**: points; typical differences ~ [−400, +400].  
- **Log-ratios**: `log(player_avg + 1e-6) − log(opponent_avg + 1e-6)`.
- **Handedness**: `player_handedness`, `opponent_handedness` ∈ {`Left`, `Right`, `Unknown`}.
- **Backhand type**: `player_backhand`, `opponent_backhand` ∈ {`one_handed`, `two_handed`, `Unknown`}.
- **Best-of sets**: `best_of` ∈ {`3`, `5`} (GS→`5`; otherwise inferred; fallback `3`).
- **Rank-trend categories** (tokens intentionally in Spanish):
  - `player_rank_trend_4w_cat`, `opponent_rank_trend_4w_cat` ∈ {`subida`, `estable`, `bajada`} (adaptive threshold ~±2% of max(rank_t, rank_t−4w), floor 1).
  - `player_rank_trend_12w_cat`, `opponent_rank_trend_12w_cat` ∈ {`subida`, `estable`, `bajada`} (adaptive threshold ~±5% of idem).
- **General vs surface probability delta (categorical)**:
  - `player_win_prob_diff_general_vs_surface_cat`, `opponent_win_prob_diff_general_vs_surface_cat` ∈ {`negative`, `neutral`, `positive`}, with cuts (−∞, −0.2], (−0.2, 0.2], (0.2, ∞).
- **Home flag**: `player_home`, `opponent_home` ∈ {`0`, `1`} (1 if citizenship == tournament country).
- **Favourite surface flag**: `player_favourite_surface`, `opponent_favourite_surface` ∈ {`0`, `1`} (1 if current surface = long-run argmax surface).
- **Recent form flags** (lagged windows):  
  - `player_good_form_5`, `player_good_form_10`, `opponent_good_form_5`, `opponent_good_form_10` ∈ {`0`, `1`} (1 if rolling win ratio > 0.7 over last 5/10 matches).
- **Previous tournament winner**: `player_won_previous_tournament`, `opponent_won_previous_tournament` ∈ {`0`, `1`}.
- **Rest & schedule flags** (based on gap since previous tournament):
  - `*_back_to_back_week` ∈ {`0`, `1`} (1 if gap ≤ 7 days).
  - `*_two_weeks_gap` ∈ {`0`, `1`} (1 if 10–16 days).
  - `*_long_rest` ∈ {`0`, `1`} (1 if ≥ 21 days).
- **Adaptation/change flags** (vs previous tournament):  
  - `*_country_changed`, `*_surface_changed`, `*_indoor_changed`, `*_continent_changed` ∈ {`0`, `1`}.
- **Red-eye risk**: `player_red_eye_risk`, `opponent_red_eye_risk` ∈ {`0`, `1`} (1 if inter-continent change **and** back-to-back week).
- **H2H availability**: `has_player_h2h_surface`, `has_player_h2h_full` ∈ {`0`, `1`} (1 if H2H exists on surface / overall).

---

## Sources & lineage

- **ATP scraping** (matches, players, tournaments, stats) → `ETL/Extractor/*`.  
- **Official ATP rankings** (HTML → CSV) → `Transform/Ranking_Scraping/*`.  
- **SQL staging & business rules** → `ETL/SQL/*` (tables, UDFs/procs, views).  
- **Feature engineering** → `Transform/DataTransform*.R`.  
- **Validation modeling** (XGBoost baseline + calibration) → `MODEL/model1.ipynb`.

> **Note**: For pre-1999 periods you may optionally *pre-seed* with historical data (e.g., Jeff Sackmann). Cite and respect the original license if used.

---

## Data availability

> ⚠️ A **minimal demo sample** is included for reproducibility:  
> `Data_Sample/Data_Sample.csv` (~20 rows, all columns).  
> The full long-horizon dataset is **proprietary** and not published here.  
> Access may be considered upon request for research/collaboration.

---

## Dataset invariants & QA

- **PK**: (`id`, `player_code`) is **unique**.  
- **Cardinality**: exactly **2 rows per `id`**.  
- **Temporal integrity**: no feature leaks future information (as-of joins, lags,rolls,...).  
- **Closed domains**: `surface`, `indoor_outdoor`, trend categories.  
- **Plausible ranges**: percentages ∈ [0,1]; Elo diffs ~ [−400, +400].  
- **Missingness flags**: features with imputation/absence expose `_was_na`.

---

## Versioning & reproducibility

- **Python environment**: see `requirements.txt` / `environment.yml`.  
- **R environment**: packages listed in README (recommend `renv`).  
- **Makefile**: targets for DB, scraping, ETL, and feature build; demo mode without Oracle using the sample.

---

<a id="index"></a>
## Column index (navigation guide)

> The next section documents each column with: **name**, **description**, **dtype**, **unit/domain**, **missing policy**, **temporal semantics**, **definition/formula**, **source/calculation**, **range/values & outliers** (if needed) and **notes**.

*NOTE : Each section is sorted alphabetically, with opponent fields listed first. If you’re looking for an opponent variable and its description defers to the player version, please refer to the corresponding player variable*

- [Clutch & tie-break metrics (6)](#clutch)
- [Dropped variables](#dropped)
- [Efficiencies & differentials (6)](#efficiencies)
- [Elo & probabilities (7)](#elo)
- [Head-to-Head (8)](#h2h)
- [Home flags (2)](#home)
- [Identifiers & match/tournament metadata (14)](#identifiers)
- [Identity & basic player info (26)](#identity)
- [Log-ratios (player vs opponent) (11)](#logratios)
- [Missingness indicators (_was_na flags) (34)](#missingness)
- [Play statistics (progressive averages) (18)](#playstats)
- [Ranking & trajectory (18)](#ranking)
- [Recent form, consistency & in-tournament load (21)](#recentform)
- [Rest, schedule & travel (26)](#rest)
- [Surface specialization (7)](#surface)
- [Target variable (1)](#target)
- [Titles & prestige (2)](#titles)

---

<a id="clutch"></a>
## Clutch & Tie-Break Metrics

### `opponent_clutch_bp_conv_gap`

* **Description:** Opponent's difference between break points converted percentage and return games won percentage
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.0864, 0.6007]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_clutch_bp_conv_gap
  * *Typical Values:* Median: 0.1760, Mean: 0.1759
  * *Notes:* Same consistently positive pattern as player version
* **Source/Calculation:** `opponent_break_points_converted_pct_avg - opponent_return_games_won_pct_avg`
* **Smoothing Details:**

  * Same mean-based smoothing with α=10 prior
  * Uses opponent's cumulative match count for credibility calculation

### `opponent_clutch_bp_save_gap`

* **Description:** Opponent's difference between break points saved percentage and service games won percentage
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.4729, 0.1170]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_clutch_bp_save_gap
  * *Typical Values:* Median: -0.1901, Mean: -0.1915
  * *Notes:* Same consistently negative pattern as player version
* **Source/Calculation:** `opponent_break_points_saved_pct_avg - opponent_service_games_won_pct_avg`
* **Smoothing Details:**

  * Same smoothing methodology as player version
  * Uses opponent's match history for credibility weighting

### `opponent_clutch_tiebreak_adj`

* **Description:** Opponent's difference between tie-breaks won percentage and total points won percentage
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.4227, 0.4289]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_clutch_tiebreak_adj
  * *Typical Values:* Median: 0.0031, Mean: 0.0037
  * *Notes:* Same nearly symmetric distribution as player version
* **Source/Calculation:** `opponent_tiebreaks_won_pct_avg - opponent_total_points_won_pct_avg`
* **Smoothing Details:**

  * Same mean-based smoothing methodology as player version
  * Uses opponent's match history for credibility weighting

### `player_clutch_bp_conv_gap`

* **Description:** Difference between break points converted percentage and return games won percentage, measuring return performance under pressure
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.0864, 0.6007]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.0864, Max: 0.6007, P99: 0.2774
  * *Typical Values:* Median: 0.1760, Mean: 0.1759
  * *Notes:* Consistently positive (expected - break point conversion is key return skill)
* **Source/Calculation:** `player_break_points_converted_pct_avg - player_return_games_won_pct_avg`
* **Smoothing Details:**

  * **Type:** Mean-based smoothing (α=10)
  * **Prior:** Global mean of the variable
  * **Credibility Weight:** Based on player's match exposure history
  * **Interpretation:** Higher positive values indicate better clutch returning ability

### `player_clutch_bp_save_gap`

* **Description:** Difference between break points saved percentage and service games won percentage, measuring serve performance under pressure
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.4729, 0.1170]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.4729, Max: 0.1170, P99: -0.0895
  * *Typical Values:* Median: -0.1901, Mean: -0.1915
  * *Notes:* Consistently negative (expected - break points are high-pressure situations)
* **Source/Calculation:** `player_break_points_saved_pct_avg - player_service_games_won_pct_avg`
* **Smoothing Details:**

  * **Type:** Mean-based smoothing (α=10)
  * **Prior:** Global mean of the variable
  * **Credibility Weight:** `n / (n + α)` where n = min(player_prev_matches, opponent_prev_matches)
  * **Missing Handling:** NA values imputed with prior mean during smoothing

### `player_clutch_tiebreak_adj`

* **Description:** Difference between tie-breaks won percentage and total points won percentage, measuring tie-break performance vs overall ability
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.4227, 0.4289]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=20 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.4227, Max: 0.4289, P99: 0.1739
  * *Typical Values:* Median: 0.0031, Mean: 0.0037
  * *Notes:* Nearly symmetric around zero; 50% of players perform similarly in tie-breaks vs overall
* **Source/Calculation:** `player_tiebreaks_won_pct_avg - player_total_points_won_pct_avg`
* **Smoothing Details:**

  * **Type:** Mean-based smoothing (α=10)
  * **Prior:** Global mean of the variable (approximately 0)
  * **Credibility Weight:** `n / (n + α)` where n depends on match exposure
  * **Interpretation:** Positive values indicate tie-break specialist; negative values indicate choke tendency

[⬆ Index](#index)

---

<a id="dropped"></a>
## Dropped Variables

*Note: These variables were calculated during the pipeline but dropped from the final dataset due to redundancy with other features. They are documented here for transparency, and users may choose to include them in their own implementations.*

### `consistency_log_ratio_diff`

* **Description:** Difference between player and opponent consistency log-ratios
* **Data Type:** Float
* **Unit/Domain:** Difference in log-ratio [-0.4134, 0.4134]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.4134, Max: 0.4134, P99: 0.1713
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Perfectly symmetric distribution around 0
* **Source/Calculation:** `player_consistency_log_ratio - opponent_consistency_log_ratio`
* **Dropped Reason:** Redundant with direct comparison of `player_consistency` and `opponent_consistency`

### `log_ratio_return_1st_won_pct`

* **Description:** Log-ratio of return points won against first serve between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-12.964, 12.964]
* **Missingness Policy:** Some missing (11.02% NAs) - inherited from component metrics
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -12.964, Max: 12.964, P99: 0.5475
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Wide range but 95% of values within ±0.2609
* **Source/Calculation:** `log(player_return_1st_won_pct_avg + ε) - log(opponent_return_1st_won_pct_avg + ε)`
* **Dropped Reason:** Redundant with other return efficiency metrics and log-ratios

### `log_ratio_serve_1st_won_pct`

* **Description:** Log-ratio of first serve points won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-13.379, 13.379]
* **Missingness Policy:** Some missing (11.02% NAs) - inherited from component metrics
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -13.379, Max: 13.379, P99: 0.2648
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tighter distribution than return log-ratio; 95% within ±0.1428
* **Source/Calculation:** `log(player_serve_1st_won_pct_avg + ε) - log(opponent_serve_1st_won_pct_avg + ε)`
* **Dropped Reason:** Redundant with `player_serve_1st_efficiency` and other serve dominance metrics

### `opponent_consistency_log_ratio`

* **Description:** Log-ratio of opponent's consistency (|win_ratio_5 - win_ratio_10|)
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.5501, 0.3288]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_consistency_log_ratio
  * *Typical Values:* Median: -0.0829, Mean: -0.0891
  * *Notes:* Same consistently negative pattern as player version
* **Source/Calculation:** Log-ratio based on opponent's recent form consistency metrics (ideam as `player_consistency_log_ratio`)
* **Dropped Reason:** Redundant with `opponent_consistency` (absolute difference version preferred)

### `opponent_elo_pre`

* **Description:** Opponent's general Elo rating before the match
* **Data Type:** Float
* **Unit/Domain:** Elo points [1004, 2934]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_elo_pre
  * *Typical Values:* Median: 1775, Mean: 1797
  * *Notes:* Same normal distribution pattern as player version
* **Source/Calculation:** General Elo rating system updated after each match
* **Dropped Reason:** Redundant with `elo_diff` and `opponent_elo_surface_pre`

### `opponent_prestigious_titles`

* **Description:** Total count of prestigious titles won by opponent (including Grand Slams) like Masters 1000,ATP Tour or Olimpic Games.
* **Data Type:** Integer
* **Unit/Domain:** Title count [0, 103]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Cumulative count up to current match (progressive)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_prestigious_titles
  * *Typical Values:* Median: 0, Mean: 1.362
  * *Notes:* Same extremely right-skewed distribution as player version
* **Source/Calculation:** Cumulative count of prestigious tournament wins
* **Dropped Reason:** Redundant with `opponent_gs_titles`.

### `opponent_return_1st_won_pct_avg`

* **Description:** Opponent's progressive average of return points won against first serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 0.900]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 0.900, P99: 0.3965
  * *Typical Values:* Median: 0.3048, Mean: 0.3020
  * *Notes:* Lower values expected (first serves are harder to return); 95% between 0.2315-0.3562
* **Source/Calculation:** Cumulative average of `opponent_first_serve_return_won / opponent_first_serve_return_total`
* **Dropped Reason:** Incorporated into `opponent_return_1st_efficiency` ratio

### `opponent_return_2nd_won_pct_avg`

* **Description:** Opponent's progressive average of return points won against second serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_return_2nd_won_pct_avg
  * *Typical Values:* Median: 0.5019, Mean: 0.4970
  * *Notes:* Same slightly left-skewed distribution as player version
* **Source/Calculation:** Cumulative average of `opponent_second_serve_return_won / opponent_second_serve_return_total`
* **Dropped Reason:** Incorporated into `opponent_return_1st_vs_2nd_diff`

### `opponent_serve_1st_won_pct_avg`

* **Description:** Opponent's progressive average of points won on first serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_serve_1st_won_pct_avg
  * *Typical Values:* Median: 0.6951, Mean: 0.6920
  * *Notes:* Same normal distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_first_serve_points_won / opponent_first_serve_points_total`
* **Dropped Reason:** Incorporated into `opponent_serve_1st_efficiency` ratio

### `opponent_surface_effect`

* **Description:** Opponent's surface-specific Elo rating normalized by surface mean
* **Data Type:** Float
* **Unit/Domain:** Normalized ratio [0.6921, 1.4945]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_surface_effect
  * *Typical Values:* Median: 0.9884, Mean: 1.0000 (centered)
  * *Notes:* Same centered distribution as player version
* **Source/Calculation:** `opponent_elo_surface_pre / mean(opponent_elo_surface_pre)` by surface
* **Dropped Reason:** Redundant with `opponent_elo_surface_pre` and `opponent_surface_specialization`

### `opponent_tiebreaks_won_pct_avg`

* **Description:** Opponent's progressive average of tie-breaks won percentage
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Higher missingness (14.37% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_tiebreaks_won_pct_avg
  * *Typical Values:* Median: 0.5082, Mean: 0.5040
  * *Notes:* Same nearly symmetric distribution as player version
* **Source/Calculation:** Cumulative average of `opponent_tiebreaks_won / (player_tiebreaks_won + opponent_tiebreaks_won)`
* **Dropped Reason:** Incorporated into `opponent_clutch_tiebreak_adj`

### `opponent_total_matches`

* **Description:** Opponent's total career matches played before current match
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1519]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_total_matches
  * *Typical Values:* Median: 170, Mean: 238.4
  * *Notes:* Same right-skewed distribution as player version
* **Source/Calculation:** Cumulative count from career match database
* **Dropped Reason:** Redundant with `opponent_prev_matches`

### `opponent_turned_pro`

* **Description:** Year when opponent turned professional
* **Data Type:** Integer
* **Unit/Domain:** Year [0, 2025] (For 99-25).(0 indicates unknown/never turned pro)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Static player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_turned_pro
  * *Typical Values:* Median: 2006, Mean: 2000
  * *Notes:* Same distribution pattern as player version
* **Source/Calculation:** Player biographical data
* **Dropped Reason:** Redundant with `opponent_years_experience`

### `opponent_win_prob`

* **Description:** General Elo-implied probability of opponent winning (all surfaces)
* **Data Type:** Float
* **Unit/Domain:** Probability [0.0012, 0.9988]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0012, Max: 0.9988, P99: 0.9316
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (symmetric)
  * *Notes:* Perfectly symmetric distribution around 0.5 (complement of player_win_prob)
* **Source/Calculation:** Derived from general Elo ratings using logistic function
* **Dropped Reason:** Redundant with `player_win_prob` (since opponent_win_prob = 1 - player_win_prob)

### `opponent_win_prob_log_ratio`

* **Description:** Log-ratio of opponent's general vs surface-specific win probabilities
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-2.8495, 3.9707]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_prob_log_ratio
  * *Typical Values:* Median: 0.0000, Mean: 0.0588
  * *Notes:* Same slightly right-skewed distribution as player version
* **Source/Calculation:** `log(opponent_win_prob) - log(opponent_win_prob_surface)`
* **Dropped Reason:** Redundant with `opponent_win_prob_diff_general_vs_surface_cat`

### `opponent_win_prob_surface`

* **Description:** Surface-specific Elo-implied probability of opponent winning
* **Data Type:** Float
* **Unit/Domain:** Probability [0.0076, 0.9924]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0076, Max: 0.9924, P99: 0.8659
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (symmetric)
  * *Notes:* Tighter distribution than general win probability
* **Source/Calculation:** Derived from surface-specific Elo ratings
* **Dropped Reason:** Redundant with `player_win_prob_surface` (complement relationship)

### `player_consistency_log_ratio`

* **Description:** Log-ratio of player's consistency (|win_ratio_5 - win_ratio_10|)
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.5501, 0.3288]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.5501, Max: 0.3288, P99: 0.0467
  * *Typical Values:* Median: -0.0829, Mean: -0.0891
  * *Notes:* Consistently negative values indicate typical consistency patterns
* **Source/Calculation:** Log-ratio based on recent form consistency metrics log(`player_win_ratio_last_5_matches`\ `opponent_win_ratio_last_5_matches`)
* **Dropped Reason:** Redundant with `player_consistency` (absolute difference version preferred)

### `player_elo_pre`

* **Description:** Player's general Elo rating before the match
* **Data Type:** Float
* **Unit/Domain:** Elo points [1004, 2934]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1004, Max: 2934, P99: 2460
  * *Typical Values:* Median: 1775, Mean: 1797
  * *Notes:* Normal distribution centered around 1800; 95% between 1465-2217
* **Source/Calculation:** General Elo rating system updated after each match
* **Dropped Reason:** Redundant with `elo_diff` and `player_elo_surface_pre` (surface-specific Elo preferred)

### `player_prestigious_titles`

* **Description:** Total count of prestigious titles won by player (including Grand Slams)
* **Data Type:** Integer
* **Unit/Domain:** Title count [0, 103]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Cumulative count up to current match (progressive)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 103, P99: 23
  * *Typical Values:* Median: 0, Mean: 1.362
  * *Notes:* Extremely right-skewed; 75% of players have 0 prestigious titles
* **Source/Calculation:** Cumulative count of prestigious tournament wins
* **Dropped Reason:** Redundant with `player_gs_titles`.

### `player_return_1st_won_pct_avg`

* **Description:** Player's progressive average of return points won against first serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 0.900]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs in early career matches
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 0.900, P99: 0.3965
  * *Typical Values:* Median: 0.3048, Mean: 0.3020
  * *Notes:* Lower values expected (first serves are harder to return); 95% between 23.1%-35.6%
* **Source/Calculation:** Cumulative average of `player_first_serve_return_won / player_first_serve_return_total`
* **Dropped Reason:** Incorporated into `player_return_1st_efficiency` ratio

### `player_return_2nd_won_pct_avg`

* **Description:** Player's progressive average of return points won against second serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs in early career matches
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 1.000, P99: 0.5882
  * *Typical Values:* Median: 0.5019, Mean: 0.4970
  * *Notes:* Slightly left-skewed; 95% of values between 0.4266-0.5474
* **Source/Calculation:** Cumulative average of `player_second_serve_return_won / player_second_serve_return_total`
* **Dropped Reason:** Incorporated into `player_return_1st_vs_2nd_diff` for comparative analysis

### `player_serve_1st_won_pct_avg`

* **Description:** Player's progressive average of points won on first serve
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs in early career matches
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 1.000, P99: 0.8030
  * *Typical Values:* Median: 0.6951, Mean: 0.6920
  * *Notes:* Normal distribution centered around 69%; 95% between 60.9%-76.5%
* **Source/Calculation:** Cumulative average of `player_first_serve_points_won / player_first_serve_points_total`
* **Dropped Reason:** Incorporated into `player_serve_1st_efficiency` ratio for better interpretability

### `player_surface_effect`

* **Description:** Player's surface-specific Elo rating normalized by surface mean (z-score-like ratio)
* **Data Type:** Float
* **Unit/Domain:** Normalized ratio [0.6921, 1.4945]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.6921, Max: 1.4945, P99: 1.2581
  * *Typical Values:* Median: 0.9884, Mean: 1.0000 (centered)
  * *Notes:* Distribution centered at 1.0 by construction
* **Source/Calculation:** `player_elo_surface_pre / mean(player_elo_surface_pre)` by surface
* **Dropped Reason:** Redundant with `player_elo_surface_pre` and `player_surface_specialization`

### `player_tiebreaks_won_pct_avg`

* **Description:** Player's progressive average of tie-breaks won percentage
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Higher missingness (14.37% NAs) - requires minimum 5 tie-break appearances
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 1.000, P99: 0.7500
  * *Typical Values:* Median: 0.5082, Mean: 0.5040
  * *Notes:* Nearly symmetric distribution around 0.5; 95% between 0.3438-0.6429
* **Source/Calculation:** Cumulative average of `player_tiebreaks_won / (player_tiebreaks_won + opponent_tiebreaks_won)`
* **Dropped Reason:** Incorporated into `player_clutch_tiebreak_adj` for clutch performance analysis

### `player_total_matches`

* **Description:** Player's total career matches played before current match
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1519]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1519, P99: 921
  * *Typical Values:* Median: 170, Mean: 238.4
  * *Notes:* Right-skewed distribution; 25% of players have ≤54 matches
* **Source/Calculation:** Cumulative count from career match database
* **Dropped Reason:** Redundant with `player_prev_matches` (which is the same cumulative count)

### `player_turned_pro`

* **Description:** Year when player turned professional (entered ATP circuit)
* **Data Type:** Integer
* **Unit/Domain:** Year [1968, 2025] (For 99-25).(0 indicates unknown/never turned pro)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Static player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 2025, P99: 2022
  * *Typical Values:* Median: 2006, Mean: 2000
  * *Notes:* Distribution spans several decades; 0 values represent missing data
* **Source/Calculation:** Player biographical data
* **Dropped Reason:** Redundant with `player_years_experience` (which is computed as `year - player_turned_pro`)

### `player_win_prob`

* **Description:** General Elo-implied probability of player winning (all surfaces)
* **Data Type:** Float
* **Unit/Domain:** Probability [0.0012, 0.9988]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0012, Max: 0.9988, P99: 0.9316
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (symmetric)
  * *Notes:* Perfectly symmetric distribution around 0.5
* **Source/Calculation:** Derived from general Elo ratings using logistic function
* **Dropped Reason:** Redundant with `player_win_prob_surface` and `elo_diff` (users typically prefer surface-specific win probability)

### `player_win_prob_log_ratio`

* **Description:** Log-ratio of player's general vs surface-specific win probabilities
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-2.8495, 3.9707]
* **Missingness Policy:** Rarely missing (2 NAs, ~0%)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -2.8495, Max: 3.9707, P99: 1.2400
  * *Typical Values:* Median: 0.0000, Mean: 0.0588
  * *Notes:* Slightly right-skewed; 95% of values between -0.4190 and 0.7141
* **Source/Calculation:** `log(player_win_prob) - log(player_win_prob_surface)`
* **Dropped Reason:** Redundant with `player_win_prob_diff_general_vs_surface_cat` (categorical version preferred)

[⬆ Index](#index)

---

<a id="efficiencies"></a>
## Efficiencies & Differentials

### `opponent_return_1st_efficiency`

* **Description:** Opponent's ratio of return points won on first serve to return games won percentage
* **Data Type:** Float
* **Unit/Domain:** Efficiency ratio [0.5000, 1.0000]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when components missing
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_return_1st_efficiency
  * *Typical Values:* Median: 1.0000, Mean: 0.9026
  * *Notes:* Same bimodal distribution pattern as player version
* **Source/Calculation:** `opponent_return_1st_won_pct_avg / opponent_return_games_won_pct_avg`
* **Calculation Details:**

  * Same calculation methodology and smoothing as player version
  * Critical for evaluating opponent's return efficiency

### `opponent_return_1st_vs_2nd_diff`

* **Description:** Opponent's difference between return points won percentage on first vs second serves
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.765, 0.439]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_return_1st_vs_2nd_diff
  * *Typical Values:* Median: -0.1954, Mean: -0.1960
  * *Notes:* Same consistently negative pattern as player version
* **Source/Calculation:** `opponent_return_1st_won_pct_avg - opponent_return_2nd_won_pct_avg`
* **Calculation Details:**

  * Same calculation methodology as player version
  * Important for understanding opponent's return strategy effectiveness

### `opponent_serve_1st_efficiency`

* **Description:** Opponent's ratio of first-serve points won percentage to service games won percentage
* **Data Type:** Float
* **Unit/Domain:** Efficiency ratio [0.8193, 2.9832]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when components missing
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_serve_1st_efficiency
  * *Typical Values:* Median: 0.9199, Mean: 0.9187
  * *Notes:* Same tight distribution pattern as player version
* **Source/Calculation:** `opponent_serve_1st_won_pct_avg / opponent_service_games_won_pct_avg`
* **Calculation Details:**

  * Same calculation methodology and smoothing as player version
  * Important for assessing opponent's serve efficiency

### `player_return_1st_efficiency`

* **Description:** Ratio of return points won on first serve to return games won percentage, measuring return effectiveness
* **Data Type:** Float
* **Unit/Domain:** Efficiency ratio [0.5000, 1.0000]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when components missing
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.5000, Max: 1.0000
  * *Typical Values:* Median: 1.0000, Mean: 0.9026
  * *Notes:* Bimodal distribution with clustering at 0.5 and 1.0; 75% of players at 1.0
* **Source/Calculation:** `player_return_1st_won_pct_avg / player_return_games_won_pct_avg`
* **Calculation Details:**

  * **Floor Value:** Minimum value capped at 0.5 due to smoothing
  * **Interpretation:** Values near 1.0 indicate efficient return game conversion
  * **Smoothing:** Bayesian smoothing applied using α=20 prior

### `player_return_1st_vs_2nd_diff`

* **Description:** Difference between return points won percentage on first vs second serves
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.765, 0.439]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs when return statistics unavailable
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.765, Max: 0.439, P99: -0.0729
  * *Typical Values:* Median: -0.1954, Mean: -0.1960
  * *Notes:* Consistently negative (expected - players win more vs second serves)
* **Source/Calculation:** `player_return_1st_won_pct_avg - player_return_2nd_won_pct_avg`
* **Calculation Details:**

  * **Expected Pattern:** Negative values are normal (second serves easier to return)
  * **Strategic Insight:** Less negative values indicate better first-serve returning
  * **Missingness:** Occurs when either component statistic is missing

### `player_serve_1st_efficiency`

* **Description:** Ratio of first-serve points won percentage to service games won percentage, measuring serve effectiveness efficiency
* **Data Type:** Float
* **Unit/Domain:** Efficiency ratio [0.8193, 2.9832]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when components missing
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.8193, Max: 2.9832, P99: 1.0118
  * *Typical Values:* Median: 0.9199, Mean: 0.9187
  * *Notes:* Tight distribution around 0.92; 95% of players between 0.878-0.968
* **Source/Calculation:** `player_serve_1st_won_pct_avg / player_service_games_won_pct_avg`
* **Calculation Details:**

  * **Interpretation:** Values >1 indicate first-serve points won % exceeds service games won %
  * **Protection:** Uses `pmax(denominator, 1e-9)` to avoid division by zero
  * **Smoothing:** Bayesian smoothing applied using α=20 prior

[⬆ Index](#index)

---

<a id="elo"></a>
## Elo & Probabilities

### `elo_diff`

* **Description:** Difference in general Elo ratings between player and opponent before the match (player − opponent).
* **Data Type:** Float
* **Unit/Domain:** Elo points [-1172.1, 1172.1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1172.1, Max: 1172.1, P99: 453.73
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:** Distribution centered at 0; 95% of matches have Elo differences within ±299.42 points
* **Source/Calculation:** Calculated as player_elo_pre − opponent_elo_pre
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE:** Player has higher general Elo than opponent (player advantage)
    * **NEGATIVE:** Opponent has higher general Elo than player (player disadvantage)
    * **ZERO:** Players have equal general Elo ratings
  * **Elo System:** Ratings initialized at 1500, updated with K=40 (provisional, <20 matches) or K=20 (established)

### `h2h_surface_vs_general_diff`

* **Description:** Difference between surface-specific and general head-to-head win ratios (smoothed).
* **Data Type:** Float
* **Unit/Domain:** Difference in win ratio [-0.3182, 0.3182]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.3182, Max: 0.3182, P99: 0.1000
  * *Typical Values:* Median: 0, Mean: 0 (symmetric)
  * *Notes:** Distribution heavily concentrated at 0; 95% of values within ±0.0556
* **Source/Calculation:** Calculated as player_h2h_surface_win_ratio − player_h2h_full_win_ratio
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE:** Player has better H2H record against this opponent on current surface vs all surfaces
    * **NEGATIVE:** Player has worse H2H record against this opponent on current surface vs all surfaces
    * **ZERO:** No surface-specific H2H advantage/disadvantage
  * **Smoothing:** Applied to handle small sample sizes in H2H data
  * **Strategic Insight:** Measures whether surface amplifies or diminishes player's historical advantage over opponent

### `opponent_elo_surface_pre`

* **Description:** Opponent's surface-specific Elo rating before the match.
* **Data Type:** Float
* **Unit/Domain:** Elo points [1134, 2466]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_elo_surface_pre
  * *Typical Values:* Median: 1613, Mean: 1636
  * *Notes:** Same distribution pattern as player's surface Elo
* **Source/Calculation:** Surface-specific Elo system trained on 1968-1998 data and updated through 1999-2025
* **Calculation Details:**

  * Same methodology as player_elo_surface_pre but for opponent
  * Maintains identical update rules and initialization logic

### `opponent_win_prob_diff_general_vs_surface_cat`

* **Description:** Categorical difference between general and surface win probabilities for opponent.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {negative, neutral, positive}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_prob_diff_general_vs_surface_cat
  * *Typical Values:* negative (6.31%), neutral (87.38%), positive (6.31%)
  * *Notes:** Same symmetric distribution pattern as player's probability difference categories
* **Source/Calculation:** Categorized from opponent_win_prob − opponent_win_prob_surface
* **Calculation Details:**

  * **Categorization Rules:**

    * Same threshold logic as player version: ±0.2 boundaries
  * **Interpretation:**

    * "negative": Surface-specific rating gives opponent LOWER win probability than general rating
    * "positive": Surface-specific rating gives opponent HIGHER win probability than general rating

### `player_elo_surface_pre`

* **Description:** Player's surface-specific Elo rating before the match.
* **Data Type:** Float
* **Unit/Domain:** Elo points [1134, 2466]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1134, Max: 2466, P99: 2069.48
  * *Typical Values:* Median: 1613, Mean: 1636
  * *Notes:** Distribution shows typical Elo range; 75% of players have surface Elo ≤1718.61
* **Source/Calculation:** Surface-specific Elo system trained on 1968-1998 data and updated through 1999-2025
* **Calculation Details:**

  * **Initialization:** 1500 for new players, pre-1999 historical Elo for players with career before 1999
  * **Updates:** Round-safe updates without intra-round leakage
  * **Surface Normalization:** Uses 4 canonical surfaces: {Clay, Grass, Carpet, Hard}

### `player_win_prob_diff_general_vs_surface_cat`

* **Description:** Categorical difference between general and surface win probabilities for player.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {negative, neutral, positive}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* negative (6.31%), neutral (87.38%), positive (6.31%)
  * *Typical Values:* Vast majority of players fall in neutral category
  * *Notes:** Symmetric distribution with equal proportions in negative/positive categories
* **Source/Calculation:** Categorized from player_win_prob − player_win_prob_surface
* **Calculation Details:**

  * **Categorization Rules:**

    * "negative" if `(player_win_prob − player_win_prob_surface) ≤ -0.2`
    * "neutral" if `-0.2 < (player_win_prob − player_win_prob_surface) < 0.2`
    * "positive" if `(player_win_prob − player_win_prob_surface) ≥ 0.2`
  * **Interpretation:**

    * "negative": Surface-specific rating gives player LOWER win probability than general rating
    * "neutral": Surface-specific and general ratings give similar win probabilities
    * "positive": Surface-specific rating gives player HIGHER win probability than general rating

### `player_win_prob_surface`

* **Description:** Elo-implied probability of player winning on current surface before the match.
* **Data Type:** Float
* **Unit/Domain:** Probability [0.0076, 0.9924]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0076, Max: 0.9924, P99: 0.8659
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (perfectly calibrated)
  * *Notes:** Distribution centered at 0.5; 95% of matches have win probabilities between 0.23-0.77
* **Source/Calculation:** Derived from surface Elo ratings using logistic function
* **Calculation Details:**

  * **Formula:** `1 / (1 + 10^(-(player_elo_surface_pre - opponent_elo_surface_pre)/400))`
  * **Interpretation:** Probability based solely on surface-specific Elo difference
  * **Calibration:** Perfectly symmetric around 0.5 indicates well-calibrated system

[⬆ Index](#index)

---

<a id="h2h"></a>
## Head-to-Head (H2H) Metrics

### `has_player_h2h_surface`

* **Description:** Binary indicator for availability of surface-specific head-to-head history
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = surface H2H available (>0 matches)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2289 (22.89% have surface H2H)
  * *Notes:** Rare feature - most player-opponent pairs lack surface-specific history
* **Source/Calculation:** Derived from player_h2h_surface_total_matches
* **Calculation Details:**

  * **Formula:** `ifelse(player_h2h_surface_total_matches > 0, 1, 0)`
  * **Usage:** Flags when surface-specific H2H information exists

### `has_player_h2h_full`

* **Description:** Binary indicator for availability of any head-to-head history
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = any H2H available (>0 matches)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.3230 (32.30% have any H2H history)
  * *Notes:** More common than surface H2H but still missing for 67.7% of pairs
* **Source/Calculation:** Derived from player_h2h_total_matches
* **Calculation Details:**

  * **Formula:** `ifelse(player_h2h_total_matches > 0, 1, 0)`
  * **Usage:** Flags when any H2H information exists for the pair

### `player_h2h_full_cred`

* **Description:** Credibility weight [0,1] for full H2H win ratio based on sample size vs prior strength
* **Data Type:** Float
* **Unit/Domain:** Credibility [0.0000, 0.8788]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0000, Max: 0.8788, P99: 0.4667
  * *Typical Values:* Median: 0.0000, Mean: 0.0619
  * *Notes:** Extremely right-skewed; 75% of values are 0 (no H2H history)
* **Source/Calculation:** Bayesian credibility formula based on H2H sample size
* **Calculation Details:**

  * **Formula:** `n / (n + α)` where α=8 (prior strength)
  * **Interpretation:** 0 = no H2H history, 1 = extensive H2H history

### `player_h2h_full_win_ratio`

* **Description:** Smoothed head-to-head win ratio against current opponent across all surfaces up to current match (Beta-Binomial smoothing with prior)
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.1481, 0.8519]
* **Missingness Policy:** Never missing (0% NAs) - uses Bayesian prior when no H2H history
* **Temporal Semantics:** Strictly pre-match cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.1481, Max: 0.8519, P99: 0.6364
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (perfectly symmetric due to smoothing)
  * *Notes:* Distribution artificially centered at 0.5 by Bayesian prior; 95% of values between 0.4444-0.5556
* **Source/Calculation:** Beta-Binomial smoothing with α=8, β=8 prior (p₀=0.5)
* **Calculation Details:**

  * **Formula:** `(raw_wins + α × p₀) / (total_matches + α)`
  * **Smoothing Effect:** Shrinks extreme ratios toward 0.5 for small sample sizes
  * **Temporal Integrity:** Chronological ordering via event_key prevents leakage

### `player_h2h_surface_cred`

* **Description:** Credibility weight [0,1] for surface H2H win ratio based on sample size vs prior strength
* **Data Type:** Float
* **Unit/Domain:** Credibility [0.0000, 0.8605]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0000, Max: 0.8605, P99: 0.4545
  * *Typical Values:* Median: 0.0000, Mean: 0.0480
  * *Notes:** Even more skewed than full H2H credibility; 75% of values are 0
* **Source/Calculation:** Bayesian credibility formula based on surface H2H sample size
* **Calculation Details:**

  * **Formula:** `n / (n + α)` where α=6 (stronger prior due to sparsity)
  * **Strategic Value:** Critical for determining when surface H2H is statistically meaningful

### `player_h2h_surface_total_matches`

* **Description:** Total number of head-to-head matches played against opponent on current surface before current match
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 37]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Strictly pre-match cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 37, P99: 5
  * *Typical Values:* Median: 0, Mean: 0.4091
  * *Notes:** Extreme sparsity: 75% of pairs have 0 surface-specific H2H matches
* **Source/Calculation:** Cumulative count from surface-filtered H2H matches
* **Calculation Details:**

  * **Distribution:** 0 matches (75%), 1 match (15%), 2+ matches (10%)
  * **Surface Specialization:** Critical for surface-dependent rivalries

### `player_h2h_surface_win_ratio`

* **Description:** Smoothed head-to-head win ratio against current opponent on current surface
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.1250, 0.8750]
* **Missingness Policy:** Never missing (0% NAs) - uses Bayesian prior when no surface H2H
* **Temporal Semantics:** Strictly pre-match cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.1250, Max: 0.8750, P99: 0.6250
  * *Typical Values:* Median: 0.5000, Mean: 0.5000 (symmetric smoothing)
  * *Notes:** Tighter distribution than full H2H; 95% of values between 0.4286-0.5714
* **Source/Calculation:** Beta-Binomial smoothing with α=6, β=6 prior (p₀=0.5)
* **Calculation Details:**

  * **Stronger Prior:** Uses α=6 (vs α=8 for full H2H) due to higher sparsity
  * **Surface Filtering:** Only matches on current surface (Clay/Grass/Hard/Carpet)

### `player_h2h_total_matches`

* **Description:** Total number of head-to-head matches played against opponent before current match
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 58]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Strictly pre-match cumulative (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 58, P99: 7
  * *Typical Values:* Median: 0, Mean: 0.7062
  * *Notes:* Highly right-skewed; 50% of player-opponent pairs have 0 prior matches
* **Source/Calculation:** Cumulative count from deduplicated H2H matches (1968-2025)
* **Calculation Details:**

  * **Distribution:** 0 matches (50%), 1 match (25%), 2+ matches (25%)
  * **Rare Rivalries:** Only 1% of pairs have 7+ H2H matches

[⬆ Index](#index)

---

<a id="home"></a>
## Home Flags

### `opponent_home`

*   **Description:** Binary flag indicating if the opponent is competing in their home country.
*   **Data Type:** Binary (0/1)
*   **Unit/Domain:** {0, 1} where 1 = opponent_citizenship == tournament_country
*   **Missingness Policy:** Never missing (0% NAs)
*   **Temporal Semantics:** Snapshot at match
*   **Range/Values & Outlier Notes:**
    *   *Observed Range:* Identical distribution to player_home
    *   *Typical Values:* 0 (75.86%), 1 (24.14%)
    *   *Notes:* Same home advantage distribution as for players
*   **Source/Calculation:** Derived from opponent_citizenship == tournament_country comparison

### `player_home`

*   **Description:** Binary flag indicating if the player is competing in their home country.
*   **Data Type:** Binary (0/1)
*   **Unit/Domain:** {0, 1} where 1 = player_citizenship == tournament_country
*   **Missingness Policy:** Never missing (0% NAs)
*   **Temporal Semantics:** Snapshot at match
*   **Range/Values & Outlier Notes:**
    *   *Observed Range:* 0 (75.86%), 1 (24.14%)
    *   *Typical Values:* Majority of players compete abroad (75.86%)
    *   *Notes:* Approximately 1 in 4 players compete in their home country
*   **Source/Calculation:** Derived from player_citizenship == tournament_country comparison

[⬆ Index](#index)

---

<a id="identifiers"></a>
## Identifiers & Match/Tournament Metadata

### `best_of`

* **Description:** Number of sets the match is configured to play (best-of format).
* **Data Type:** Integer
* **Unit/Domain:** {3, 5}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 3, Max: 5
  * *Typical Values:* Median: 3, Mean: 3.175
  * *Notes:* 95% of matches are best-of-3; only 5% are best-of-5 (Grand Slams)
* **Source/Calculation:** Inferred from match scores with fallback to 3; GS matches set to 5

### `id`

* **Description:** Unique match identifier shared by the two player rows.
* **Data Type:** String
* **Unit/Domain:** Format: "YYYY-T-player1-player2-round" (288,512 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 288,512 unique match identifiers
  * *Typical Values:* All values appear exactly twice (confirming 2 rows per match)
  * *Notes:* Primary key component; ensures exactly 2 rows per match
* **Source/Calculation:** Generated match identifier

### `indoor_outdoor`

* **Description:** Venue type indicating whether match was played indoors or outdoors.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Indoor, Outdoor, (blank)}
* **Missingness Policy:** Never missing, but has blank category (8.82%)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Outdoor (74.41%), Indoor (16.78%), Blank (8.82%)
  * *Typical Values:* Majority of matches are played outdoors
  * *Notes:* 8.82% of records have blank values for this field
* **Source/Calculation:** Direct scraping from ATP match data

### `match_order`

* **Description:** Order of the match within the current round (resets per stadie_id).
* **Data Type:** Integer
* **Unit/Domain:** [1, 300]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 300, P99: 204
  * *Typical Values:* Median: 5, Mean: 10.54
  * *Notes:* Highly right-skewed; 75% of matches have order ≤10, but extremes go to 300
* **Source/Calculation:** Calculated from match scheduling data

### `stadie_id`

* **Description:** Round code representing the stage of the tournament.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {Q1, Q2, Q3, BR, RR, R128, R64, R32, R16, QF, SF, F, 3P}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* R32 (31.46%), R16 (16.11%), Q1 (16.69%), Q2 (9.68%), QF (8.06%)
  * *Typical Values:* Early rounds (R32, R16, Q1) comprise majority of matches
  * *Notes:* 3P (3rd place) and BR are extremely rare (<0.01%)
* **Source/Calculation:** Direct scraping from ATP match data

### `stadie_ord`

* **Description:** Ordinal index of stadie_id (ordered numerical representation of round).
* **Data Type:** Integer
* **Unit/Domain:** [1, 13]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 13
  * *Typical Values:* Median: 8, Mean: 6.491
  * *Notes:* Bimodal distribution with concentrations at lower (qualifying) and middle (main draw) values
* **Source/Calculation:** Derived from stadie_id mapping to ordinal scale

### `surface`

* **Description:** Court surface on which the match was played.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Clay, Grass, Hard, Carpet}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Hard (48.91%), Clay (42.64%), Grass (5.57%), Carpet (2.89%)
  * *Typical Values:* Hard courts are most common, followed by Clay
  * *Notes:* Carpet surfaces are relatively rare (2.89% of matches)
* **Source/Calculation:** Direct scraping from ATP tournament data

### `tournament_category`

* **Description:** Classification of tournament type and prestige level.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {1000, atp250, atp500, atpCup, atpFinal, ch100, ch50, chFinal, gs, gsCup, laverCup, nextGen, og, teamCup}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* ch50 (41.66%), ch100 (21.95%), atp250 (15.81%), gs (8.69%), 1000 (6.65%)
  * *Typical Values:* Challenger events (ch50, ch100) dominate the dataset
  * *Notes:* Rare categories: gsCup (0.00%), laverCup (0.02%), nextGen (0.04%)
* **Source/Calculation:** Categorized from ATP tournament metadata

### `tournament_country`

* **Description:** Host country of the tournament (ISO-3 code).
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** ISO-3 codes (84 unique countries)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at tournament level
* **Range/Values & Outlier Notes:**

  * *Observed Range:* USA (27.07%), ITA (14.94%), FRA (13.54%), GER (9.53%), GBR (8.05%)
  * *Typical Values:* United States hosts the most tournaments (27.07%)
  * *Notes:* Top 10 countries account for 89.53% of all tournaments
* **Source/Calculation:** Direct scraping from ATP tournament data

### `tournament_id`

* **Description:** Unique tournament identifier combining year and tournament code.
* **Data Type:** String
* **Unit/Domain:** Format: "YYYY-NNN" (5,881 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 5,881 unique tournament instances
  * *Typical Values:* Most frequent: 2024-520 (11.78%), 2025-540 (9.86%), 2025-580 (9.86%)
  * *Notes:* Format suggests year-tournament_code combination
* **Source/Calculation:** Generated from ATP tournament identifiers

### `tournament_name`

* **Description:** Official name of the tournament.
* **Data Type:** String
* **Unit/Domain:** Tournament names (1,347 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at tournament level
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 1,347 unique tournament names
  * *Typical Values:* Grand Slams dominate: Roland Garros (16.93%), Australian Open (16.80%), US Open (16.50%), Wimbledon (16.17%)
  * *Notes:* Four Grand Slams account for 66.4% of all tournament name occurrences
* **Source/Calculation:** Direct scraping from ATP tournament data

### `tournament_prize`

* **Description:** Total prize money for the tournament (usually EUR/GBP, not inflation-adjusted).
* **Data Type:** Float
* **Unit/Domain:** [0, 43,250,000] (currency units)
* **Missingness Policy:** Rarely missing (0.09% NAs)
* **Temporal Semantics:** Snapshot at tournament level
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 43,250,000, P99: 26,334,000
  * *Typical Values:* Median: 91,250, Mean: 1,769,387
  * *Notes:* Highly right-skewed; 75% of tournaments have prize ≤630,705, but maximum is 43M
* **Source/Calculation:** Scraped from ATP tournament information

### `tournament_start_dtm`

* **Description:** Tournament start date (YYYY-MM-DD).
* **Data Type:** Date
* **Unit/Domain:** [1999-01-04, 2025-09-22]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at tournament level
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 1999-01-04 to 2025-09-22
  * *Typical Values:* 1,610 unique tournament dates
  * *Notes:* Covers 26+ years of tournament history
* **Source/Calculation:** Direct scraping from ATP tournament schedule

### `year`

* **Description:** Calendar year of the tournament.
* **Data Type:** Integer
* **Unit/Domain:** [1999, 2025]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1999, Max: 2025
  * *Typical Values:* Median: 2013, Mean: 2013
  * *Notes:* Data covers 1999-2025 period; distribution is relatively even across years
* **Source/Calculation:** Extracted from tournament start date

[⬆ Index](#index)

---

<a id="identity"></a>
## Identity & Basic Player Info

### `opponent_age`

* **Description:** Opponent's age at the time of the match (in years).
* **Data Type:** Float
* **Unit/Domain:** Years (with decimal precision)
* **Missingness Policy:** Rarely missing (0.26% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_age
  * *Typical Values:* Median: 25.17, Mean: 25.47
  * *Notes:** Same data quality issues as player_age with extreme outliers
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_backhand`

* **Description:** Type of backhand technique used by the opponent.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Two-Handed Backhand, One-Handed Backhand, Unknown Backhand}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_backhand
  * *Typical Values:* Unknown Backhand (59.81%), Two-Handed Backhand (14.98%)
  * *Notes:* Same data completeness issues as player_backhand
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_citizenship`

* **Description:** Opponent's country of citizenship (ISO-3 code).
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** ISO-3 codes (144 unique countries)
* **Missingness Policy:** Rarely missing (0.27% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_citizenship
  * *Typical Values:* USA (15.77%), FRA (14.46%), ESP (12.45%)
  * *Notes:* Same missingness pattern and distribution as player_citizenship
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_code`

* **Description:** Unique identifier for the opponent player.
* **Data Type:** String
* **Unit/Domain:** Alphanumeric codes (11,945 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Persistent player identifier
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 11,945 unique opponent codes
  * *Typical Values:* Identical distribution to player_code (same top players)
  * *Notes:* Matches player_code distribution, confirming symmetric representation
* **Source/Calculation:** Generated player identifier from ATP data

### `opponent_gs_titles`

* **Description:** Opponent's Grand Slam titles won (singles only) up to this match.
* **Data Type:** Integer
* **Unit/Domain:** Title count [0, 24]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_gs_titles
  * *Typical Values:* Median: 0, Mean: 0.1
  * *Notes:* Same extreme skew as player_gs_titles
* **Source/Calculation:** Cumulative count from opponent's Grand Slam tournament history

### `opponent_handedness`

* **Description:** Opponent's dominant hand for playing tennis.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Right-Handed, Left-Handed, Ambidextrous, Unknown, (blank)}
* **Missingness Policy:** No NAs, but has blank category (4.31%)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_handedness
  * *Typical Values:* Right-Handed (82.78%), Left-Handed (12.89%)
  * *Notes:* Same distribution pattern as player_handedness
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_height`

* **Description:** Opponent's height in centimeters.
* **Data Type:** Integer
* **Unit/Domain:** Centimeters [0, 244]
* **Missingness Policy:** Frequently missing (10.64% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_height
  * *Typical Values:* Median: 185, Mean: 183.5
  * *Notes:** Same data quality issues as player_height
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_matches_won`

* **Description:** Opponent's cumulative career wins up to this match (progressive count).
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1241]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_matches_won
  * *Typical Values:* Median: 89, Mean: 131.9
  * *Notes:* Same skew pattern as player_matches_won
* **Source/Calculation:** Progressive count from opponent's career match history

### `opponent_name`

* **Description:** Display name of the opponent player.
* **Data Type:** String
* **Unit/Domain:** Player names (11,911 unique values)
* **Missingness Policy:** Extremely rare missing (1 record, 0%)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 11,911 unique opponent names
  * *Typical Values:* Identical to player_name top frequencies
  * *Notes:* Perfect correspondence with opponent_code distribution
* **Source/Calculation:** Direct scraping from ATP player data

### `opponent_seed`

* **Description:** Tournament seeding status of the opponent (0/NA = unseeded).
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {0, WC, Q, 1, 2, 3, ...} (182 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_seed
  * *Typical Values:* 0 (51.24%), WC (10.22%), Q (8.89%)
  * *Notes:* Same coding scheme as player_seed: 'WC' = Wild Card, 'Q' = Qualifier
* **Source/Calculation:** Tournament seeding information from ATP

### `opponent_weight`

* **Description:** Opponent's weight in kilograms.
* **Data Type:** Integer
* **Unit/Domain:** Kilograms [0, 200.2]
* **Missingness Policy:** Frequently missing (10.67% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_weight
  * *Typical Values:* Median: 79, Mean: 83.59
  * *Notes:** Same extreme outliers as player_weight
* **Source/Calculation:** Direct scraping from ATP player profiles

### `opponent_win_rate`

* **Description:** Opponent's career win rate up to this match (progressive percentage).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.94% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_rate
  * *Typical Values:* Median: 0.524, Mean: 0.506
  * *Notes:* Same distribution pattern as player_win_rate
* **Source/Calculation:** Calculated as opponent's career wins / total matches up to t-1

### `opponent_years_experience`

* **Description:** Opponent's years of professional experience calculated as current year minus turned_pro year.
* **Data Type:** Integer
* **Unit/Domain:** Years [0, 35]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_years_experience
  * *Typical Values:* Median: 6, Mean: 12.79
  * *Notes:** Extreme outliers present (negative values); realistic range is 0-19 years (1%-99% percentiles)
* **Source/Calculation:** Calculated as year − turned_pro for opponent

### `player_age`

* **Description:** Player's age at the time of the match (in years).
* **Data Type:** Float
* **Unit/Domain:** Years (with decimal precision)
* **Missingness Policy:** Rarely missing (0.26% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.387, Max: 2023.172, P99: 35.981
  * *Typical Values:* Median: 25.17, Mean: 25.47
  * *Notes:** Extreme values (negative, >100) are data errors; realistic range is 17-36 years (1%-99% percentiles)
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_backhand`

* **Description:** Type of backhand technique used by the player.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Two-Handed Backhand, One-Handed Backhand, Unknown Backhand}
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Unknown Backhand (59.81%), Two-Handed Backhand (14.98%), One-Handed Backhand (6.71%)
  * *Typical Values:* Two-handed backhand is more common than one-handed
  * *Notes:* High percentage (59.81%) in "Unknown Backhand" category suggests data completeness issues
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_citizenship`

* **Description:** Player's country of citizenship (ISO-3 code).
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** ISO-3 codes (144 unique countries)
* **Missingness Policy:** Rarely missing (0.27% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* USA (15.77%), FRA (14.46%), ESP (12.45%), ITA (11.90%)
  * *Typical Values:* Traditional tennis nations dominate the distribution
  * *Notes:* Top 10 countries account for 88.01% of player citizenships
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_code`

* **Description:** Unique identifier for the focal player in the row.
* **Data Type:** String
* **Unit/Domain:** Alphanumeric codes (11,945 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Persistent player identifier
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 11,945 unique player codes
  * *Typical Values:* Most frequent: f324 (12.37%), d643 (11.44%), n409 (10.93%)
  * *Notes:* Top 10 players account for ~90% of appearances, reflecting long careers of top players
* **Source/Calculation:** Generated player identifier from ATP data

### `player_gs_titles`

* **Description:** Grand Slam titles won (singles only) up to this match.
* **Data Type:** Integer
* **Unit/Domain:** Title count [0, 24]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 24, P99: 2
  * *Typical Values:* Median: 0, Mean: 0.1
  * *Notes:* Extremely right-skewed; 75% of players have 0 GS titles; maximum of 24 reflects exceptional career
* **Source/Calculation:** Cumulative count from Grand Slam tournament history

### `player_handedness`

* **Description:** Player's dominant hand for playing tennis.
* **Data Type:** Categorical (Nominal)
* **Unit/Domain:** {Right-Handed, Left-Handed, Ambidextrous, Unknown, (blank)}
* **Missingness Policy:** No NAs, but has blank category (4.31%)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Right-Handed (82.78%), Left-Handed (12.89%), Blank (4.31%), Ambidextrous (0.03%)
  * *Typical Values:* Vast majority of players are right-handed
  * *Notes:* Left-handed players represent about 1 in 8 players; ambidextrous is extremely rare
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_height`

* **Description:** Player's height in centimeters.
* **Data Type:** Integer
* **Unit/Domain:** Centimeters [0, 244]
* **Missingness Policy:** Frequently missing (10.64% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 244, P99: 203
  * *Typical Values:* Median: 185, Mean: 183.5
  * *Notes:** Values of 0 are data errors; realistic range is 168-203cm (1%-99% percentiles); 244cm is physically implausible
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_matches_won`

* **Description:** Cumulative career wins up to this match (progressive count).
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1241]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1241, P99: 563
  * *Typical Values:* Median: 89, Mean: 131.9
  * *Notes:* Highly right-skewed distribution; 25% of players have ≤26 wins, while top players have 400+ wins
* **Source/Calculation:** Progressive count from career match history

### `player_name`

* **Description:** Display name of the focal player.
* **Data Type:** String
* **Unit/Domain:** Player names (11,911 unique values)
* **Missingness Policy:** Extremely rare missing (1 record, 0%)
* **Temporal Semantics:** Persistent player attribute
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 11,911 unique player names
  * *Typical Values:* Roger Federer (12.37%), Novak Djokovic (11.44%), Rafael Nadal (10.93%)
  * *Notes:* Distribution matches player_code, confirming code-name correspondence
* **Source/Calculation:** Direct scraping from ATP player data

### `player_seed`

* **Description:** Tournament seeding status of the player (0/NA = unseeded).
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {0, WC, Q, 1, 2, 3, ...} (182 unique values)
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 0 (51.24%), WC (10.22%), Q (8.89%), seeded positions 1-32
  * *Typical Values:* Majority of players are unseeded (51.24%)
  * *Notes:* 'WC' = Wild Card, 'Q' = Qualifier, '0' = Unseeded main draw
* **Source/Calculation:** Tournament seeding information from ATP

### `player_weight`

* **Description:** Player's weight in kilograms.
* **Data Type:** Integer
* **Unit/Domain:** Kilograms [0, 200.2]
* **Missingness Policy:** Frequently missing (10.67% NAs)
* **Temporal Semantics:** Snapshot at match (assumed constant)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 200.2, P99: 100
  * *Typical Values:* Median: 79, Mean: 83.59
  * *Notes:** Extreme outliers present (200.2kg is impossible); realistic range is 64-100kg (1%-99% percentiles)
* **Source/Calculation:** Direct scraping from ATP player profiles

### `player_win_rate`

* **Description:** Career win rate up to this match (progressive percentage).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.94% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1, P99: 0.801
  * *Typical Values:* Median: 0.524, Mean: 0.506
  * *Notes:* Distribution centers around 0.5; 95% of players have win rate ≤0.645
* **Source/Calculation:** Calculated as career wins / total matches up to t-1

### `player_years_experience`

* **Description:** Years of professional experience calculated as current year minus turned_pro year.
* **Data Type:** Integer
* **Unit/Domain:** Years [0, 35]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 35, P99: 19
  * *Typical Values:* Median: 6, Mean: 12.79
  * *Notes:** Extreme outliers present (negative values); realistic range is 0-19 years (1%-99% percentiles)
* **Source/Calculation:** Calculated as year − turned_pro (first Challenger/ATP appearance)

[⬆ Index](#index)

---

<a id="logratios"></a>
## Log-Ratios (Player vs Opponent)

### `log_ratio_aces_per_match`

* **Description:** Log-ratio of aces per match between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-6.8897, 6.8897]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -6.8897, Max: 6.8897, P99: 1.2242
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Widest distribution among log-ratios due to ace count variability
* **Source/Calculation:** `log(player_aces_per_match_avg + ε) - log(opponent_aces_per_match_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player serving power advantage

### `log_ratio_break_points_converted_pct`

* **Description:** Log-ratio of break points converted percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-1.8582, 1.8582]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1.8582, Max: 1.8582, P99: 0.2213
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tight distribution; 95% of values within ±0.1224
* **Source/Calculation:** `log(player_break_points_converted_pct_avg + ε) - log(opponent_break_points_converted_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in converting break opportunities

### `log_ratio_break_points_saved_pct`

* **Description:** Log-ratio of break points saved percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.7362, 0.7362]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.7362, Max: 0.7362, P99: 0.1625
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tight distribution; 95% of values within ±0.0995
* **Source/Calculation:** `log(player_break_points_saved_pct_avg + ε) - log(opponent_break_points_saved_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * **Base Formula:** Natural logarithm of ratio between player and opponent break point save percentages
  * **Epsilon Protection:** ε = 1e-6 to handle zero values
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in clutch serving under pressure

### `log_ratio_double_faults_pct`

* **Description:** Log-ratio of double faults percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-2.3308, 2.3308]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -2.3308, Max: 2.3308, P99: 0.6760
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Wider distribution reflects higher variability in double fault rates
* **Source/Calculation:** `log(player_double_faults_pct_avg + ε) - log(opponent_double_faults_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * **Important Note:** Negative values indicate player advantage (fewer double faults)
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Negative values = player more reliable on serve

### `log_ratio_return_2nd_won_pct`

* **Description:** Log-ratio of return points won against second serve percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-13.367, 13.367]
* **Missingness Policy:** Some missing (11.02% NAs) - occurs when return statistics unavailable
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -13.367, Max: 13.367, P99: 0.3417
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:** Extreme range but 95% of values within ±0.1643; highest NA% among log-ratios
* **Source/Calculation:** `log(player_return_2nd_won_pct_avg + ε) - log(opponent_return_2nd_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Applied only to non-NA values with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in returning second serves

### `log_ratio_return_games_won_pct`

* **Description:** Log-ratio of return games won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-2.4198, 2.4198]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -2.4198, Max: 2.4198, P99: 0.4971
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:** Moderate distribution width; 95% of values within ±0.2858
* **Source/Calculation:** `log(player_return_games_won_pct_avg + ε) - log(opponent_return_games_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in breaking opponent's serve

### `log_ratio_serve_1st_in_pct`

* **Description:** Log-ratio of first serve in percentage between player and opponent (player vs opponent)
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.4610, 0.4610]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.4610, Max: 0.4610, P99: 0.1608
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (perfectly symmetric)
  * *Notes:* Symmetric distribution around 0; 95% of values between -0.1031 and 0.1031
* **Source/Calculation:** `log(player_serve_1st_in_pct_avg + ε) - log(opponent_serve_1st_in_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * **Base Formula:** Natural logarithm of ratio between player and opponent metrics
  * **Epsilon Protection:** ε = 1e-6 to avoid log(0) and handle zero values
  * **Smoothing Type:** Log-ratio smoothing with α=30 (strong shrinkage toward 0)
  * **Interpretation:** Positive values indicate player advantage in first serve accuracy

### `log_ratio_serve_2nd_won_pct`

* **Description:** Log-ratio of second serve points won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-1.5473, 1.5473]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1.5473, Max: 1.5473, P99: 0.1345
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tighter distribution than range suggests; 95% within ±0.0782
* **Source/Calculation:** `log(player_serve_2nd_won_pct_avg + ε) - log(opponent_serve_2nd_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in second serve effectiveness

### `log_ratio_service_games_won_pct`

* **Description:** Log-ratio of service games won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.9022, 0.9022]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.9022, Max: 0.9022, P99: 0.1565
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tight distribution; 95% of values within ±0.1002
* **Source/Calculation:** `log(player_service_games_won_pct_avg + ε) - log(opponent_service_games_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player serve dominance advantage

### `log_ratio_tiebreaks_won_pct`

* **Description:** Log-ratio of tie-breaks won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-8.3202, 8.3202]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -8.3202, Max: 8.3202, P99: 0.4319
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Wide range but 95% of values within ±0.2458; reflects tie-break volatility
* **Source/Calculation:** `log(player_tiebreaks_won_pct_avg + ε) - log(opponent_tiebreaks_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate player advantage in tie-break situations

### `log_ratio_total_points_won_pct`

* **Description:** Log-ratio of total points won percentage between player and opponent
* **Data Type:** Float
* **Unit/Domain:** Log-ratio [-0.3177, 0.3177]
* **Missingness Policy:** Never missing (0% NAs) - Bayesian smoothing applied with α=30 prior
* **Temporal Semantics:** Derived from progressive averages (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.3177, Max: 0.3177, P99: 0.0661
  * *Typical Values:* Median: 0.0000, Mean: 0.0000 (symmetric)
  * *Notes:* Tightest distribution among all log-ratios; 95% within ±0.0388
* **Source/Calculation:** `log(player_total_points_won_pct_avg + ε) - log(opponent_total_points_won_pct_avg + ε)`
* **Calculation & Smoothing Details:**

  * Same log-ratio formula with epsilon protection
  * **Smoothing:** Strong shrinkage toward 0 with α=30 prior
  * **Interpretation:** Positive values indicate overall player dominance in match points

[⬆ Index](#index)

---

<a id="missingness"></a>
## Missingness Indicators

### `log_ratio_aces_per_match_was_na`

* **Description:** Binary indicator if log_ratio_aces_per_match was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2249 (22.49% were NA)
  * *Notes:* Nearly identical to other count-based metric missingness

### `log_ratio_break_points_converted_pct_was_na`

* **Description:** Binary indicator if log_ratio_break_points_converted_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2316 (23.16% were NA)
  * *Notes:* Similar missingness rate to other break point metrics

### `log_ratio_break_points_saved_pct_was_na`

* **Description:** Binary indicator if log_ratio_break_points_saved_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2276 (22.76% were NA)
  * *Notes:* Slightly lower missingness than converted break points

### `log_ratio_double_faults_pct_was_na`

* **Description:** Binary indicator if log_ratio_double_faults_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2250 (22.50% were NA)
  * *Notes:* Consistent with other serve metric missingness patterns

### `log_ratio_return_games_won_pct_was_na`

* **Description:** Binary indicator if log_ratio_return_games_won_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2250 (22.50% were NA)
  * *Notes:* Symmetric missingness with service games metric

### `log_ratio_serve_1st_in_pct_was_na`

* **Description:** Binary indicator if log_ratio_serve_1st_in_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1102 (11.02% were NA)
  * *Notes:* Lower missingness than most log-ratio metrics

### `log_ratio_serve_2nd_won_pct_was_na`

* **Description:** Binary indicator if log_ratio_serve_2nd_won_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1102 (11.02% were NA)
  * *Notes:* Same missingness rate as first serve log-ratio

### `log_ratio_service_games_won_pct_was_na`

* **Description:** Binary indicator if log_ratio_service_games_won_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2250 (22.50% were NA)
  * *Notes:* Same missingness rate as return games won percentage

### `log_ratio_tiebreaks_won_pct_was_na`

* **Description:** Binary indicator if log_ratio_tiebreaks_won_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2328 (23.28% were NA)
  * *Notes:* About 23% of tie-break log-ratios required imputation

### `log_ratio_total_points_won_pct_was_na`

* **Description:** Binary indicator if log_ratio_total_points_won_pct was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2250 (22.50% were NA)
  * *Notes:* Consistent missingness across points-based metrics

### `opponent_aces_per_match_avg_was_na`

* **Description:** Binary indicator if opponent_aces_per_match_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_break_points_converted_pct_avg_was_na`

* **Description:** Binary indicator if opponent_break_points_converted_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1527 (15.27% were NA)
  * *Notes:* Identical missingness rate to player version

### `opponent_break_points_saved_pct_avg_was_na`

* **Description:** Binary indicator if opponent_break_points_saved_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1495 (14.95% were NA)
  * *Notes:* Same missingness rate as player version

### `opponent_clutch_bp_conv_gap_was_na`

* **Description:** Binary indicator if opponent_clutch_bp_conv_gap was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1527 (15.27% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_clutch_bp_save_gap_was_na`

* **Description:** Binary indicator if opponent_clutch_bp_save_gap was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1495 (14.95% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_clutch_tiebreak_adj_was_na`

* **Description:** Binary indicator if opponent_clutch_tiebreak_adj was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2001 (20.01% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_double_faults_pct_avg_was_na`

* **Description:** Binary indicator if opponent_double_faults_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Same missingness rate as player version

### `opponent_return_1st_efficiency_was_na`

* **Description:** Binary indicator if opponent_return_1st_efficiency was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_return_games_won_pct_avg_was_na`

* **Description:** Binary indicator if opponent_return_games_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_serve_1st_efficiency_was_na`

* **Description:** Binary indicator if opponent_serve_1st_efficiency was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_service_games_won_pct_avg_was_na`

* **Description:** Binary indicator if opponent_service_games_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `opponent_total_points_won_pct_avg_was_na`

* **Description:** Binary indicator if opponent_total_points_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Symmetric missingness with player version

### `player_aces_per_match_avg_was_na`

* **Description:** Binary indicator if player_aces_per_match_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Same missingness as double faults metric

### `player_break_points_converted_pct_avg_was_na`

* **Description:** Binary indicator if player_break_points_converted_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1527 (15.27% were NA)
  * *Notes:* Lower missingness than derived log-ratio metrics

### `player_break_points_saved_pct_avg_was_na`

* **Description:** Binary indicator if player_break_points_saved_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1495 (14.95% were NA)
  * *Notes:* Slightly lower missingness than break points converted

### `player_clutch_bp_conv_gap_was_na`

* **Description:** Binary indicator if player_clutch_bp_conv_gap was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1527 (15.27% were NA)
  * *Notes:* Same missingness as underlying break points converted metric

### `player_clutch_bp_save_gap_was_na`

* **Description:** Binary indicator if player_clutch_bp_save_gap was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1495 (14.95% were NA)
  * *Notes:* Matches missingness of underlying break points saved metric

### `player_clutch_tiebreak_adj_was_na`

* **Description:** Binary indicator if player_clutch_tiebreak_adj was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.2001 (20.01% were NA)
  * *Notes:* Lower missingness than log-ratio metrics

### `player_double_faults_pct_avg_was_na`

* **Description:** Binary indicator if player_double_faults_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Lowest missingness among serve metrics

### `player_return_1st_efficiency_was_na`

* **Description:** Binary indicator if player_return_1st_efficiency was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Consistent with other efficiency metrics

### `player_return_games_won_pct_avg_was_na`

* **Description:** Binary indicator if player_return_games_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Same missingness rate as service games metric

### `player_serve_1st_efficiency_was_na`

* **Description:** Binary indicator if player_serve_1st_efficiency was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Same missingness as component metrics

### `player_service_games_won_pct_avg_was_na`

* **Description:** Binary indicator if player_service_games_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Consistent missingness across service game metrics

### `player_total_points_won_pct_avg_was_na`

* **Description:** Binary indicator if player_total_points_won_pct_avg was missing before smoothing
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = original value was NA
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-smoothing snapshot
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1
  * *Typical Values:* Mean: 0.1476 (14.76% were NA)
  * *Notes:* Consistent with other percentage-based metrics

[⬆ Index](#index)

---

<a id="playstats"></a>
## Play Statistics (Progressive Averages)

### `opponent_aces_per_match_avg`

* **Description:** Opponent's progressive average of aces per match with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Aces per match [0.5857, 19.8049]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_aces_per_match_avg
  * *Typical Values:* Median: 4.6887, Mean: 4.7359
  * *Notes:* Same right-skewed distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_aces` per match
* **Calculation Details:**

  * Same minimum N requirement and smoothing methodology as player version
  * Important for assessing opponent's serving threat level

### `opponent_break_points_converted_pct_avg`

* **Description:** Opponent's progressive average of break points converted percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.1610, 0.7664]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_break_points_converted_pct_avg
  * *Typical Values:* Median: 0.4334, Mean: 0.4334
  * *Notes:** Same very tight distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_break_points_converted / opponent_break_points_return_total`
* **Calculation Details:**

  * Same methodology and smoothing as player version
  * Important for evaluating opponent's return pressure

### `opponent_break_points_saved_pct_avg`

* **Description:** Opponent's progressive average of break points saved percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.2788, 0.7927]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_break_points_saved_pct_avg
  * *Typical Values:* Median: 0.5686, Mean: 0.5704
  * *Notes:* Same tight distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_break_points_saved / opponent_break_points_serve_total`
* **Calculation Details:**

  * Same methodology and smoothing as player version
  * Important for identifying opponent's vulnerability under pressure

### `opponent_double_faults_pct_avg`

* **Description:** Opponent's progressive average of double faults percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.0095, 0.1140]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_double_faults_pct_avg
  * *Typical Values:* Median: 0.0420, Mean: 0.0415
  * *Notes:* Same tight distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_double_faults / opponent_first_serves_total`
* **Calculation Details:**

  * Same minimum N requirement and smoothing methodology as player version
  * Important for identifying opponent's serve weakness under pressure

### `opponent_return_games_won_pct_avg`

* **Description:** Opponent's progressive average of return games won percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.0354, 0.4993]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_return_games_won_pct_avg
  * *Typical Values:* Median: 0.2569, Mean: 0.2572
  * *Notes:* Same normal distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_break_points_converted / opponent_return_games_played`
* **Calculation Details:**

  * Same methodology and smoothing as player version
  * Critical for assessing opponent's return game strength

### `opponent_serve_1st_in_pct_avg`

* **Description:** Opponent's progressive average of first serves in percentage before current match
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.167, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_serve_1st_in_pct_avg
  * *Typical Values:* Median: 0.6046, Mean: 0.6040
  * *Notes:* Same normal distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_first_serves_in / opponent_first_serves_total`
* **Calculation Details:**

  * Same methodology as player version but from opponent's perspective
  * Maintains identical temporal integrity guarantees

### `opponent_serve_2nd_won_pct_avg`

* **Description:** Opponent's progressive average of points won on second serve before current match
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - symmetric with player version
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_serve_2nd_won_pct_avg
  * *Typical Values:* Median: 0.5038, Mean: 0.4970
  * *Notes:* Same slightly left-skewed distribution pattern
* **Source/Calculation:** Cumulative average of `opponent_second_serve_points_won / opponent_second_serve_points_total`
* **Calculation Details:**

  * Same methodology as player version but for opponent
  * Critical for assessing opponent's serve vulnerability

### `opponent_service_games_won_pct_avg`

* **Description:** Opponent's progressive average of service games won percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.3629, 0.9301]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_service_games_won_pct_avg
  * *Typical Values:* Median: 0.7587, Mean: 0.7624
  * *Notes:* Same normal distribution pattern as player version
* **Source/Calculation:** Cumulative average of `(opponent_games_won - opponent_break_points_converted) / opponent_service_games_played`
* **Calculation Details:**

  * Same calculation methodology and smoothing as player version
  * Critical for evaluating opponent's serve game strength

### `opponent_total_points_won_pct_avg`

* **Description:** Opponent's progressive average of total points won percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.3641, 0.5821]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_total_points_won_pct_avg
  * *Typical Values:* Median: 0.5010, Mean: 0.5019
  * *Notes:* Same extremely tight distribution pattern as player version
* **Source/Calculation:** Cumulative average of `opponent_total_points_won / opponent_total_points_total`
* **Calculation Details:**

  * Same methodology and smoothing as player version
  * Critical for assessing opponent's overall match dominance

### `player_aces_per_match_avg`

* **Description:** Player's progressive average of aces per match with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Aces per match [0.5857, 19.8049]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.5857, Max: 19.8049, P99: 12.2812
  * *Typical Values:* Median: 4.6887, Mean: 4.7359
  * *Notes:* Right-skewed distribution; 75% of players average ≤5.48 aces per match
* **Source/Calculation:** Cumulative average of `player_aces` per match
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=10 prior
  * **Interpretation:** Higher values indicate stronger serving power

### `player_break_points_converted_pct_avg`

* **Description:** Player's progressive average of break points converted percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.1610, 0.7664]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.1610, Max: 0.7664, P99: 0.5060
  * *Typical Values:* Median: 0.4334, Mean: 0.4334
  * *Notes:** Very tight distribution; 95% of players between 38.2%-47.9%
* **Source/Calculation:** Cumulative average of `player_break_points_converted / player_break_points_return_total`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Clutch Indicator:** Measures return efficiency under pressure

### `player_break_points_saved_pct_avg`

* **Description:** Player's progressive average of break points saved percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.2788, 0.7927]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.2788, Max: 0.7927, P99: 0.6575
  * *Typical Values:* Median: 0.5686, Mean: 0.5704
  * *Notes:* Tight distribution; 95% of players between 51.8%-62.4%
* **Source/Calculation:** Cumulative average of `player_break_points_saved / player_break_points_serve_total`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Clutch Indicator:** Measures performance under serve pressure

### `player_double_faults_pct_avg`

* **Description:** Player's progressive average of double faults percentage (double faults / first serve attempts) with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.0095, 0.1140]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0095, Max: 0.1140, P99: 0.0711
  * *Typical Values:* Median: 0.0420, Mean: 0.0415
  * *Notes:* Tight distribution; 95% of players between 2.73%-5.74%
* **Source/Calculation:** Cumulative average of `player_double_faults / player_first_serves_total`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Interpretation:** Lower values indicate better serve consistency

### `player_return_games_won_pct_avg`

* **Description:** Player's progressive average of return games won percentage (break points converted) with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.0354, 0.4993]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.0354, Max: 0.4993, P99: 0.3531
  * *Typical Values:* Median: 0.2569, Mean: 0.2572
  * *Notes:* Normal distribution; 95% of players between 19.0%-32.4%
* **Source/Calculation:** Cumulative average of `player_break_points_converted / player_return_games_played`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Interpretation:** Key metric for return game effectiveness

### `player_serve_1st_in_pct_avg`

* **Description:** Player's progressive average of first serves in percentage before current match
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.167, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs in early career matches before sufficient data
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.167, Max: 1.000, P99: 0.7227
  * *Typical Values:* Median: 0.6046, Mean: 0.6040
  * *Notes:* Normal distribution centered around 60%; 95% of players between 53.3%-67.7%
* **Source/Calculation:** Cumulative average of `player_first_serves_in / player_first_serves_total`
* **Calculation Details:**

  * **Formula:** `cumsum(first_serves_in) / cumsum(first_serves_total)` with lag
  * **Anti-leakage:** Strict chronological ordering with lag-1 protection
  * **No Minimum N:** Available from first recorded match

### `player_serve_2nd_won_pct_avg`

* **Description:** Player's progressive average of points won on second serve before current match
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.000, 1.000]
* **Missingness Policy:** Some missing (6.56% NAs) - occurs in early career matches
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 1.000, P99: 0.5795
  * *Typical Values:* Median: 0.5038, Mean: 0.4970
  * *Notes:* Slightly left-skewed; 95% of players between 42.6%-54.5%
* **Source/Calculation:** Cumulative average of `player_second_serve_points_won / player_second_serve_points_total`
* **Calculation Details:**

  * **Formula:** `cumsum(second_serve_points_won) / cumsum(second_serve_points_total)` with lag
  * **Strategic Importance:** Key indicator of serve reliability under pressure
  * **No Minimum N:** Available from first recorded match

### `player_service_games_won_pct_avg`

* **Description:** Player's progressive average of service games won percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.3629, 0.9301]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.3629, Max: 0.9301, P99: 0.8785
  * *Typical Values:* Median: 0.7587, Mean: 0.7624
  * *Notes:* Normal distribution; 95% of players between 68.9%-83.7%
* **Source/Calculation:** Cumulative average of `(player_games_won - player_break_points_converted) / player_service_games_played`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Strategic Importance:** Key indicator of overall serve dominance

### `player_total_points_won_pct_avg`

* **Description:** Player's progressive average of total points won percentage with minimum 5-match history
* **Data Type:** Float
* **Unit/Domain:** Proportion [0.3641, 0.5821]
* **Missingness Policy:** Never missing (0% NAs) - uses smoothing when N<5
* **Temporal Semantics:** Progressive average (up to t-1) with N≥5 requirement
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.3641, Max: 0.5821, P99: 0.5347
  * *Typical Values:* Median: 0.5010, Mean: 0.5019
  * *Notes:** Extremely tight distribution around 50%; 95% of players between 47.9%-52.0%
* **Source/Calculation:** Cumulative average of `player_total_points_won / player_total_points_total`
* **Calculation Details:**

  * **Minimum N:** Requires ≥5 prior matches with data before exposing average
  * **Smoothing:** Bayesian smoothing applied when N<5 using α=20 prior
  * **Overall Performance:** Best single metric for overall player quality

[⬆ Index](#index)

---

<a id="ranking"></a>
## Ranking & Trajectory

### `log_opponent_dist_to_peak`

* **Description:** Logarithmic distance from opponent's current rank to career peak: log(current_rank) − log(peak_rank).
* **Data Type:** Float
* **Unit/Domain:** Log distance [-0.9656, 7.1922]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to log_player_dist_to_peak
  * *Typical Values:* Median: 0.2221, Mean: 0.4839
  * *Notes:* Same distribution pattern as player's distance to peak
* **Source/Calculation:** Calculated as log(opponent_atp_ranking) − log(opponent_highest_atp_ranking)
* **Calculation Details:**

  * **Interpretation:**

    * **ZERO:** Opponent is at career peak
    * **POSITIVE values:** Opponent is below career peak
    * **NEGATIVE values:** Data error
  * **Strategic Importance:** Helps assess if opponent is performing at their historical best level

### `log_player_dist_to_peak`

* **Description:** Logarithmic distance from current rank to career peak: log(current_rank) − log(peak_rank).
* **Data Type:** Float
* **Unit/Domain:** Log distance [-0.9656, 7.1922]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.9656, Max: 7.1922, P99: 3.0723
  * *Typical Values:* Median: 0.2221, Mean: 0.4839
  * *Notes:** Positive skew indicates most players are below their career peak; 25% of players are very close to peak (≤0.018)
* **Source/Calculation:** Calculated as log(player_atp_ranking) − log(player_highest_atp_ranking)
* **Calculation Details:**

  * **Interpretation:**

    * **ZERO:** Player is at career peak
    * **POSITIVE values:** Player is below career peak (larger values = further from peak)
    * **NEGATIVE values:** Data error (should not occur as peak should be best rank)
  * **Psychological Insight:** Measures how far player has fallen from their best level
  * **Example:** If player's peak was 10 and current rank is 40, distance = log(40) − log(10) = log(4) ≈ 1.386

### `log_rank_ratio_t`

* **Description:** Logarithmic ratio of opponent rank to player rank: log(opponent_rank / player_rank).
* **Data Type:** Float
* **Unit/Domain:** Log ratio [-7.2182, 7.2182]
* **Missingness Policy:** Moderately missing (4.42% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -7.2182, Max: 7.2182, P99: 2.7932
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:** Scale-invariant measure; 95% of matches have log ratios within ±1.66
* **Source/Calculation:** Calculated as log(opponent_atp_ranking) − log(player_atp_ranking)
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE values:** Player is BETTER ranked than opponent (player advantage)
    * **NEGATIVE values:** Opponent is BETTER ranked than player (player disadvantage)
    * **ZERO:** Players have equal ranking
  * **Mathematical Properties:**

    * Scale-invariant: same ratio gives same log difference regardless of absolute ranks
    * Symmetric: log(a/b) = -log(b/a)
    * Compresses large differences while emphasizing small differences at top ranks
  * **Example:** If player is ranked 50 and opponent is ranked 100, log_ratio = log(100/50) = log(2) ≈ +0.693

### `opponent_atp_ranking`

* **Description:** Opponent's ATP singles ranking as of the day before tournament start (t-1).
* **Data Type:** Integer
* **Unit/Domain:** Ranking position [1, 2267]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_atp_ranking
  * *Typical Values:* Median: 200, Mean: 291.8
  * *Notes:* Same missingness pattern and distribution as player ranking
* **Source/Calculation:** Official ATP rankings with rolling join ≤ tournament start date

### `opponent_highest_atp_ranking`

* **Description:** Historical best ATP ranking achieved by the opponent up to this match.
* **Data Type:** Integer
* **Unit/Domain:** Ranking position [1, 2257]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_highest_atp_ranking
  * *Typical Values:* Median: 136, Mean: 217.7
  * *Notes:* Same pattern as player's best ranking distribution
* **Source/Calculation:** Historical maximum of opponent_atp_ranking over career

### `opponent_rank_trend_12w`

* **Description:** Opponent's numerical 12-week ranking trend: rank(t−12w) − rank(t) (positive = opponent improving).
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1417, 1684]
* **Missingness Policy:** Rarely missing (2.76% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_rank_trend_12w
  * *Typical Values:* Median: 3, Mean: 14.42
  * *Notes:** Same distribution pattern as player's 12-week trend
* **Source/Calculation:** Calculated as opponent_rank(t−12w) − opponent_rank(t)
* **Calculation Details:**

  * **Interpretation:**

    * Positive values indicate opponent has been improving over 3-month period
    * Negative values indicate opponent has been declining
  * **Strategic Importance:** Reveals opponent's longer-term career trajectory

### `opponent_rank_trend_12w_cat`

* **Description:** Opponent's 12-week ranking trend category.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {-1: bajada, 0: estable, 1: subida}
* **Missingness Policy:** Rarely missing (2.76% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_rank_trend_12w_cat
  * *Typical Values:* -1 (40.3%), 1 (51.9%)
  * *Notes:* Same trend distribution as player's 12-week categories
* **Source/Calculation:** Categorized from opponent's rank(t−12w) − rank(t)
* **Calculation Details:**

  * **Trend Formula:** `trend = opponent_rank(t−12w) − opponent_rank(t)` (positive values indicate improvement for opponent)
  * **Adaptive Threshold:** `threshold = max(1, ceil(0.05 * max(opponent_rank(t), opponent_rank(t−12w))))`
  * **Categorization:**

    * "subida" (improving) if `trend ≥ threshold`
    * "bajada" (declining) if `trend ≤ -threshold`
    * "estable" (stable) if `-threshold < trend < threshold`

### `opponent_rank_trend_4w`

* **Description:** Opponent's numerical 4-week ranking trend: rank(t−4w) − rank(t) (positive = opponent improving).
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1340, 1334]
* **Missingness Policy:** Rarely missing (2.56% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_rank_trend_4w
  * *Typical Values:* Median: 1, Mean: 4.77
  * *Notes:** Same distribution pattern as player's 4-week trend
* **Source/Calculation:** Calculated as opponent_rank(t−4w) − opponent_rank(t)
* **Calculation Details:**

  * **Interpretation:**

    * Positive values indicate opponent is improving
    * Negative values indicate opponent is declining
  * **Strategic Importance:** Helps assess opponent's recent form and momentum

### `opponent_rank_trend_4w_cat`

* **Description:** Opponent's 4-week ranking trend category.
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {-1: bajada, 0: estable, 1: subida}
* **Missingness Policy:** Rarely missing (2.56% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_rank_trend_4w_cat
  * *Typical Values:* -1 (42.4%), 1 (49.1%)
  * *Notes:* Same trend distribution as player's 4-week categories
* **Source/Calculation:** Categorized from opponent's rank(t−4w) − rank(t)
* **Calculation Details:**

  * **Trend Formula:** `trend = opponent_rank(t−4w) − opponent_rank(t)` (positive values indicate improvement for opponent)
  * **Adaptive Threshold:** `threshold = max(1, ceil(0.02 * max(opponent_rank(t), opponent_rank(t−4w))))`
  * **Categorization:**

    * "subida" (improving) if `trend ≥ threshold`
    * "bajada" (declining) if `trend ≤ -threshold`
    * "estable" (stable) if `-threshold < trend < threshold`

### `player_atp_ranking`

* **Description:** Player's ATP singles ranking as of the day before tournament start (t-1).
* **Data Type:** Integer
* **Unit/Domain:** Ranking position [1, 2267]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 2267, P99: 1644
  * *Typical Values:* Median: 200, Mean: 291.8
  * *Notes:* Distribution is right-skewed; 25% of players are ranked ≤100, 75% ≤354
* **Source/Calculation:** Official ATP rankings with rolling join ≤ tournament start date

### `player_highest_atp_ranking`

* **Description:** Historical best ATP ranking achieved by the player up to this match.
* **Data Type:** Integer
* **Unit/Domain:** Ranking position [1, 2257]
* **Missingness Policy:** Rarely missing (2.44% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 2257, P99: 1488
  * *Typical Values:* Median: 136, Mean: 217.7
  * *Notes:* Consistently better than current ranking (median 136 vs 200), showing career progression
* **Source/Calculation:** Historical maximum of player_atp_ranking over career

### `player_rank_trend_12w`

* **Description:** Numerical 12-week ranking trend: rank(t−12w) − rank(t) (positive = improving).
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1417, 1684]
* **Missingness Policy:** Rarely missing (2.76% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1417, Max: 1684, P99: 342
  * *Typical Values:* Median: 3, Mean: 14.42
  * *Notes:** Stronger positive bias than 4-week trend; 75% of players improved or declined by ≤29 positions
* **Source/Calculation:** Calculated as rank(t−12w) − rank(t)
* **Calculation Details:**

  * **Interpretation:**

    * Positive values indicate improvement over 12-week period
    * Negative values indicate decline over 12-week period
  * **Example:** If a player was ranked 100 twelve weeks ago and is now ranked 75, the trend is +25 (significant improvement).
  * **Note:** 12-week window captures more substantial career trajectory changes compared to 4-week window

### `player_rank_trend_12w_cat`

* **Description:** 12-week ranking trend category using adaptive threshold (~5% of max(rank_t, rank_t−12w)).
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {-1: bajada, 0: estable, 1: subida}
* **Missingness Policy:** Rarely missing (2.76% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* -1 (40.3%), 0 (7.8%), 1 (51.9%)
  * *Typical Values:* More players show improvement over 12 weeks (51.9%)
  * *Notes:* Longer timeframe shows more positive trends compared to 4-week period
* **Source/Calculation:** Categorized from rank(t−12w) − rank(t) with adaptive threshold
* **Calculation Details:**

  * **Trend Formula:** `trend = rank(t−12w) − rank(t)` (positive values indicate improvement)
  * **Adaptive Threshold:** `threshold = max(1, ceil(0.05 * max(rank(t), rank(t−12w))))`
  * **Categorization:**

    * "subida" (improving) if `trend ≥ threshold`
    * "bajada" (declining) if `trend ≤ -threshold`
    * "estable" (stable) if `-threshold < trend < threshold`

### `player_rank_trend_4w`

* **Description:** Numerical 4-week ranking trend: rank(t−4w) − rank(t) (positive = improving).
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1340, 1334]
* **Missingness Policy:** Rarely missing (2.56% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1340, Max: 1334, P99: 159
  * *Typical Values:* Median: 1, Mean: 4.77
  * *Notes:** Slight positive bias; 75% of players improved or declined by ≤10 ranking positions
* **Source/Calculation:** Calculated as rank(t−4w) − rank(t)
* **Calculation Details:**

  * **Interpretation:**

    * Positive values indicate improvement (player's ranking has gone down in number, meaning better position)
    * Negative values indicate decline (player's ranking has gone up in number, meaning worse position)
  * **Example:** If a player was ranked 50 four weeks ago and is now ranked 45, the trend is +5 (improvement).

### `player_rank_trend_4w_cat`

* **Description:** 4-week ranking trend category using adaptive threshold (~2% of max(rank_t, rank_t−4w)).
* **Data Type:** Categorical (Ordinal)
* **Unit/Domain:** {-1: bajada, 0: estable, 1: subida}
* **Missingness Policy:** Rarely missing (2.56% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* -1 (42.4%), 0 (8.5%), 1 (49.1%)
  * *Typical Values:* Slightly more players improving (49.1%) than declining (42.4%)
  * *Notes:* Categories intentionally in Spanish; positive trend (1) is most common
* **Source/Calculation:** Categorized from rank(t−4w) − rank(t) with adaptive threshold
* **Calculation Details:**

  * **Trend Formula:** `trend = rank(t−4w) − rank(t)` (positive values indicate improvement)
  * **Adaptive Threshold:** `threshold = max(1, ceil(0.02 * max(rank(t), rank(t−4w))))`
  * **Categorization:**

    * "subida" (improving) if `trend ≥ threshold`
    * "bajada" (declining) if `trend ≤ -threshold`
    * "estable" (stable) if `-threshold < trend < threshold`

### `rank_diff_t`

* **Description:** Ranking difference between opponent and player: opponent_rank − player_rank.
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-2126, 2126]
* **Missingness Policy:** Moderately missing (4.42% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -2126, Max: 2126, P99: 1144
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:** Distribution centered at 0 with symmetric tails; 95% of matches have rank differences within ±489 positions
* **Source/Calculation:** Calculated as opponent_atp_ranking − player_atp_ranking
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE values:** Opponent is WORSE ranked than player (player advantage)
    * **NEGATIVE values:** Opponent is BETTER ranked than player (player disadvantage)
    * **ZERO:** Players have equal ranking
  * **Example:** If player is ranked 50 and opponent is ranked 100, rank_diff_t = +50 (player advantage)

### `trend_diff_12w`

* **Description:** Difference in 12-week ranking trends: opponent_trend_12w − player_trend_12w.
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1732, 1732]
* **Missingness Policy:** Moderately missing (4.97% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1732, Max: 1732, P99: 393
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:** Distribution centered at 0; 95% of matches have trend differences within ±158 positions
* **Source/Calculation:** Calculated as opponent_rank_trend_12w − player_rank_trend_12w
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE values:** Opponent has BETTER 3-month momentum than player
    * **NEGATIVE values:** Player has BETTER 3-month momentum than opponent
    * **ZERO:** Both players have similar 3-month momentum
  * **Strategic Importance:** Captures relative career trajectories over longer period

### `trend_diff_4w`

* **Description:** Difference in 4-week ranking trends: opponent_trend_4w − player_trend_4w.
* **Data Type:** Integer
* **Unit/Domain:** Ranking points [-1624, 1624]
* **Missingness Policy:** Moderately missing (4.62% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1624, Max: 1624, P99: 198
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:** Distribution centered at 0; 95% of matches have trend differences within ±74 positions
* **Source/Calculation:** Calculated as opponent_rank_trend_4w − player_rank_trend_4w
* **Calculation Details:**

  * **Interpretation:**

    * **POSITIVE values:** Opponent has BETTER recent momentum than player
    * **NEGATIVE values:** Player has BETTER recent momentum than opponent
    * **ZERO:** Both players have similar recent momentum
  * **Example:** If player trend_4w = +5 and opponent trend_4w = +15, trend_diff_4w = +10 (opponent has better momentum)

[⬆ Index](#index)
    
---

<a id="recentform"></a>
## Recent Form, Consistency & In-Tournament Load

### `cumulative_sets`

* **Description:** Total sets played by player including current match within current tournament.
* **Data Type:** Integer
* **Unit/Domain:** Set count [0, 31]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 31, P99: 14
  * *Typical Values:* Median: 3, Mean: 4.363
  * *Notes:** Right-skewed distribution; 25% of matches are first round (0 prior sets)
* **Source/Calculation:** Cumulative sum of sets_in_match within tournament
* **Calculation Details:**

  * **Includes:** Current match's sets
  * **Ordering:** Stable chronological ordering within tournament
  * **Purpose:** Measures total workload in current tournament

### `momentum_diff_10`

* **Description:** Difference in 10-match win rates between player and opponent (player − opponent).
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-1, 1]
* **Missingness Policy:** Moderately missing (3.67% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1, Max: 1, P99: 0.6
  * *Typical Values:* Median: 0, Mean: 0 (symmetric)
  * *Notes:** Tighter distribution than 5-match version; 95% of matches have momentum differences within ±0.4
* **Source/Calculation:** Calculated as player_win_ratio_last_10_matches − opponent_win_ratio_last_10_matches
* **Interpretation:**

  * **POSITIVE:** Player has better medium-term form than opponent (10-match window)
  * **NEGATIVE:** Opponent has better medium-term form than player
  * **ZERO:** Players have similar medium-term form

### `momentum_diff_5`

* **Description:** Difference in 5-match win rates between player and opponent (player − opponent).
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-1, 1]
* **Missingness Policy:** Moderately missing (3.67% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1, Max: 1, P99: 0.6
  * *Typical Values:* Median: 0, Mean: 0 (symmetric)
  * *Notes:** Distribution centered at 0; 95% of matches have momentum differences within ±0.4
* **Source/Calculation:** Calculated as player_win_ratio_last_5_matches − opponent_win_ratio_last_5_matches
* **Interpretation:**

  * **POSITIVE:** Player has better recent form than opponent (5-match window)
  * **NEGATIVE:** Opponent has better recent form than player
  * **ZERO:** Players have similar recent form

### `opponent_consistency`

* **Description:** Absolute difference between opponent's 5-match and 10-match win rates, measuring form stability.
* **Data Type:** Float
* **Unit/Domain:** Absolute difference [0, 0.5]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_consistency
  * *Typical Values:* Median: 0.1, Mean: 0.1059
  * *Notes:** Same consistency pattern as player's metrics
* **Source/Calculation:** Calculated as |opponent_win_ratio_last_5_matches − opponent_win_ratio_last_10_matches|
* **Interpretation:**

  * **LOWER values:** Opponent has more consistent performance
  * **HIGHER values:** Opponent has more volatile performance

### `opponent_good_form_10`

* **Description:** Binary flag indicating if opponent has strong medium-term form (>70% win rate in last 10 matches).
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = opponent_win_ratio_last_10_matches > 0.7
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_good_form_10
  * *Typical Values:* 0 (92.26%), 1 (7.74%)
  * *Notes:** Same rarity as player's 10-match good form
* **Source/Calculation:** Derived from opponent_win_ratio_last_10_matches with threshold of 0.7
* **Strategic Importance:** Identifies consistently strong opponents over longer period

### `opponent_good_form_5`

* **Description:** Binary flag indicating if opponent has strong recent form (>70% win rate in last 5 matches).
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = opponent_win_ratio_last_5_matches > 0.7
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_good_form_5
  * *Typical Values:* 0 (82.19%), 1 (17.81%)
  * *Notes:** Same proportion as player's 5-match good form
* **Source/Calculation:** Derived from opponent_win_ratio_last_5_matches with threshold of 0.7
* **Strategic Importance:** Identifies opponents with recent winning momentum

### `opponent_prev_matches`

* **Description:** Opponent's total career matches played before current match (exposure count).
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1513]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_prev_matches
  * *Typical Values:* Median: 149, Mean: 218.7
  * *Notes:** Same experience distribution as players
* **Source/Calculation:** Cumulative count from unified match history for opponent
* **Interpretation:**

  * **LOW values:** Inexperienced opponents
  * **HIGH values:** Seasoned veteran opponents

### `opponent_sets_played_tournament`

* **Description:** Sets played by opponent before current match within current tournament.
* **Data Type:** Integer
* **Unit/Domain:** Set count [0, 26]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_sets_played_tournament
  * *Typical Values:* Median: 0, Mean: 2.053
  * *Notes:** Same distribution pattern as player's tournament sets
* **Source/Calculation:** Cumulative sets minus current match sets for opponent
* **Strategic Importance:** Measures opponent's fatigue/accumulated workload

### `opponent_trend`

* **Description:** Difference between opponent's short-term and medium-term form (opponent_5_matches − opponent_10_matches).
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.5, 0.5]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_trend
  * *Typical Values:* Median: 0, Mean: -0.0087
  * *Notes:** Same slight negative bias and distribution as player_trend
* **Source/Calculation:** Calculated as opponent_win_ratio_last_5_matches − opponent_win_ratio_last_10_matches
* **Interpretation:**

  * **POSITIVE:** Opponent's form is improving
  * **NEGATIVE:** Opponent's form is declining
  * **ZERO:** Opponent's form is stable

### `opponent_win_ratio_last_10_matches`

* **Description:** Opponent's rolling win rate over the last 10 matches before current match (lagged).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_ratio_last_10_matches
  * *Typical Values:* Median: 0.5, Mean: 0.4983
  * *Notes:** Same continuous distribution as player's 10-match win rate
* **Source/Calculation:** Rolling window over unified chronological history (pre-1999 + 1999-2025)
* **Calculation Details:**

  * Same methodology as player version but for opponent
  * Maintains identical anti-leakage guarantees

### `opponent_win_ratio_last_5_matches`

* **Description:** Opponent's rolling win rate over the last 5 matches before current match (lagged).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_ratio_last_5_matches
  * *Typical Values:* Median: 0.4, Mean: 0.4895
  * *Notes:** Same discrete pattern as player's 5-match win rate
* **Source/Calculation:** Rolling window over unified chronological history (pre-1999 + 1999-2025)
* **Calculation Details:**

  * Same methodology as player version but for opponent
  * Maintains identical anti-leakage guarantees

### `opponent_won_previous_tournament`

* **Description:** Binary flag indicating if opponent won their most recent tournament before this one.
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = opponent won their previous tournament
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_won_previous_tournament
  * *Typical Values:* 0 (97.31%), 1 (2.69%)
  * *Notes:** Same rarity as player's previous tournament win flag
* **Source/Calculation:** Non-equi join to find immediate previous tournament and check if opponent won final
* **Strategic Importance:** Identifies opponents arriving with championship momentum

### `player_consistency`

* **Description:** Absolute difference between 5-match and 10-match win rates, measuring form stability.
* **Data Type:** Float
* **Unit/Domain:** Absolute difference [0, 0.5]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 0.5, P99: 0.4
  * *Typical Values:* Median: 0.1, Mean: 0.1059
  * *Notes:** 25% of players show perfect consistency (0 difference); 75% have ≤0.2 difference
* **Source/Calculation:** Calculated as |player_win_ratio_last_5_matches − player_win_ratio_last_10_matches|
* **Interpretation:**

  * **LOWER values:** More consistent performance across time horizons
  * **HIGHER values:** More volatile/inconsistent performance
  * **ZERO:** Perfect consistency between short and medium-term form

### `player_good_form_10`

* **Description:** Binary flag indicating if player has strong medium-term form (>70% win rate in last 10 matches).
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = player_win_ratio_last_10_matches > 0.7
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 0 (92.26%), 1 (7.74%)
  * *Typical Values:** Much rarer than 5-match good form
  * *Notes:** Only about 1 in 13 players maintain strong form over 10 matches
* **Source/Calculation:** Derived from player_win_ratio_last_10_matches with threshold of 0.7
* **Strategic Importance:** Identifies consistently strong performers over longer period

### `player_good_form_5`

* **Description:** Binary flag indicating if player has strong recent form (>70% win rate in last 5 matches).
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = player_win_ratio_last_5_matches > 0.7
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 0 (82.19%), 1 (17.81%)
  * *Typical Values:* Majority of players not in strong short-term form
  * *Notes:** Approximately 1 in 6 players exhibit strong 5-match form
* **Source/Calculation:** Derived from player_win_ratio_last_5_matches with threshold of 0.7
* **Strategic Importance:** Identifies players with recent winning momentum

### `player_prev_matches`

* **Description:** Player's total career matches played before current match (exposure count).
* **Data Type:** Integer
* **Unit/Domain:** Match count [0, 1513]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1513, P99: 907
  * *Typical Values:* Median: 149, Mean: 218.7
  * *Notes:** Highly right-skewed; 25% of players have ≤47 career matches
* **Source/Calculation:** Cumulative count from unified match history (pre-1999 + 1999-2025)
* **Interpretation:**

  * **LOW values:** Inexperienced players (rookies or early career)
  * **HIGH values:** Seasoned veterans with extensive match experience
  * **Purpose:** Controls for experience effects in modeling

### `player_sets_played_tournament`

* **Description:** Sets played by player before current match within current tournament.
* **Data Type:** Integer
* **Unit/Domain:** Set count [0, 26]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 26, P99: 11
  * *Typical Values:* Median: 0, Mean: 2.053
  * *Notes:** 50% of players have 0 sets played (first match in tournament)
* **Source/Calculation:** Cumulative sets minus current match sets
* **Calculation Details:**

  * **Anti-leakage:** Strictly counts sets before current match
  * **Formula:** `cumulative_sets - sets_in_current_match`
  * **Purpose:** Measures fatigue/accumulated workload entering current match

### `player_trend`

* **Description:** Difference between short-term and medium-term form (player_5_matches − player_10_matches).
* **Data Type:** Float
* **Unit/Domain:** Difference in proportion [-0.5, 0.5]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -0.5, Max: 0.5, P99: 0.3
  * *Typical Values:* Median: 0, Mean: -0.0087
  * *Notes:** Slight negative bias; 95% of players have trends within ±0.2
* **Source/Calculation:** Calculated as player_win_ratio_last_5_matches − player_win_ratio_last_10_matches
* **Interpretation:**

  * **POSITIVE:** Player's form is improving (recent results better than medium-term)
  * **NEGATIVE:** Player's form is declining (recent results worse than medium-term)
  * **ZERO:** Player's form is stable

### `player_win_ratio_last_10_matches`

* **Description:** Player's rolling win rate over the last 10 matches before current match (lagged).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1, P99: 0.9
  * *Typical Values:* Median: 0.5, Mean: 0.4983
  * *Notes:** More continuous distribution than 5-match version; 95% of players have win rate ≤0.8
* **Source/Calculation:** Rolling window over unified chronological history (pre-1999 + 1999-2025)
* **Calculation Details:**

  * **Window:** Last 10 matches before current match
  * **Seeding:** Uses pre-1999 match results as historical context
  * **Anti-leakage:** Computed then lagged by 1 match to exclude current match
  * **Formula:** `mean(win_flag) over last 10 matches, then shift(1)`

### `player_win_ratio_last_5_matches`

* **Description:** Player's rolling win rate over the last 5 matches before current match (lagged).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (1.99% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1, P99: 1.0
  * *Typical Values:* Median: 0.4, Mean: 0.4895
  * *Notes:** Discrete distribution with common values at 0, 0.4, 0.6; 25% of players have win rate exactly 0.4
* **Source/Calculation:** Rolling window over unified chronological history (pre-1999 + 1999-2025)
* **Calculation Details:**

  * **Window:** Last 5 matches before current match
  * **Seeding:** Uses pre-1999 (1968-1998) match results as historical context
  * **Anti-leakage:** Computed then lagged by 1 match to exclude current match
  * **Formula:** `mean(win_flag) over last 5 matches, then shift(1)`

### `player_won_previous_tournament`

* **Description:** Binary flag indicating if player won their most recent tournament before this one.
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = player won their previous tournament
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 0 (97.31%), 1 (2.69%)
  * *Typical Values:** Extremely rare - only about 1 in 37 players arrive as defending champions
  * *Notes:** Only players who reached and won the final in their previous tournament get flag=1
* **Source/Calculation:** Non-equi join to find immediate previous tournament and check if player won final
* **Calculation Details:**

  * **Method:** Unified timeline of player tournaments (pre-1999 + 1999-2025)
  * **Logic:** For each (player, current tournament), find immediately previous tournament and check if player was winner in final round
  * **Scope:** Includes both pre-1999 and modern era tournaments

[⬆ Index](#index)

---

<a id="rest"></a>
## Rest, Schedule & Travel Variables

### `opponent_back_to_back_week`

* **Description:** Binary flag indicating if opponent had ≤9 days rest since previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* Identical distribution to player_back_to_back_week
  * *Typical Values:* Mean: 0.4683
  * *Notes:** Perfect symmetry: 46.83% of opponents also have back-to-back scheduling
* **Source/Calculation:** Derived from `opponent_days_since_prev_tournament ≤ 9`
* **Calculation Details:**

  * Same threshold logic as player version
  * Enables direct comparison of rest advantages/disadvantages in match-ups

### `opponent_continent_changed`

* **Description:** Binary flag indicating if tournament continent changed from opponent's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (73.92%), 1 (26.08%)
  * *Typical Values:* Mean: 0.2608
  * *Notes:** Same distribution as player; long-haul travel affects both equally
* **Source/Calculation:** Computed as `continent != previous_tournament_continent` for opponent
* **Calculation Details:**

  * Same continent mapping dictionary as player version

### `opponent_country_changed`

* **Description:** Binary flag indicating if tournament country changed from opponent's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (32%), 1 (68%)
  * *Typical Values:* Mean: 0.68, Median: 1.00
  * *Notes:** Identical to player distribution; international travel is common for both
* **Source/Calculation:** Computed as `tournament_country != previous_tournament_country` for opponent
* **Calculation Details:**

  * Same ISO-3 country code comparison as player version

### `opponent_days_since_prev_tournament`

* **Description:** Number of days between the current tournament start and the opponent's previous tournament participation
* **Data Type:** Float
* **Unit/Domain:** Days [1.00, 20439.00]
* **Missingness Policy:** Rarely missing (2.97% NAs) - same as player version
* **Temporal Semantics:** Pre-match calculation (t-1) using strict chronological ordering
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_days_since_prev_tournament
  * *Typical Values:* Median: 13.00, Mean: 42.59
  * *Notes:** Same right-skewed distribution; perfect symmetry between player and opponent
* **Source/Calculation:** Same computation as player version but for opponent
* **Calculation Details:**

  * Maintains identical temporal integrity and seeding logic
  * Essential for fair match-up analysis

### `opponent_indoor_changed`

* **Description:** Binary flag indicating if indoor/outdoor setting changed from opponent's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (85.54%), 1 (14.46%)
  * *Typical Values:* Mean: 0.1446
  * *Notes:** Identical to player; least frequent change type for both
* **Source/Calculation:** Computed as `indoor_outdoor != previous_tournament_indoor_outdoor` for opponent
* **Calculation Details:**

  * Same environmental condition comparison

### `opponent_long_rest`

* **Description:** Binary flag indicating if opponent had ≥21 days rest since previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (70.06%), 1 (29.94%)
  * *Typical Values:* Mean: 0.2994
  * *Notes:** Same distribution as player; second most common rest pattern
* **Source/Calculation:** Derived from `opponent_days_since_prev_tournament ≥ 21`
* **Calculation Details:**

  * Same extended break logic as player version
  * Enables comparison of freshness vs match sharpness between opponents

### `opponent_prev_tour_matches`

* **Description:** Number of matches played by the opponent in their previous tournament
* **Data Type:** Integer
* **Unit/Domain:** Match count [1, 9]
* **Missingness Policy:** Rarely missing (2.45% NAs) - same as player version
* **Temporal Semantics:** Pre-match calculation (t-1) - from previous tournament performance
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 9, P99: 6
  * *Typical Values:* Median: 2, Mean: 2.119
  * *Notes:** Identical right-skewed distribution; same match load patterns
* **Source/Calculation:** Count of matches in previous tournament for opponent, with pre-1999 historical seeding
* **Calculation Details:**

  * Same computation logic and historical integration as player version

### `opponent_prev_tour_max_round`

* **Description:** Highest round reached by opponent in previous tournament (encoded as ordinal)
* **Data Type:** Integer (ordinal)
* **Unit/Domain:** Round code [1, 13] mapping to: 1=Q1, 6=R128, 8=R32, 9=R16, 12=SF, 13=F
* **Missingness Policy:** Rarely missing (2.45% NAs) - same pattern as player
* **Temporal Semantics:** Pre-match calculation (t-1) - from previous tournament performance
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 13, P99: 12
  * *Typical Values:* Median: 8 (R32), Mean: 7.04
  * *Notes:** Same bimodal distribution as player version
* **Source/Calculation:** Maximum round achieved in previous tournament by opponent, aligned to standard ladder
* **Calculation Details:**

  * Same round mapping and pre-1999 historical integration as player version

### `opponent_red_eye_risk`

* **Description:** Binary flag indicating high-risk travel scenario for opponent: back-to-back week AND inter-continent change
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - composite of two conditions
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (93.46%), 1 (6.54%)
  * *Typical Values:* Mean: 0.06539
  * *Notes:** Identical rare occurrence as player; high-impact travel scenario
* **Source/Calculation:** Computed as `opponent_back_to_back_week == 1 & opponent_continent_changed == 1`
* **Calculation Details:**

  * Same high-risk scenario definition as player version

### `opponent_surface_changed`

* **Description:** Binary flag indicating if court surface changed from opponent's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (76.21%), 1 (23.79%)
  * *Typical Values:* Mean: 0.2379
  * *Notes:** Same frequency as player; surface changes affect about 1/4 of tournaments
* **Source/Calculation:** Computed as `surface != previous_tournament_surface` for opponent
* **Calculation Details:**

  * Same surface type comparison: {Clay, Grass, Hard, Carpet}

### `opponent_travel_fatigue`

* **Description:** Composite score quantifying cumulative travel and adaptation demands for opponent
* **Data Type:** Float
* **Unit/Domain:** Score [0.000, 4.500]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - weighted sum of change indicators
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 4.500, P99: 4.000
  * *Typical Values:* Median: 1.000, Mean: 1.512
  * *Notes:** Identical multi-modal distribution to player version
* **Source/Calculation:** Weighted sum: `2*continent_changed + 1*country_changed + 1*surface_changed + 0.5*indoor_changed` for opponent
* **Calculation Details:**

  * Same weighting scheme as player: Continent (2x), Country/Surface (1x), Indoor (0.5x)

### `opponent_two_weeks_gap`

* **Description:** Binary flag indicating if opponent had 10-16 days rest since previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (80.99%), 1 (19.01%)
  * *Typical Values:* Mean: 0.1901
  * *Notes:** Identical distribution to player version; intermediate rest pattern
* **Source/Calculation:** Derived from `9 < opponent_days_since_prev_tournament ≤ 16`
* **Calculation Details:**

  * Same threshold logic as player version
  * Represents standard two-week tour schedule for opponent

### `opponent_weeks_since_prev_tournament`

* **Description:** Number of weeks between the current tournament start and the opponent's previous tournament participation
* **Data Type:** Float
* **Unit/Domain:** Weeks [0.1429, 2919.8571]
* **Missingness Policy:** Rarely missing (2.97% NAs) - same as player version
* **Temporal Semantics:** Pre-match calculation (t-1) - derived from days
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_weeks_since_prev_tournament
  * *Typical Values:* Median: 1.86, Mean: 6.08
  * *Notes:** Perfect symmetry with player metric distribution
* **Source/Calculation:** Derived from `opponent_days_since_prev_tournament / 7`
* **Calculation Details:**

  * Same transformation logic as player version

### `player_back_to_back_week`

* **Description:** Binary flag indicating if player had ≤9 days rest since previous tournament (back-to-back scheduling)
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (53.17%), 1 (46.83%)
  * *Typical Values:* Mean: 0.4683
  * *Notes:** Most frequent rest pattern; nearly half of all tournament appearances are back-to-back
* **Source/Calculation:** Derived from `player_days_since_prev_tournament ≤ 9`
* **Calculation Details:**

  * Represents the most demanding schedule with minimal recovery time
  * Important for fatigue and injury risk assessment

### `player_continent_changed`

* **Description:** Binary flag indicating if tournament continent changed from player's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (73.92%), 1 (26.08%)
  * *Typical Values:* Mean: 0.2608
  * *Notes:** Occurs in about 1/4 of tournaments; indicates long-haul international travel
* **Source/Calculation:** Computed as `continent != previous_tournament_continent`
* **Calculation Details:**

  * Uses static offline dictionary mapping ISO-3 countries to continents
  * Considered more disruptive than country changes due to greater travel demands

### `player_country_changed`

* **Description:** Binary flag indicating if tournament country changed from player's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (32%), 1 (68%)
  * *Typical Values:* Mean: 0.68, Median: 1.00
  * *Notes:** Most frequent change type; players change countries in majority of tournaments
* **Source/Calculation:** Computed as `tournament_country != previous_tournament_country`
* **Calculation Details:**

  * Reflects international travel demands
  * Uses ISO-3 country codes for comparison

### `player_days_since_prev_tournament`

* **Description:** Number of days between the current tournament start and the player's previous tournament participation
* **Data Type:** Float
* **Unit/Domain:** Days [1.00, 20439.00]
* **Missingness Policy:** Rarely missing (2.97% NAs) - occurs for players' first tournaments in dataset
* **Temporal Semantics:** Pre-match calculation (t-1) using strict chronological ordering
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1.00, Max: 20439.00, P99: 567.00
  * *Typical Values:* Median: 13.00, Mean: 42.59
  * *Notes:* Highly right-skewed distribution; 75% of values ≤21 days; extreme max value (~56 years) likely from pre-1999 seeding
* **Source/Calculation:** Computed as `current_tournament_start_dtm - previous_tournament_start_dtm` with pre-1999 historical seeding
* **Calculation Details:**

  * Uses Jeff Sackmann archive for players who turned pro before 1999
  * Strict anti-leakage: previous tournament date must be before current tournament
  * Includes both ATP and Challenger level tournaments

### `player_indoor_changed`

* **Description:** Binary flag indicating if indoor/outdoor setting changed from player's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (85.54%), 1 (14.46%)
  * *Typical Values:* Mean: 0.1446
  * *Notes:** Least frequent change type; environmental conditions relatively stable
* **Source/Calculation:** Computed as `indoor_outdoor != previous_tournament_indoor_outdoor`
* **Calculation Details:**

  * Values: {"Indoor", "Outdoor"}
  * Affects playing conditions like wind, temperature, and lighting

### `player_long_rest`

* **Description:** Binary flag indicating if player had ≥21 days rest since previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (70.06%), 1 (29.94%)
  * *Typical Values:* Mean: 0.2994
  * *Notes:** Second most common rest pattern; represents extended breaks
* **Source/Calculation:** Derived from `player_days_since_prev_tournament ≥ 21`
* **Calculation Details:**

  * Indicates off-season, injury recovery, or strategic scheduling breaks
  * May affect match sharpness vs physical freshness

### `player_prev_tour_matches`

* **Description:** Number of matches played by the player in their previous tournament
* **Data Type:** Integer
* **Unit/Domain:** Match count [1, 9]
* **Missingness Policy:** Rarely missing (2.45% NAs) - occurs for players' first tournaments
* **Temporal Semantics:** Pre-match calculation (t-1) - from previous tournament performance
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 9, P99: 6
  * *Typical Values:* Median: 2, Mean: 2.119
  * *Notes:** Right-skewed; 75% of players played ≤3 matches in previous tournament
* **Source/Calculation:** Count of matches in previous tournament, with pre-1999 historical seeding
* **Calculation Details:**

  * Includes all match types (main draw, qualifying)
  * Pre-1999 data from Jeff Sackmann archive for players who turned pro before 1999

### `player_prev_tour_max_round`

* **Description:** Highest round reached by player in previous tournament (encoded as ordinal)
* **Data Type:** Integer (ordinal)
* **Unit/Domain:** Round code [1, 13] mapping to: 1=Q1, 6=R128, 8=R32, 9=R16, 12=SF, 13=F
* **Missingness Policy:** Rarely missing (2.45% NAs) - same pattern as previous matches
* **Temporal Semantics:** Pre-match calculation (t-1) - from previous tournament performance
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 1, Max: 13, P99: 12
  * *Typical Values:* Median: 8 (R32), Mean: 7.04
  * *Notes:** Bimodal distribution with peaks at early rounds (1,6) and middle rounds (8,9)
* **Source/Calculation:** Maximum round achieved in previous tournament, aligned to standard ladder
* **Calculation Details:**

  * **Round Mapping:** Uses standard ATP round codes: Q1, Q2, Q3, BR, RR, R128, R64, R32, R16, QF, SF, F, 3P
  * **Pre-1999:** Historical data integrated with round alignment (ER→R128)

### `player_red_eye_risk`

* **Description:** Binary flag indicating high-risk travel scenario: back-to-back week AND inter-continent change
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - composite of two conditions
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (93.46%), 1 (6.54%)
  * *Typical Values:* Mean: 0.06539
  * *Notes:** Rare but high-impact scenario; only 6.5% of tournament appearances
* **Source/Calculation:** Computed as `player_back_to_back_week == 1 & player_continent_changed == 1`
* **Calculation Details:**

  * Represents the most demanding travel scenario: minimal rest + long-haul flight
  * Key variable for fatigue and jet lag analysis

### `player_surface_changed`

* **Description:** Binary flag indicating if court surface changed from player's previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - compares consecutive tournaments
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (76.21%), 1 (23.79%)
  * *Typical Values:* Mean: 0.2379
  * *Notes:** Less common than country changes; occurs in about 1/4 of tournaments
* **Source/Calculation:** Computed as `surface != previous_tournament_surface`
* **Calculation Details:**

  * Surface types: {Clay, Grass, Hard, Carpet}
  * Important for technical adaptation and performance expectations

### `player_travel_fatigue`

* **Description:** Composite score quantifying cumulative travel and adaptation demands
* **Data Type:** Float
* **Unit/Domain:** Score [0.000, 4.500]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1) - weighted sum of change indicators
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.000, Max: 4.500, P99: 4.000
  * *Typical Values:* Median: 1.000, Mean: 1.512
  * *Notes:** Multi-modal distribution; 25% of players have score 0, 25% have score 3+
* **Source/Calculation:** Weighted sum: `2*continent_changed + 1*country_changed + 1*surface_changed + 0.5*indoor_changed`
* **Calculation Details:**

  * **Weighting:** Continent changes (2x) considered most disruptive, followed by country/surface (1x), then indoor (0.5x)
  * **Interpretation:** Higher scores indicate greater cumulative travel/adaptation burden

### `player_two_weeks_gap`

* **Description:** Binary flag indicating if player had 10-16 days rest since previous tournament
* **Data Type:** Integer (binary)
* **Unit/Domain:** Binary [0, 1]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Values:* 0 (80.99%), 1 (19.01%)
  * *Typical Values:* Mean: 0.1901
  * *Notes:** Intermediate rest pattern; less common than back-to-back weeks
* **Source/Calculation:** Derived from `9 < player_days_since_prev_tournament ≤ 16`
* **Calculation Details:**

  * Represents standard two-week tour schedule
  * Allows for adequate recovery between tournaments

### `player_weeks_since_prev_tournament`

* **Description:** Number of weeks between the current tournament start and the player's previous tournament participation
* **Data Type:** Float
* **Unit/Domain:** Weeks [0.1429, 2919.8571]
* **Missingness Policy:** Rarely missing (2.97% NAs) - same missingness pattern as days version
* **Temporal Semantics:** Pre-match calculation (t-1) - derived from days
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0.14, Max: 2919.86, P99: 81.00
  * *Typical Values:* Median: 1.86, Mean: 6.08
  * *Notes:* Same right-skewed distribution as days; 95% of players return within 24 weeks
* **Source/Calculation:** Derived from `player_days_since_prev_tournament / 7`
* **Calculation Details:**

  * Direct transformation of days metric for easier interpretation
  * Maintains same temporal integrity and seeding logic


[⬆ Index](#index)

---
<a id="surface"></a>
# Surface Specialization

### `opponent_favourite_surface`

* **Description:** Binary flag indicating if current surface matches opponent's long-run best-performing surface.
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = current surface = opponent's argmax surface by win rate
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_favourite_surface
  * *Typical Values:* 0 (53.68%), 1 (46.32%)
  * *Notes:* Same distribution pattern as player's favourite surface flag
* **Source/Calculation:** Determined by comparing current surface to opponent's highest win-rate surface

### `opponent_surface_specialization`

* **Description:** Difference between opponent's surface Elo and general Elo (opponent_elo_surface_pre − opponent_elo_pre).
* **Data Type:** Float
* **Unit/Domain:** Elo points [-1102.65, 414.72]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_surface_specialization
  * *Typical Values:* Median: -142.54, Mean: -160.89
  * *Notes:* Same negative bias pattern as player specialization
* **Source/Calculation:** Calculated as opponent_elo_surface_pre − opponent_elo_pre
* **Interpretation:**

  * **POSITIVE:** Opponent performs better on this surface than their general level
  * **NEGATIVE:** Opponent performs worse on this surface than their general level

### `opponent_win_rate_surface_progressive`

* **Description:** Opponent's pre-match progressive win rate on current surface (seeded with pre-1999 data).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (3.1% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Identical distribution to player_win_rate_surface_progressive
  * *Typical Values:* Median: 0.531, Mean: 0.513
  * *Notes:* Same distribution pattern as player's surface win rate
* **Source/Calculation:** Vectorially computed win rate using pre-1999 seeds + cumulative wins/matches up to current match
* **Calculation Details:**

  * Same methodology as player version but from opponent's perspective
  * Maintains strict anti-leakage guarantees through chronological ordering

### `player_favourite_surface`

* **Description:** Binary flag indicating if current surface matches player's long-run best-performing surface.
* **Data Type:** Binary (0/1)
* **Unit/Domain:** {0, 1} where 1 = current surface = player's argmax surface by win rate
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Snapshot at match
* **Range/Values & Outlier Notes:**

  * *Observed Range:* 0 (53.68%), 1 (46.32%)
  * *Typical Values:* Slightly more players are NOT on their favourite surface
  * *Notes:* Based on long-run historical win rates across all surfaces in career
* **Source/Calculation:** Determined by comparing current surface to player's highest win-rate surface using combined pre-1999 and 1999-2025 data

### `player_surface_specialization`

* **Description:** Difference between player's surface Elo and general Elo (player_elo_surface_pre − player_elo_pre).
* **Data Type:** Float
* **Unit/Domain:** Elo points [-1102.65, 414.72]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -1102.65, Max: 414.72, P99: 68.01
  * *Typical Values:* Median: -142.54, Mean: -160.89
  * *Notes:* Strong negative bias indicates most players have lower surface Elo than general Elo; 75% of players have negative specialization
* **Source/Calculation:** Calculated as player_elo_surface_pre − player_elo_pre
* **Interpretation:**

  * **POSITIVE:** Player performs better on this surface than their general level
  * **NEGATIVE:** Player performs worse on this surface than their general level
  * **ZERO:** No surface specialization effect

### `player_win_rate_surface_progressive`

* **Description:** Player's pre-match progressive win rate on current surface (seeded with pre-1999 data).
* **Data Type:** Float
* **Unit/Domain:** Proportion [0, 1]
* **Missingness Policy:** Rarely missing (3.1% NAs)
* **Temporal Semantics:** Progressive average (up to t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: 0, Max: 1, P99: 1.0
  * *Typical Values:* Median: 0.531, Mean: 0.513
  * *Notes:* Distribution centers around 0.5; 95% of players have surface win rate ≤0.690
* **Source/Calculation:** Vectorially computed win rate using pre-1999 seeds + cumulative wins/matches up to current match
* **Calculation Details:**

  * Uses strict chronological ordering to prevent data leakage
  * Pre-1999 data (1968-1998) serves as Bayesian prior for players who turned pro before 1999
  * Formula: `(seed_wins + cumulative_wins_before) / (seed_matches + cumulative_matches_before)`

### `surface_specialization_diff`

* **Description:** Difference in surface specialization between player and opponent (player − opponent).
* **Data Type:** Float
* **Unit/Domain:** Elo points [-808.95, 808.95]
* **Missingness Policy:** Never missing (0% NAs)
* **Temporal Semantics:** Pre-match calculation (t-1)
* **Range/Values & Outlier Notes:**

  * *Observed Range:* Min: -808.95, Max: 808.95, P99: 305.40
  * *Typical Values:* Median: 0, Mean: 0 (perfectly symmetric)
  * *Notes:* Distribution centered at 0; 95% of matches have specialization differences within ±188.74 points
* **Source/Calculation:** Calculated as player_surface_specialization − opponent_surface_specialization
* **Interpretation:**

  * **POSITIVE:** Player has relative surface advantage over opponent
  * **NEGATIVE:** Opponent has relative surface advantage over player
  * **ZERO:** No relative surface advantage

[⬆ Index](#index)

---

<a id="target"></a>
## Target Variable

### `match_result`

*   **Description:** Target variable indicating whether the player won (1) or lost (0) the match
*   **Data Type:** Integer (binary)
*   **Unit/Domain:** Binary [0, 1]
*   **Missingness Policy:** Minimal missing (0% NAs) - only 2 missing observations in entire dataset
*   **Temporal Semantics:** Match outcome (current match at time t)
*   **Range/Values & Outlier Notes:**
    *   *Observed Values:* 0 (loss), 1 (win)
    *   *Typical Values:* Perfectly balanced distribution - 50% wins, 50% losses
    *   *Notes:* No outliers or extreme values; clean binary classification target
*   **Source/Calculation:** Direct match outcome recording
*   **Target Role:** Primary prediction variable for match outcome classification models

[⬆ Index](#index)

---

<a id="titles"></a>
## Titles & Prestige

### `opponent_prestigious_non_gs_titles`

*   **Description:** Count of non-Grand Slam prestigious titles won by opponent
*   **Data Type:** Integer
*   **Unit/Domain:** Title count [0, 83]
*   **Missingness Policy:** Never missing (0% NAs)
*   **Temporal Semantics:** Cumulative count up to current match (progressive)
*   **Range/Values & Outlier Notes:**
    *   *Observed Range:* Identical distribution to player_prestigious_non_gs_titles
    *   *Typical Values:* Median: 0, Mean: 1.262
    *   *Notes:* Same extremely right-skewed distribution as player version
*   **Source/Calculation:** `opponent_prestigious_titles - opponent_gs_titles`
*   **Calculation Details:**
    *   Same calculation methodology as player version
    *   **Strategic Value:** Helps identify opponents with significant tournament success outside majors
    
### `player_prestigious_non_gs_titles`

*   **Description:** Count of non-Grand Slam prestigious titles won by player (Masters 1000/ATP Finals/Olympics)
*   **Data Type:** Integer
*   **Unit/Domain:** Title count [0, 83]
*   **Missingness Policy:** Never missing (0% NAs)
*   **Temporal Semantics:** Cumulative count up to current match (progressive)
*   **Range/Values & Outlier Notes:**
    *   *Observed Range:* Min: 0, Max: 83, P99: 21
    *   *Typical Values:* Median: 0, Mean: 1.262
    *   *Notes:* Extremely right-skewed; 75% of players have 0 non-GS prestigious titles
*   **Source/Calculation:** `player_prestigious_titles - player_gs_titles`
*   **Calculation Details:**
    *   **Definition:** Excludes Grand Slam titles from total prestigious titles count
    *   **Tournament Types:** Masters 1000, ATP Finals, Olympic gold medals
    *   **Distribution Insight:** Only 5% of players have 7+ non-GS prestigious titles
    
[⬆ Index](#index)

---
