# ATP Match Outcome Prediction — **a curated, long-horizon dataset** + a calibrated baseline that outperforms strong controls

> **Tagline:** *End‑to‑end ETL + scalable feature engineering + calibrated XGBoost with transparent validation. Built for reproducibility. Designed for sports analytics.*

---

## ✨ What is this?

This repository brings together the **entire workflow** to predict ATP match outcomes:
**scraping → parsing → SQL staging → ETL/feature engineering → year‑wise validation → calibration → hold‑out evaluation** and, most importantly, a **curated longitudinal dataset** that’s the project’s **crown jewel**.

You get two deliverables:

1. **A rich, long‑horizon dataset** (the *jewel*): All ATP History coverage (depends on your environment), with **real competitive context** features (rest, travel, adaptation to surface & indoor, prior load) for **both players**.
2. **A calibrated XGBoost model** that outputs realistic win probabilities and strong out‑of‑sample metrics.

If you work in **sports analytics**, **quantitative sports trading**, **scouting**, or **ML R&D for sports**, this repo offers **production‑grade building blocks** backed by **high‑quality data**.

---

## 🔑 Why this project stands out

* **Serious, reproducible ETL.** Temporal ordering is enforced, leakage is avoided, and the unit of analysis (match–player) is consistent across time.
* **Unique “fatigue & adaptation” features** (for both player roles):

  * Days/weeks since previous tournament.
  * Discrete signals: *back‑to‑back*, *two‑weeks gap*, *long rest*.
  * Country / continent / surface / indoor–outdoor changes.
  * **Red‑eye risk** (intercontinental + consecutive week).
  * **Travel fatigue score** (composite).
* **Cold‑start pre‑1999** with historical seed (Jeff Sackmann): last seen date & tournament prior to 1999, and round normalization (**ER→R128**) for phase alignment.
* **NOTE:** We used pre-seeding with data from Jeff Sackman due to budget and hardware limitations. This is completely optional, and we strongly recommend that anyone who can extract all the data from the ATP website across all years do so and skip the pre-seeding.
* **Validation that mirrors reality**:

  * **Year‑wise cross‑validation (2000–2025)** with an **`id` guarantee** (both rows of a match stay together).
  * **OOF (2000–2022)** to train a **calibrated probability** model via isotonic regression.
  * **Hold‑out 2023–2025**, also broken down by tournament type.
* **Calibrated probabilities** + **cost‑optimal thresholding** for decision‑ready outputs.

---

## 📊​ Dataset description

This dataset is the result of applying the **Extract - Load - Transform** modules.
A **highly complete** dataset with **207 final variables**, including a drop of more than 30 features.
>The large number of features is offset by large-scale record extraction for the database. For more advanced projects,optimization or neural network implementations we recommend running a feature-importance analysis during XGBoost training to identify the most informative variables and dropping the rest in bulk.

**Conventions (applies to many fields):**

* **Unit of analysis:** one row = *(match, player)* (two rows per match `id`).
* **Anti-leakage:** all rolling/progressive stats are computed in strict time order and **exclude the current match**.
* **Dates:** rankings are taken **as of the day before** `tournament_start_dtm`.
* **Codes & units:** countries/citizenships in **ISO-3**; height **cm**, weight **kg**; surfaces = **Clay/Grass/Hard/Carpet**; indoor/outdoor = **“Indoor/Outdoor”**.
* **Grand Slams:** GS = the four majors only (no doubles).
* **Elo:** logistic win prob; `elo_diff` uses **general** Elo (player − opponent).
* **Log-ratios:** `log(player_avg+1e-6) − log(opponent_avg+1e-6)`.
* **KPIs with min history (N≥5)** before exposing averages: double faults, aces/match, service games won %, break-points saved/converted %, return games won %, total points won %, tie-breaks won %.

---

### Identifiers & match/tournament metadata (14)

* `surface`: court surface (Clay/Grass/Hard/Carpet).
* `stadie_id`: round code (Q1, Q2, Q3, BR, RR, R128, R64, R32, R16, QF, SF, F, 3P).
* `best_of`: best-of sets (GS=5; non-GS inferred from scores; fallback 3).
* `tournament_id`: tournament unique identifier.
* `id`: match identifier (shared by the two player rows).
* `year`: calendar year of the tournament.
* `match_order`: order **within the current round** (resets per `stadie_id`).
* `tournament_start_dtm`: tournament start date (YYYY-MM-DD).
* `tournament_category`: one of {atp250, atp500, 1000, gs, teamCup, gsCup, atpFinal, og, ch100, ch50, chFinal, laverCup, nextGen, atpCup}.
* `tournament_prize`: prize money as scraped (usually EUR/GBP; **not inflation-adjusted**).
* `tournament_country`: host country (ISO-3).
* `tournament_name`: tournament name string.
* `indoor_outdoor`: “Indoor” or “Outdoor”.
* `stadie_ord`: ordinal index of `stadie_id` (ordered factor).

### Identity & basic player info (26)

* `player_code`: player ID (focal row).
* `player_name`: player display name.
* `player_citizenship`: player country (ISO-3).
* `player_age`: player age at event.
* `player_seed`: tournament seed (0/NA = unseeded).
* `player_handedness`: Left/Right-handed.
* `player_backhand`: one-/two-handed backhand (or Unknown).
* `player_height`: player height (cm).
* `player_weight`: player weight (kg).
* `player_years_experience`: `year − turned_pro` (first Challenger/ATP appearance).
* `player_matches_won`: **career** wins up to this match (progressive).
* `player_win_rate`: **career** win rate up to this match (progressive).
* `player_gs_titles`: Grand Slam titles (singles only).
* `opponent_code`: opponent ID.
* `opponent_name`: opponent display name.
* `opponent_citizenship`: opponent country (ISO-3).
* `opponent_age`: opponent age at event.
* `opponent_seed`: opponent seed (0/NA = unseeded).
* `opponent_handedness`: Left/Right-handed.
* `opponent_backhand`: one-/two-handed (or Unknown).
* `opponent_height`: opponent height (cm).
* `opponent_weight`: opponent weight (kg).
* `opponent_years_experience`: `year − turned_pro` for opponent.
* `opponent_matches_won`: opponent **career** wins to date.
* `opponent_win_rate`: opponent **career** win rate to date.
* `opponent_gs_titles`: opponent GS titles.

### Home flags (2)

* `player_home`: 1 if `player_citizenship == tournament_country`, else 0.
* `opponent_home`: 1 if `opponent_citizenship == tournament_country`, else 0.

### Ranking & trajectory (18)

* `player_atp_ranking`: singles rank at **t−1 day** (rolling join ≤ start date).
* `opponent_atp_ranking`: opponent rank at **t−1 day**.
* `player_highest_atp_ranking`: historical best rank up to t.
* `opponent_highest_atp_ranking`: opponent best rank up to t.
* `player_rank_trend_4w_cat`: 4-week rank trend category {subida, estable, bajada} with **adaptive** threshold (~2% of max(rank_t, rank_t−4w), floor 1).
* `player_rank_trend_12w_cat`: 12-week category (threshold ~5%).
* `opponent_rank_trend_4w_cat`: as above for opponent (4w).
* `opponent_rank_trend_12w_cat`: as above for opponent (12w).
* `player_rank_trend_4w`: `rank(t−4w) − rank(t)` (positive = improving).
* `player_rank_trend_12w`: `rank(t−12w) − rank(t)`.
* `opponent_rank_trend_4w`: opponent 4-week trend.
* `opponent_rank_trend_12w`: opponent 12-week trend.
* `rank_diff_t`: `opponent_rank − player_rank` at t (positive = opponent worse).
* `trend_diff_4w`: opponent 4w trend − player 4w trend.
* `trend_diff_12w`: opponent 12w trend − player 12w trend.
* `log_rank_ratio_t`: `log(opponent_rank / player_rank)`.
* `log_player_dist_to_peak`: `log(rank_t) − log(best_rank_so_far)`.
* `log_opponent_dist_to_peak`: same for opponent.

### Surface specialization (7)

* `player_surface_specialization`: `player_elo_surface_pre − player_elo_pre` (surface vs general).
* `opponent_surface_specialization`: opponent analogue.
* `surface_specialization_diff`: player − opponent specialization.
* `player_favourite_surface`: 1 if match surface = player’s long-run argmax surface.
* `opponent_favourite_surface`: opponent analogue.
* `player_win_rate_surface_progressive`: player **pre-match** surface win rate (seeded by pre-1999).
* `opponent_win_rate_surface_progressive`: opponent analogue.

### Elo & probabilities (7)

* `elo_diff`: **general** Elo difference *(player − opponent)* pre-match.
* `player_elo_surface_pre`: player **surface** Elo pre-match.
* `opponent_elo_surface_pre`: opponent surface Elo pre-match.
* `player_win_prob_surface`: Elo-implied win prob on surface (pre-match).
* `player_win_prob_diff_general_vs_surface_cat`: {negative, neutral, positive} from `player_win_prob − player_win_prob_surface` with cuts (−∞, −0.2], (−0.2, 0.2], (0.2, ∞).
* `opponent_win_prob_diff_general_vs_surface_cat`: opponent analogue.
* `h2h_surface_vs_general_diff`: `player_h2h_surface_win_ratio − player_h2h_full_win_ratio` (smoothed).

### Recent form, consistency & in-tournament load (21)

* `player_win_ratio_last_5_matches`: rolling win rate last 5 (lagged).
* `player_win_ratio_last_10_matches`: rolling win rate last 10 (lagged).
* `opponent_win_ratio_last_5_matches`: opponent last 5 (lagged).
* `opponent_win_ratio_last_10_matches`: opponent last 10 (lagged).
* `momentum_diff_5`: player5 − opponent5.
* `momentum_diff_10`: player10 − opponent10.
* `player_trend`: player5 − player10 (positive = improving).
* `opponent_trend`: opponent5 − opponent10.
* `player_good_form_5`: 1 if player5 > 0.7 else 0.
* `player_good_form_10`: 1 if player10 > 0.7 else 0.
* `opponent_good_form_5`: 1 if opponent5 > 0.7 else 0.
* `opponent_good_form_10`: 1 if opponent10 > 0.7 else 0.
* `player_consistency`: |player5 − player10|.
* `opponent_consistency`: |opp5 − opp10|.
* `player_won_previous_tournament`: 1 if last tournament entered was won.
* `opponent_won_previous_tournament`: opponent analogue.
* `cumulative_sets`: **sets played including this match** within current tournament.
* `player_sets_played_tournament`: player sets played **before** this match in current tournament.
* `opponent_sets_played_tournament`: opponent analogue.
* `player_prev_matches`: player’s total prior matches up to t (exposure).
* `opponent_prev_matches`: opponent’s exposure count.

### Rest, schedule & travel (26)

* `player_days_since_prev_tournament`: days since player’s previous tournament (seeded with pre-1999 “last seen” if applicable).
* `player_weeks_since_prev_tournament`: weeks since previous tournament.
* `player_back_to_back_week`: ≤9 days gap flag.
* `player_two_weeks_gap`: 10–16 days gap flag.
* `player_long_rest`: ≥21 days gap flag.
* `player_country_changed`: country changed vs previous tournament.
* `player_surface_changed`: surface changed vs previous.
* `player_indoor_changed`: indoor/outdoor changed vs previous.
* `player_continent_changed`: continent changed vs previous.
* `player_red_eye_risk`: inter-continent **and** back-to-back.
* `player_travel_fatigue`: composite score (2×continent + 1×country + 1×surface + 0.5×indoor).
* `player_prev_tour_matches`: matches played in the **previous** tournament.
* `player_prev_tour_max_round`: furthest round reached in the **previous** tournament (aligned ladder).
* `opponent_days_since_prev_tournament`: opponent analogue.
* `opponent_weeks_since_prev_tournament`: opponent analogue.
* `opponent_back_to_back_week`: opponent analogue.
* `opponent_two_weeks_gap`: opponent analogue.
* `opponent_long_rest`: opponent analogue.
* `opponent_country_changed`: opponent analogue.
* `opponent_surface_changed`: opponent analogue.
* `opponent_indoor_changed`: opponent analogue.
* `opponent_continent_changed`: opponent analogue.
* `opponent_red_eye_risk`: opponent analogue.
* `opponent_travel_fatigue`: opponent analogue.
* `opponent_prev_tour_matches`: opponent analogue.
* `opponent_prev_tour_max_round`: opponent analogue.

### Head-to-Head (8)

* `player_h2h_full_win_ratio`: smoothed H2H win ratio (all counted events) up to t.
* `player_h2h_total_matches`: H2H sample size (all surfaces).
* `player_h2h_surface_win_ratio`: smoothed H2H win ratio on current surface.
* `player_h2h_surface_total_matches`: H2H sample size on current surface.
* `has_player_h2h_surface`: 1 if surface H2H available (>0 matches), else 0.
* `has_player_h2h_full`: 1 if any H2H available (>0 matches), else 0.
* `player_h2h_full_cred`: credibility 0..1 based on sample size vs prior.
* `player_h2h_surface_cred`: surface credibility 0..1.

### Play statistics (progressive averages) (18)

* `player_serve_1st_in_pct_avg`: % first serves in (lagged avg).
* `opponent_serve_1st_in_pct_avg`: opponent analogue.
* `player_serve_2nd_won_pct_avg`: % points won on **2nd serve** (lagged avg).
* `opponent_serve_2nd_won_pct_avg`: opponent analogue.
* `player_double_faults_pct_avg`: double faults / first-serve attempts (lagged avg, N≥5).
* `opponent_double_faults_pct_avg`: opponent analogue (N≥5).
* `player_aces_per_match_avg`: aces per match (lagged avg, N≥5).
* `opponent_aces_per_match_avg`: opponent analogue (N≥5).
* `player_service_games_won_pct_avg`: service games won % (lagged avg, N≥5).
* `opponent_service_games_won_pct_avg`: opponent analogue (N≥5).
* `player_break_points_saved_pct_avg`: % BP saved on serve (lagged avg, N≥5).
* `opponent_break_points_saved_pct_avg`: opponent analogue (N≥5).
* `player_return_games_won_pct_avg`: return games won % (lagged avg, N≥5).
* `opponent_return_games_won_pct_avg`: opponent analogue (N≥5).
* `player_break_points_converted_pct_avg`: % BP converted on return (lagged avg, N≥5).
* `opponent_break_points_converted_pct_avg`: opponent analogue (N≥5).
* `player_total_points_won_pct_avg`: total points won % (lagged avg, N≥5).
* `opponent_total_points_won_pct_avg`: opponent analogue (N≥5).

### Efficiencies & differentials (6)

* `player_serve_1st_efficiency`: `player_serve_1st_won_pct_avg / player_service_games_won_pct_avg`.
* `opponent_serve_1st_efficiency`: opponent analogue.
* `player_return_1st_efficiency`: `player_return_1st_won_pct_avg / player_return_games_won_pct_avg`.
* `opponent_return_1st_efficiency`: opponent analogue.
* `player_return_1st_vs_2nd_diff`: `return_1st_won_pct_avg − return_2nd_won_pct_avg`.
* `opponent_return_1st_vs_2nd_diff`: opponent analogue.

### Clutch & tie-break metrics (6)

* `player_clutch_bp_save_gap`: BP saved % − service games won % (serve pressure).
* `opponent_clutch_bp_save_gap`: opponent analogue.
* `player_clutch_bp_conv_gap`: BP converted % − return games won % (return pressure).
* `opponent_clutch_bp_conv_gap`: opponent analogue.
* `player_clutch_tiebreak_adj`: tie-breaks won % − total points won %.
* `opponent_clutch_tiebreak_adj`: opponent analogue.

### Log-ratios (player vs opponent) (11)

* `log_ratio_serve_1st_in_pct`: log-ratio of first-serve-in % (player vs opp).
* `log_ratio_serve_2nd_won_pct`: log-ratio of 2nd-serve points won %.
* `log_ratio_double_faults_pct`: log-ratio of DF rate.
* `log_ratio_aces_per_match`: log-ratio of aces per match.
* `log_ratio_service_games_won_pct`: log-ratio of service games won %.
* `log_ratio_break_points_saved_pct`: log-ratio of BP saved %.
* `log_ratio_return_2nd_won_pct`: log-ratio of return vs 2nd-serve points won %.
* `log_ratio_return_games_won_pct`: log-ratio of return games won %.
* `log_ratio_break_points_converted_pct`: log-ratio of BP converted %.
* `log_ratio_total_points_won_pct`: log-ratio of total points won %.
* `log_ratio_tiebreaks_won_pct`: log-ratio of tie-breaks won %.

### Titles & prestige (2)

* `player_prestigious_non_gs_titles`: count of **non-GS** “prestigious” titles (as defined in the pipeline; typically Masters 1000/ATP Finals/Olympics).
* `opponent_prestigious_non_gs_titles`: opponent analogue.

### Missingness indicators ( `_was_na` flags ) (34)

*(Binary flags: 1 if the named metric was **NA before smoothing/imputation**, else 0.)*

* `log_ratio_tiebreaks_won_pct_was_na`: NA-flag for `log_ratio_tiebreaks_won_pct`.
* `log_ratio_break_points_converted_pct_was_na`: NA-flag for `log_ratio_break_points_converted_pct`.
* `log_ratio_break_points_saved_pct_was_na`: NA-flag for `log_ratio_break_points_saved_pct`.
* `log_ratio_double_faults_pct_was_na`: NA-flag for `log_ratio_double_faults_pct`.
* `log_ratio_service_games_won_pct_was_na`: NA-flag for `log_ratio_service_games_won_pct`.
* `log_ratio_return_games_won_pct_was_na`: NA-flag for `log_ratio_return_games_won_pct`.
* `log_ratio_total_points_won_pct_was_na`: NA-flag for `log_ratio_total_points_won_pct`.
* `log_ratio_aces_per_match_was_na`: NA-flag for `log_ratio_aces_per_match`.
* `player_clutch_tiebreak_adj_was_na`: NA-flag for `player_clutch_tiebreak_adj`.
* `opponent_clutch_tiebreak_adj_was_na`: NA-flag for `opponent_clutch_tiebreak_adj`.
* `player_break_points_converted_pct_avg_was_na`: NA-flag for `player_break_points_converted_pct_avg`.
* `opponent_break_points_converted_pct_avg_was_na`: NA-flag for `opponent_break_points_converted_pct_avg`.
* `player_clutch_bp_conv_gap_was_na`: NA-flag for `player_clutch_bp_conv_gap`.
* `opponent_clutch_bp_conv_gap_was_na`: NA-flag for `opponent_clutch_bp_conv_gap`.
* `player_break_points_saved_pct_avg_was_na`: NA-flag for `player_break_points_saved_pct_avg`.
* `opponent_break_points_saved_pct_avg_was_na`: NA-flag for `opponent_break_points_saved_pct_avg`.
* `player_clutch_bp_save_gap_was_na`: NA-flag for `player_clutch_bp_save_gap`.
* `opponent_clutch_bp_save_gap_was_na`: NA-flag for `opponent_clutch_bp_save_gap`.
* `player_double_faults_pct_avg_was_na`: NA-flag for `player_double_faults_pct_avg`.
* `opponent_double_faults_pct_avg_was_na`: NA-flag for `opponent_double_faults_pct_avg`.
* `player_aces_per_match_avg_was_na`: NA-flag for `player_aces_per_match_avg`.
* `opponent_aces_per_match_avg_was_na`: NA-flag for `opponent_aces_per_match_avg`.
* `player_service_games_won_pct_avg_was_na`: NA-flag for `player_service_games_won_pct_avg`.
* `opponent_service_games_won_pct_avg_was_na`: NA-flag for `opponent_service_games_won_pct_avg`.
* `player_return_games_won_pct_avg_was_na`: NA-flag for `player_return_games_won_pct_avg`.
* `opponent_return_games_won_pct_avg_was_na`: NA-flag for `opponent_return_games_won_pct_avg`.
* `player_total_points_won_pct_avg_was_na`: NA-flag for `player_total_points_won_pct_avg`.
* `opponent_total_points_won_pct_avg_was_na`: NA-flag for `opponent_total_points_won_pct_avg`.
* `player_serve_1st_efficiency_was_na`: NA-flag for `player_serve_1st_efficiency`.
* `opponent_serve_1st_efficiency_was_na`: NA-flag for `opponent_serve_1st_efficiency`.
* `player_return_1st_efficiency_was_na`: NA-flag for `player_return_1st_efficiency`.
* `opponent_return_1st_efficiency_was_na`: NA-flag for `opponent_return_1st_efficiency`.
* `log_ratio_serve_1st_in_pct_was_na`: NA-flag for `log_ratio_serve_1st_in_pct`.
* `log_ratio_serve_2nd_won_pct_was_na`: NA-flag for `log_ratio_serve_2nd_won_pct`.

## Dropped variables
>The following features were dropped for redundancy reasons. It is up to the user to choose whether or not to keep them.

* `player_turned_pro`,`opponent_turned_pro`, `player_prestigious_titles`
* `opponent_prestigious_titles`, `player_total_matches`, `opponent_total_matches`
* `opponent_win_prob`, `opponent_win_prob_surface`, `player_win_prob_log_ratio`
* `opponent_win_prob_log_ratio`, `player_elo_pre`, `opponent_elo_pre`
* `player_consistency_log_ratio`, `opponent_consistency_log_ratio`, `consistency_log_ratio_diff`
* `player_surface_effect`, `opponent_surface_effect`, `player_serve_1st_won_pct_avg`
* `opponent_serve_1st_won_pct_avg`, `player_return_1st_won_pct_avg`, `player_return_2nd_won_pct_avg`
* `opponent_return_1st_won_pct_avg`, `opponent_return_2nd_won_pct_avg`, `player_win_prob`
* `player_tiebreaks_won_pct_avg`, `opponent_tiebreaks_won_pct_avg`, `log_ratio_return_1st_won_pct`
* `log_ratio_serve_1st_won_pct`


### Target variable (1)

* `match_result`: **0/1** label (1 = player win, 0 = loss). Walkovers/retirements follow match records; Elo updates handle RET/W.O. with adjusted K.

---

## 🏆 Results (executive summary)

> Figures come from the notebook with embedded outputs (`MODEL/model1.ipynb`) and are indicative for this data snapshot and setup.

* **Year‑wise CV 2000–2025** (26 folds, `id` leakage‑safe):
  **AUC ≈ 0.964 | LogLoss ≈ 0.224 | Brier ≈ 0.072 | Accuracy ≈ 0.89**
* **OOF 2000–2022** (for isotonic calibration):
  **AUC ≈ 0.972 | LogLoss ≈ 0.210 | Brier ≈ 0.068**
* **Hold‑out 2023–2025** (calibrated probabilities):
  **AUC ≈ 0.915 | LogLoss ≈ 0.379 | Brier ≈ 0.120 | Accuracy ≈ 0.821**

**Bottom line:** the system **generalizes** and the **probabilities are calibrated**—a must for risk‑aware decisioning.

---

## 🗂️ Repository structure (actual file names)

```
ATP-Match-Outcome-Prediction/
├─.env/
|  ├─.env.example
|  ├─Makefile
|  └─docker-compose.yml
|
|
├─ Data_Sample/
│  ├─Data_Sample.csv       # Tiny sample for quick inspection
|  ├─fechas_ex.txt
|  └─ info_fechas.txt                  
│
├─ ETL/
│  ├─ Extractor/
│  │  ├─ MatchesATPExtractor.py
│  │  ├─ MatchesBaseExtractor.py
│  │  ├─ PlayersATPExtractor.py
│  │  ├─ StatsATPExtractor.py
│  │  ├─ TournamentsATPExtractor.py
│  │  ├─ base_extractor.py
|  |  ├─ constants.py
│  │  └─ runner.py
│  │
│  ├─ Load/
│  │  └─ CreateData.R                 # R loader/assembler
│  │
│  └─ SQL/
│     ├─ Procedures&Functions/        # Stored procs & UDFs (sf_* / sp_*)
│     ├─ Tables/
│     │  └─ Staging/
|     |  |     ├─ stg_match_scores.sql
|     |  |     ├─ stg_match_stats.sql
|     |  |     ├─ stg_matches.sql
|     |  |     ├─ stg_players.sql
|     |  |     ├─ stg_teams.sql
|     |  |     └─ stg_tournaments.sql
│     │  ├─ atp_matches.sql
│     │  ├─ atp_matches_enriched.sql
│     │  ├─ atp_players.sql
│     │  ├─ atp_tournaments.sql
│     │  ├─ countries.sql
│     │  ├─ indoor_outdoor.sql
│     │  ├─ match_scores_adjustments.sql
│     │  ├─ player_points.sql
│     │  ├─ points_rulebook.sql
│     │  ├─ points_rules.sql
│     │  ├─ series.sql
│     │  ├─ series_category.sql
│     │  ├─ stadies.sql            # (kept as‑is)
│     │  └─ surfaces.sql
│     └─ views/
│        ├─ vw_atp_matches.sql
│        └─ vw_player_stats.sql
│
├─ Transform/
│  ├─ Ranking Scraping/
│  │  ├─ Ranking_scraping.py         # Headless HTML fetch from atptour.com
│  │  ├─ rankings_to_csv.py           # BeautifulSoup → per‑date rankings CSV
│  ├─ DataTransform1.R
│  ├─ DataTransform2.R
│  ├─ DataTransform3.R
│  ├─ DataTransform4.R
│  ├─ DataTransform5_1.R
│  ├─ DataTransform6.R
│  ├─ DataTransform6_1.R
│  ├─ DataTransform7.R
│  ├─ DataTransform8.R
│  ├─ DataTransform9.R
│  ├─ DataTransform10.R
│  ├─ DataTransform11.R
│  ├─ DataTransform12.R
|  ├─ DataTransformFinal.R
│  ├─ readme.txt
└─ transform_info.txt
│
├─ MODEL/
│  └─ model1.ipynb                    # CV by year, OOF calibration, hold‑out 2023–2025
│
├─ LICENSE
├─ README.md
└─ requirements.txt
```

> **Note on dates file**: the rankings fetcher uses `fechas.txt` populated directly from ATP HTML. Example lines present in that file (as found in source pages):
> `<option value="2025-09-22">2025.09.22</option>`
> `<option value="2025-09-15">2025.09.15</option>`
> …the **`value`** field is parsed as `YYYY-mm-dd`.

---

## 🧪 Pipeline at a glance

```
  A[Ranking_scraping.py (headless)] --> B[raw HTML (.txt per date)]
  B --> C[rankings_to_csv.py (BeautifulSoup)]
  C --> D[SQL Staging (Tables/ Staging/)]
  D --> E[Procedures & Functions (sf_*/sp_*)]
  E --> F[Views (vw_atp_matches, vw_player_stats)]

  %% Python ETL extractors run AFTER SQL creation (all run by runner.py)
  F --> X1[ETL/Extractor/TournamentsATPExtractor.py]
  X1 --> X2[ETL/Extractor/PlayersATPExtractor.py]
  X2 --> X3[ETL/Extractor/MatchesATPExtractor.py]
  X3 --> X4[ETL/Extractor/StatsATPExtractor.py]

  X4 --> G[CreateData.R & DataTransform*.R]
  G --> H[Final enriched dataset]
  H --> I[MODEL/model1.ipynb — XGBoost]
  I --> J[CV by year + OOF calibration + hold‑out]
```

### 1) Scraping & Parsing

**A. Core HTML Extractors (Python)**
Located in `ETL/Extractor/`, these modules perform the **primary data extraction from ATP web pages (HTML scraping)** and normalize outputs for staging:

* `ETL/Extractor/base_extractor.py` & `ETL/Extractor/constants.py` — shared session, headers, retries/backoff, helpers, and constants (URLs, paths, regexes). Designed for polite scraping.
* `ETL/Extractor/MatchesATPExtractor.py` — crawls & parses match pages/feeds and prepares match-level records.
* `ETL/Extractor/PlayersATPExtractor.py` — extracts player pages (bio/handedness/backhand, country, etc.).
* `ETL/Extractor/TournamentsATPExtractor.py` — pulls tournament metadata (location, surface, category, indoor/outdoor).
* `ETL/Extractor/StatsATPExtractor.py` — scrapes stats blocks where available and aligns them to match IDs/players.

> **Notes:** Extractors follow a "fetch → parse (BeautifulSoup) → normalize" pattern. Raw HTML/JSON can be cached locally to make runs reproducible and to minimize load on the origin.

**B. Rankings Scrapers (headless) + Parser**

* `Transform/Ranking Scraping/Ranking_scraping.py` — downloads **official ATP rankings HTML** in **headless mode** and stores full HTML as text (`rankings_YYYY-mm-dd.txt`).
  *This design is deliberate:* saving raw HTML first makes the pipeline **finite and reproducible**; you can re‑parse locally without revisiting the site.
* `Transform/Ranking Scraping/rankings_to_csv.py` — parses those files and extracts **`ranking`** and **`player_code`** per date (robust to absolute/relative URLs and locale prefixes like `/es/`, `/en/`).

---

### 2) SQL Staging & Business Logic

* **Tables** under `ETL/SQL/Tables/Staging/` define the staging schema: `atp_matches.sql`, `atp_matches_enriched.sql`, `atp_players.sql`, `atp_tournaments.sql`, `points_rulebook.sql`, `surfaces.sql`, etc.
* **Procedures & functions** under `ETL/SQL/Procedures&Functions/` (files beginning with `sf_` / `sp_`) implement:

  * Delta and hash logic for incremental loads (`*_delta_hash.sql`).
  * Player points rules application & enrichment (`sp_apply_points_rules.sql`, `sp_calculate_player_points.sql`, `sp_enrich_atp_matches.sql`).
  * Merge/processing orchestration for matches, players, tournaments (e.g., `sp_merge_atp_players.sql`, `sp_process_atp_matches.sql`).
* **Views** in `ETL/SQL/views/` expose analytics‑ready joins: `vw_atp_matches.sql`, `vw_player_stats.sql`.

---

### 3) Load / Feature Engineering (R)

* `ETL/Load/CreateData.R` and the series of `Transform/DataTransform*.R` scripts stitch everything into a **match–player** panel.
* Feature highlights (mirrored for `player_*` and `opponent_*`):

  * **Rest & load:** `*_days_since_prev_tournament`, `*_weeks_since_prev_tournament`, `*_prev_tour_matches`.
  * **Adaptation flags:** `*_country_changed`, `*_continent_changed`, `*_surface_changed`, `*_indoor_changed`.
  * **Fatigue proxies:** `*_back_to_back_week`, `*_two_weeks_gap`, `*_long_rest`, `*_red_eye_risk`, `*_travel_fatigue`.

---

### 4) Modeling (Python, Jupyter)

* `MODEL/model1.ipynb` implements:

  * `ColumnTransformer` (sparse **One‑Hot** for categoricals, numeric coercion to `float32`).
  * **XGBoost** (`tree_method=hist`) with early stopping.
  * **CV by year (2000–2025)** with **`id` grouping** (both rows of a match stay together).
  * **OOF 2000–2022** for **isotonic calibration**.
  * **Hold‑out 2023–2025** with breakdowns by tournament type and a **cost‑optimal threshold** utility.

---

# 🚀 Quickstart

> Assumes **Python 3.10+**, **R 4.2+**, and isolated envs (conda/venv).

---

## 1) Clone

```bash
git clone https://github.com/Aitor-Quint-04/ATP-Match-Outcome-Prediction.git
cd ATP-Match-Outcome-Prediction
```

## 2) Install Python deps 

```bash
python -m pip install -U pandas numpy scipy scikit-learn xgboost beautifulsoup4 lxml selenium
# Optional: easy driver management
python -m pip install -U webdriver-manager
```

## 3) Fetch rankings HTML & parse

```bash
python "Transform/Ranking Scraping/Ranking_scraping.py"
python "Transform/Ranking Scraping/rankings_to_csv.py"
```

## 4) Create staging & run SQL logic

Load the scripts in this order:

1. `ETL/SQL/Tables/Staging/` (tables)
2. `ETL/SQL/Procedures&Functions/` (procedures/functions)
3. `ETL/SQL/views/` (views)

## 5) Run Python ETL extractors (in order)

> Run from the repo root so relative imports/config resolve correctly.

```bash
#Order to run:
# 1) Tournaments
# 2) Players
# 3) Matches
# 4) Stats

python "ETL/Extractor/runner.py" tournaments --year {year}

python "ETL/Extractor/runner.py" players --year {year}

python "ETL/Extractor/runner.py" matches --year {year}

python "ETL/Extractor/runner.py" stats --year {year}

#run all together:

python "ETL/Extractor/runner.py" all --year {year}

```

## 6) Assemble features (R)

```r
# In R
source("ETL/Load/CreateData.R")
```
All transformation scripts live in **`Transform/`** and are designed to run **sequentially**. They progressively build the final **match–player panel** (two rows per match) with mirrored `player_*` / `opponent_*` context.

> Required packages (typical): `data.table`, `dplyr`, `readr`, `stringr`, `lubridate`, `tidyr`, `purrr`,`progress`,`roll`,`zoo`. Install as needed.
`
**Script responsibilities (by file):**

**(read the codes doc)**

1. **`DataTransform1.R`** – Base normalization

   * Coerce types, standardize column names, parse `tournament_start_dtm`, rounds and match order.
   * Normalize keys and fix minor inconsistencies.
  
     **...**

2. **`DataTransform3.R`** – Geography & context

   * Country → continent mapping; indoor/outdoor normalization.
   * Surface harmonization (clay/hard/grass); stadium metadata if required.

     **...**

3. **`DataTransform5.R`** – Rankings join

   * Merge per‑date rankings (from scraping) into matches by player and date.
   * Create ranking trend features (e.g., 4w/12w deltas if available).
  
     **...**

15. **`DataTransformFINAL.R`** 

    * Write the long‑horizon enriched dataset (e.g., `database_99-25_1.csv`).
    * Bayesian Smooth
    * Correlation analysis

> Notes
>
> * `ETL/Load/CreateData.R` can orchestrate or prepare inputs.
> * Intermediate artifacts (if any) are written under your configured output directory.

### One‑shot runner for all R transforms

Use this snippet to execute the transforms **in the right order** (explicitly lists `5_1` and `6_1` to avoid alphanumeric sorting issues):

```r
# ---- packages (install if needed) ----
req <- c("data.table","dplyr","readr","stringr","lubridate","tidyr","purrr","zoo","progress","roll")
new <- setdiff(req, rownames(installed.packages()))
if (length(new)) install.packages(new)
invisible(lapply(req, library, character.only = TRUE))

# ---- paths ----
ROOT <- getwd()  # run from repo root
file.path <- ""
SCRIPTS <- file.path

order <- c(
  "Transform/DataTransform1.R",
  "Transform/DataTransform2.R",
  "Transform/DataTransform3.R",
  "Transform/DataTransform4.R",
  "Transform/DataTransform5.R",
  "Transform/DataTransform5_1.R",
  "Transform/DataTransform6.R",
  "Transform/DataTransform6_1.R",
  "Transform/DataTransform7.R",
  "Transform/DataTransform8.R",
  "Transform/DataTransform9.R",
  "Transform/DataTransform10.R",
  "Transform/DataTransform11.R",
  "Transform/DataTransform12.R",
  "Transform/DataTransformFinal.R"
)

for (s in order) {
  cat(sprintf("\n>>> Running: %s\n", s))
  source(s, echo = TRUE, max.deparse.length = Inf)
}

cat("\nAll transforms finished. Check the exported dataset (e.g., database_99-25_1.csv).\n")
```

---

## 7) Model

Open **`MODEL/model1.ipynb`** and run all cells to reproduce: **CV by year**, **OOF calibration**, and **hold‑out 2023–2025**.

> A tiny sample lives in `Data_Sample/Data_Sample.csv` for quick sanity checks.

---

## 🧰 Practical tips

* **Separate download & parsing**: save HTML once, parse many times—faster and kinder to the origin.
* **Avoid leakage**: never fit the preprocessor on validation folds; the notebook uses per‑fold clones.
* **Use the cost‑optimal threshold**: when decisions carry asymmetric costs, tune `cost_fp`/`cost_fn` and deploy `thr*`.

---

## ⚠️ Data & ethics

* **Scraping** must follow the source site’s **Terms of Use**, **robots.txt**, and reasonable rate limits.
* This repo is for **research/educational** purposes. You’re responsible for compliance and downstream use.
* **Not betting advice.** If you operate in betting contexts, understand legal constraints, risk management, and calibration needs.

---

## 🗺️ Roadmap

* [ ] Export the **final dataset** in partitioned Parquet with a full **data dictionary**.
* [ ] Minimal **feature store** (ETL versioning + artifact registry).
* [ ] Additional baselines (Logistic, CatBoost, LightGBM) + **ensembles**.
* [ ] Drift monitoring by season and tournament type.
* [ ] Lightweight API for serving **calibrated probabilities** in real time.

---

## 🤝 Contributing

Ideas, PRs and issues are very welcome! If you propose new features, please **motivate the sports mechanism** you’re capturing and include **out‑of‑sample evidence**.

---

## 📄 License

Code under a permissive open license (see `LICENSE`).
Please also review the terms that apply to any **source data** you use.

---

## 🎯 TL;DR

This project combines **robust ETL**, **context‑rich competitive features**, and a **calibrated XGBoost** with metrics that **generalize**.
The **dataset is the very important thing in this project**: deep, consistent and ready to power serious **sports analytics**—from research to production.
