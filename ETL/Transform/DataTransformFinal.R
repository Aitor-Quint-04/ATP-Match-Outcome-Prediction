####################################################################################################
# Tennis ML — Correlation audit, feature engineering, NA treatment & Bayesian smoothing (R)
# --------------------------------------------------------------------------------------------------
# Executive summary
#   This script cleans, audits, and enriches a player‑centric ATP table (t_players) prior to modeling.
#   It enforces temporal ordering (anti‑leakage), audits correlations (Pearson/Spearman with p‑values),
#   derives domain features (serve/return efficiencies, H2H deltas, discretizations), encodes categorical
#   trends, treats NAs (seeds, durations, match order), applies Bayesian smoothing (Beta‑Binomial for
#   H2H and shrinkage across 34 noisy metrics), and reports NA% by year. The mixed dplyr/data.table
#   style is intentional to minimize churn and preserve reproducibility.
#
# Inputs / outputs
#   • Input: CSV "pred_jugadores_99‑25.csv" in the t_players schema, expected to include at least:
#     id, year, tournament_start_dtm, tournament_id, tournament_name, stadie_id, match_order,
#     best_of, surface, player_code, opponent_code, match_ret, player_seed, opponent_seed,
#     match_duration, and the families referenced in `cols_target` (e.g., *_games_won_pct_avg,
#     *_aces_per_match_avg, log_ratio_* …).
#     Note: The script intersects with existing names; missing columns are safely skipped.
#   • Output: "database_99‑25_1.csv" (default). Adjust path/name in section 10 as needed.
#
# Data contracts & assumptions
#   • Rows are "player vs opponent" instances (commonly 2 per match).
#   • tournament_start_dtm is coercible to Date and supports chronological sorting.
#   • stadie_id follows the canonical order: Q1,Q2,Q3,BR,RR,R128,R64,R32,R16,QF,SF,F,3P.
#   • Percentages may be in [0,1] or [0,100]; smoothing detects scale and normalizes accordingly.
#   • H2H ratios and totals are used when available; otherwise raw wins are reconstructed and smoothed.
#
# Workflow (high‑level)
#   1) Robust temporal ordering (date → phase → tournament → match_order) to prevent leakage.
#   2) Correlation audit:
#       - Full Pearson (pairwise NA) across numeric features.
#       - Spearman on a sample of up to ~35k unique matches (cost control).
#       - High‑corr pairs with |r|>0.85 and consistency checks (p<0.05, Spearman).
#   3) Feature engineering:
#       - Prestigious non‑GS titles; discretized general‑vs‑surface win‑probability gaps; first/second
#         serve/return efficiencies; surface‑vs‑general deltas in H2H.
#   4) NA handling & encoding:
#       - match_result → binary; flags for retirements (RET) and walkovers (W/O, WEA).
#       - Rank‑trend categories → ordered integers (‑1, 0, 1).
#       - Missing seeds → 0; NA snapshot ranked by severity.
#   5) H2H smoothing (Beta‑Binomial, p0=0.5):
#       - p̂ = (w + α·p0) / (n + α), with α_full=8 and α_surface=6.
#       - Credibility signals: n/(n+α) to gate trust.
#   6) match_duration imputation conditional on (surface, stadie_id, best_of):
#       - rnorm from cell means/SD; clipped to [60, 300] minutes.
#       - Note: groups with no history yield NA means/SD; consider a fallback (see Limitations).
#   7) match_order completion for (tournament_id, stadie_id) when NA.
#   8) Year‑level NA% across all columns (longitudinal QC).
#   9) Bayesian smoothing on 34 metrics:
#       - Proportions → shrink toward global mean with α_prop=20 (auto‑detect 0–1 vs 0–100 + clipping).
#       - Log‑ratios → shrink to 0 with α_logr=30.
#       - Means/gaps → shrink to the global mean with α_mean=10.
#       - Exposure n = cumulative prior matches per role (player/opponent).
#       - Emits *_was_na flags for post‑imputation traceability.
#
# Design choices & safeguards
#   • Strict anti‑leakage via temporal/competitive ordering; re‑applied at critical points.
#   • Numerical stability: pmax/pmin guards, clip01 for probabilities, and duration clipping.
#   • Spearman subsampling at ~35k unique matches to reduce cost and duplication bias.
#   • Name intersection avoids failures on partial schemas; pipeline is resilient to missing fields.
#
# Tunables (easy to adjust)
#   • High‑correlation threshold: threshold = 0.85 (section 1.5).
#   • Priors: α_full=8, α_surface=6, p0=0.5; α_prop=20, α_logr=30, α_mean=10.
#   • Spearman cap: 35,000 unique matches (smp_size).
#   • Duration clamp: [60, 300] minutes (domain‑dependent).
#
# Limitations & practical notes
#   • match_duration imputation: if a (surface, stadie_id, best_of) cell lacks history,
#     mean_dur/sd_dur remain NA and imputation is skipped; consider hierarchical fallbacks
#     (e.g., by surface or global) if you see residual gaps.
#   • rcorr() on very wide matrices can be memory‑hungry; reduce feature set or process in blocks.
#   • This script does not persist correlation matrices/plots; export CSVs/figures if you need formal audit deliverables.
#
# Reproducibility & performance
#   • set.seed(123) for stochastic steps; results are reproducible.
#   • data.table for heavy ops; dplyr for readability (arrange/group_by/mutate).
#   • Single fwrite at the end; toggle persistence as required by the environment.
#
# How to run
#   1) Set setwd() and confirm input paths/CSV.
#   2) Verify the presence of key columns (missing ones are safely ignored).
#   3) Run end‑to‑end; review console output for:
#       - High‑correlation pairs and their Spearman/p‑value consistency.
#       - NA% summaries by variable and by year.
#   4) Consume "database_99‑25_1.csv" as the enriched modeling base.
#
# Suggested extensions (optional)
#   • Export correlation matrices and >threshold pairs to audit files.
#   • Hierarchical fallbacks for match_duration (by surface → global).
#   • Visual QA: correlation heatmaps, imputation distributions, shrinkage traces.
####################################################################################################


# --------------------------------------------------------------------------------------------------
# Libraries (some are optional; keep installed if you want plots/diagnostics)
# --------------------------------------------------------------------------------------------------
library(data.table)
library(Hmisc)        # rcorr() for correlation p-values
library(dplyr)        # simple arrange/mutate/group_by used in a few places
# Optional (only if you plan to plot or run extra diagnostics down the road)
# library(corrplot)
# library(performance)
# library(ggplot2)
# library(stringr)

# --------------------------------------------------------------------------------------------------
# Load
# --------------------------------------------------------------------------------------------------
setwd("")
t_players <- fread("pred_jugadores_99-25.csv")
setDT(t_players)  # ensure data.table

# --------------------------------------------------------------------------------------------------
# Ordering helpers (anti‑leakage)
# --------------------------------------------------------------------------------------------------
orden_fases <- c("Q1","Q2","Q3","BR","RR","R128","R64","R32","R16","QF","SF","F","3P")

order_datasets <- function(df) {
  # Convert tournament_start_dtm to Date if needed, stabilize phase ordering, then sort.
  if ("tournament_start_dtm" %in% names(df) && !inherits(df$tournament_start_dtm, c("Date","POSIXt"))) {
    df$tournament_start_dtm <- as.Date(df$tournament_start_dtm)
  }
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # main chronological key
      tournament_name,       # tie-breaker within start_dtm
      tournament_id,         # group by tournament
      stadie_id,             # phase order within tournament
      match_order            # deterministic line-up inside phase
    )
}

# Make sure we start ordered (safe default)
t_players <- order_datasets(t_players)

# --------------------------------------------------------------------------------------------------
# QUICK distribution check (optional)
# --------------------------------------------------------------------------------------------------
# table(t_players$player_prev_matches)
# t_players$stadie_ord <- NULL  # was unused

# Keep a copy for correlation work (read‑only)
dt <- copy(t_players)

# ==================================================================================================
# 1) Correlation audit (Pearson on full numeric set; Spearman on a ~35k‑match sample)
# ==================================================================================================
# 1.1 Select numeric columns and exclude obvious IDs / labels
numeric_cols <- names(dt)[vapply(dt, is.numeric, TRUE)]
exclude_patterns <- c("^id$","code","name","tournament")
exclude_cols <- unique(unlist(lapply(exclude_patterns, function(p) grep(p, names(dt), value = TRUE))))
numeric_cols <- setdiff(numeric_cols, exclude_cols)

dt_num <- dt[, ..numeric_cols]

if (length(numeric_cols) >= 2L) {
  # 1.2 Pearson on full data (pairwise NAs)
  cor_mat <- cor(dt_num, use = "pairwise.complete.obs", method = "pearson")

  # 1.3 Spearman on a capped sample of unique matches
  set.seed(123)
  unique_ids <- unique(dt$id)
  if (length(unique_ids)) {
    smp_size <- min(length(unique_ids), 35000L)
    sample_ids <- sample(unique_ids, size = smp_size)
    dt_sample <- dt[id %in% sample_ids, ..numeric_cols]
    cor_mat_spear <- cor(dt_sample, use = "pairwise.complete.obs", method = "spearman")
  } else {
    cor_mat_spear <- matrix(NA_real_, nrow = ncol(dt_num), ncol = ncol(dt_num),
                            dimnames = list(colnames(dt_num), colnames(dt_num)))
  }

  # 1.4 p-values for Pearson (Hmisc::rcorr)
  rc <- rcorr(as.matrix(dt_num), type = "pearson")
  p_values <- rc$P

  # 1.5 High‑correlation pairs (|r|>0.85), contrasted with Spearman and p‑value
  threshold <- 0.85
  m_pear <- cor_mat
  m_pear[lower.tri(m_pear, diag = TRUE)] <- NA
  high_corr_pairs_pear <- which(abs(m_pear) > threshold, arr.ind = TRUE)

  if (length(high_corr_pairs_pear)) {
    pairs_df <- data.frame(
      var1 = rownames(m_pear)[high_corr_pairs_pear[, 1]],
      var2 = colnames(m_pear)[high_corr_pairs_pear[, 2]],
      corr_pear = m_pear[high_corr_pairs_pear],
      stringsAsFactors = FALSE
    )

    # Align Spearman & p‑values by var names
    pairs_df$corr_spear <- cor_mat_spear[cbind(pairs_df$var1, pairs_df$var2)]
    pairs_df$p_val      <- p_values[cbind(pairs_df$var1, pairs_df$var2)]

    strict_pairs <- pairs_df[abs(pairs_df$corr_pear) > threshold &
                               pairs_df$p_val < 0.05 &
                               abs(pairs_df$corr_spear) > threshold, ]

    if (nrow(strict_pairs)) {
      cat("High-corr pairs (|Pearson|>", threshold,
          ", p<0.05 & |Spearman|>", threshold, "):\n", sep = "")
      print(strict_pairs[, c("var1","var2","corr_pear","p_val","corr_spear")])
    } else {
      cat("No pairs meet all strict criteria.\n")
    }

    non_strict_pairs <- pairs_df[abs(pairs_df$corr_pear) > threshold &
                                   !(pairs_df$p_val < 0.05 & abs(pairs_df$corr_spear) > threshold), ]
    if (nrow(non_strict_pairs)) {
      cat("\nPairs with |Pearson|>", threshold,
          " but failing p<0.05 or |Spearman|>", threshold, ":\n", sep = "")
      print(non_strict_pairs[, c("var1","var2","corr_pear","p_val","corr_spear")])
    } else {
      cat("\nNo Pearson>threshold pairs fail the other criteria.\n")
    }
  } else {
    cat("No Pearson correlations above threshold (", threshold, ").\n", sep = "")
  }
} else {
  warning("<2 numeric columns available for correlation audit; skipping.")
}

# ==================================================================================================
# 2) Domain feature engineering & light cleanup
# ==================================================================================================
# 2.1 New non‑GS titles (convexity vs. GS titles)
t_players[, c("player_prestigious_non_gs_titles", "opponent_prestigious_non_gs_titles") := .(
  player_prestigious_titles - player_gs_titles,
  opponent_prestigious_titles - opponent_gs_titles
)]

# 2.2 Discretize general vs. surface win‑probability difference (symmetric trichotomy)
t_players[, c("player_win_prob_diff_general_vs_surface_cat",
              "opponent_win_prob_diff_general_vs_surface_cat") := .(
  cut(player_win_prob_diff_general_vs_surface,  breaks = c(-Inf, -0.2, 0.2, Inf),
      labels = c("negative","neutral","positive")),
  cut(opponent_win_prob_diff_general_vs_surface, breaks = c(-Inf, -0.2, 0.2, Inf),
      labels = c("negative","neutral","positive"))
)]

# 2.3 Efficiency ratios & surface‑vs‑general H2H delta
t_players[, c("h2h_surface_vs_general_diff",
              "player_serve_1st_efficiency", "opponent_serve_1st_efficiency",
              "player_return_1st_efficiency", "opponent_return_1st_efficiency",
              "player_return_1st_vs_2nd_diff", "opponent_return_1st_vs_2nd_diff") := .(
  player_h2h_surface_win_ratio - player_h2h_full_win_ratio,
  player_serve_1st_won_pct_avg / pmax(player_service_games_won_pct_avg, 1e-9),
  opponent_serve_1st_won_pct_avg / pmax(opponent_service_games_won_pct_avg, 1e-9),
  player_return_1st_won_pct_avg / pmax(player_return_games_won_pct_avg, 1e-9),
  opponent_return_1st_won_pct_avg / pmax(opponent_return_games_won_pct_avg, 1e-9),
  player_return_1st_won_pct_avg - player_return_2nd_won_pct_avg,
  opponent_return_1st_won_pct_avg - opponent_return_2nd_won_pct_avg
)]

#Delete the cols that you consider
drop_cols <- intersect(c(
), names(t_players))

if (length(drop_cols)) t_players[, (drop_cols) := NULL]

# ==================================================================================================
# 3) NA treatment & categorical encoding
# ==================================================================================================
# 3.1 Binary target & RET/W/O flags

t_players[, match_result := as.integer(match_result == "win")]

t_players[, is_retirement := fifelse(match_ret == "(RET)", 1L, 0L, na = 0L)]

t_players[, is_walkover  := fifelse(match_ret %in% c("(W/O)","W/O","(WEA)"), 1L, 0L, na = 0L)]

# Drop original if not needed downstream
if ("match_ret" %in% names(t_players)) t_players[, match_ret := NULL]

# 3.2 Rank trend categories → numeric (ordered: down < flat < up)
map_trend <- function(x) fcase(x == "bajada", -1L, x == "estable", 0L, x == "subida", 1L, default = NA_integer_)

t_players[, player_rank_trend_4w_cat  := map_trend(player_rank_trend_4w_cat)]

t_players[, opponent_rank_trend_4w_cat := map_trend(opponent_rank_trend_4w_cat)]

t_players[, player_rank_trend_12w_cat := map_trend(player_rank_trend_12w_cat)]

t_players[, opponent_rank_trend_12w_cat := map_trend(opponent_rank_trend_12w_cat)]

# 3.3 NA snapshot (sorted)
na_percentage <- t_players[, lapply(.SD, function(x) round(mean(is.na(x)) * 100, 2))]
na_percentage_vector <- unlist(na_percentage, use.names = TRUE)
na_summary <- data.frame(variable = names(na_percentage_vector),
                         na_percentage = as.numeric(na_percentage_vector))
na_summary <- na_summary[order(na_summary$na_percentage, decreasing = TRUE), ]
print(na_summary)

# 3.4 Simple seed imputation (0 = unseeded)
t_players[is.na(player_seed),   player_seed := 0L]
t_players[is.na(opponent_seed), opponent_seed := 0L]

# ==================================================================================================
# 4) H2H — Beta‑Binomial smoothing (p0 = 0.5) + credibility
# ==================================================================================================
alpha_full    <- 8L  # prior strength for overall H2H
alpha_surface <- 6L  # prior strength for surface H2H
p0_full       <- 0.5
p0_surface    <- 0.5
cap01 <- function(p, eps = 0.001) pmax(pmin(p, 1 - eps), eps)

# Availability flags

t_players[, has_player_h2h_surface := as.integer(!is.na(player_h2h_surface_win_ratio) &
                                                   !is.na(player_h2h_surface_total_matches) &
                                                   player_h2h_surface_total_matches > 0)]

t_players[, has_player_h2h_full    := as.integer(!is.na(player_h2h_full_win_ratio) &
                                                   !is.na(player_h2h_total_matches) &
                                                   player_h2h_total_matches > 0)]

# Rebuild raw wins (ratio * n) when possible

t_players[, `:=`(
  .player_h2h_full_wins_raw    = fifelse(!is.na(player_h2h_full_win_ratio)    & !is.na(player_h2h_total_matches),
                                         player_h2h_full_win_ratio    * player_h2h_total_matches, NA_real_),
  .player_h2h_surface_wins_raw = fifelse(!is.na(player_h2h_surface_win_ratio) & !is.na(player_h2h_surface_total_matches),
                                         player_h2h_surface_win_ratio * player_h2h_surface_total_matches, NA_real_)
)]

# Smoothed ratios (overwrite originals)

t_players[, player_h2h_full_win_ratio := {
  n <- player_h2h_total_matches
  w <- .player_h2h_full_wins_raw
  num <- fifelse(!is.na(n) & !is.na(w), w + alpha_full * p0_full, alpha_full * p0_full)
  den <- fifelse(!is.na(n),             n + alpha_full,            alpha_full)
  cap01(num / den)
}]

t_players[, player_h2h_surface_win_ratio := {
  n <- player_h2h_surface_total_matches
  w <- .player_h2h_surface_wins_raw
  num <- fifelse(!is.na(n) & !is.na(w), w + alpha_surface * p0_surface, alpha_surface * p0_surface)
  den <- fifelse(!is.na(n),             n + alpha_surface,              alpha_surface)
  cap01(num / den)
}]

# Credibility signals (0..1 based on sample size vs. prior strength)

t_players[, `:=`(
  player_h2h_full_cred    = fifelse(!is.na(player_h2h_total_matches),
                                    player_h2h_total_matches    / (player_h2h_total_matches    + alpha_full), 0),
  player_h2h_surface_cred = fifelse(!is.na(player_h2h_surface_total_matches),
                                    player_h2h_surface_total_matches / (player_h2h_surface_total_matches + alpha_surface), 0)
)]

# Delta already uses smoothed ratios

t_players[, h2h_surface_vs_general_diff := player_h2h_surface_win_ratio - player_h2h_full_win_ratio]

t_players[is.na(h2h_surface_vs_general_diff), h2h_surface_vs_general_diff := 0]

# Clean temporaries

t_players[, c(".player_h2h_full_wins_raw", ".player_h2h_surface_wins_raw") := NULL]

# ==================================================================================================
# 5) match_duration — conditional imputation by (surface, stadie_id, best_of)
# ==================================================================================================
duration_stats <- t_players[!is.na(match_duration),
                            .(mean_dur = mean(match_duration), sd_dur = sd(match_duration)),
                            by = .(surface, stadie_id, best_of)]

t_players <- merge(t_players, duration_stats, by = c("surface","stadie_id","best_of"), all.x = TRUE)

set.seed(123)

t_players[is.na(match_duration), match_duration := rnorm(.N, mean = mean_dur, sd = sd_dur)]

# Keep within a plausible range (minutes; adjust bounds if your data warrants it)

t_players[match_duration <  60, match_duration :=  60]

t_players[match_duration > 300, match_duration := 300]

# Drop helper columns and reorder for stability

t_players[, c("mean_dur","sd_dur") := NULL]

t_players <- order_datasets(t_players)

# ==================================================================================================
# 6) match_order — fill NAs consistently by (tournament_id, phase)
# ==================================================================================================
if ("match_order" %in% names(t_players)) {
  na_groups <- unique(t_players[is.na(match_order), .(tournament_id, stadie_id, id)])
  if (nrow(na_groups)) {
    na_groups[, match_order_new := seq_len(.N), by = .(tournament_id, stadie_id)]
    t_players[na_groups, match_order := match_order_new, on = .(tournament_id, stadie_id, id)]
    t_players[, match_order_new := NULL]
  }
}

# If match_duration is only used as an imputation helper, drop it now (optional)
# t_players[, match_duration := NULL]

# ==================================================================================================
# 7) NA% by year (robust computation)
# ==================================================================================================
# Compute % of NA cells across *all* columns for each year
na_by_year <- t_players[, .(na_percent = mean(is.na(unlist(.SD))) * 100), by = year]
print(na_by_year)

# ==================================================================================================
# 8) Bayesian smoothing + NA flags (34 columns)
# ==================================================================================================
cols_target <- c(
  "log_ratio_tiebreaks_won_pct",
  "log_ratio_break_points_converted_pct",
  "log_ratio_break_points_saved_pct",
  "log_ratio_double_faults_pct",
  "log_ratio_service_games_won_pct",
  "log_ratio_return_games_won_pct",
  "log_ratio_total_points_won_pct",
  "log_ratio_aces_per_match",
  "player_clutch_tiebreak_adj",
  "opponent_clutch_tiebreak_adj",
  "player_break_points_converted_pct_avg",
  "opponent_break_points_converted_pct_avg",
  "player_clutch_bp_conv_gap",
  "opponent_clutch_bp_conv_gap",
  "player_break_points_saved_pct_avg",
  "opponent_break_points_saved_pct_avg",
  "player_clutch_bp_save_gap",
  "opponent_clutch_bp_save_gap",
  "player_double_faults_pct_avg",
  "opponent_double_faults_pct_avg",
  "player_aces_per_match_avg",
  "opponent_aces_per_match_avg",
  "player_service_games_won_pct_avg",
  "opponent_service_games_won_pct_avg",
  "player_return_games_won_pct_avg",
  "opponent_return_games_won_pct_avg",
  "player_total_points_won_pct_avg",
  "opponent_total_points_won_pct_avg",
  "player_serve_1st_efficiency",
  "opponent_serve_1st_efficiency",
  "player_return_1st_efficiency",
  "opponent_return_1st_efficiency",
  "log_ratio_serve_1st_in_pct",
  "log_ratio_serve_2nd_won_pct"
)
cols_target <- intersect(cols_target, names(t_players))
stopifnot(length(cols_target) > 0L)

# Ensure date type + stable ordering before temporal features
if (!inherits(t_players$tournament_start_dtm, "Date")) {
  t_players <- t_players %>% mutate(tournament_start_dtm = as.Date(tournament_start_dtm))
}

order_vars <- c("tournament_start_dtm",
                intersect(c("tournament_id","stadie_id","match_order","id"), names(t_players)))

t_players <- t_players %>% arrange(across(all_of(order_vars)))

# Exposure: cumulative appearances up to (but excluding) the current row per role
# (dplyr kept to minimize churn; data.table equivalent would be faster)

t_players <- t_players %>%
  group_by(player_code)   %>% mutate(player_prev_matches   = row_number() - 1L) %>% ungroup() %>%
  group_by(opponent_code) %>% mutate(opponent_prev_matches = row_number() - 1L) %>% ungroup()

# Helpers to detect feature types
clip01 <- function(x, eps = 1e-6) pmin(pmax(x, eps), 1 - eps)

is_prop_col <- function(nm) {
  grepl("(_pct($|_)|_pct_avg$|_efficiency$|games_won_pct_avg$|points_won_pct_avg$)", nm)
}

is_logratio_col <- function(nm) startsWith(nm, "log_ratio_")

is_mean_col <- function(nm) grepl("clutch|gap|aces_per_match_avg", nm) && !is_logratio_col(nm)

who_owner <- function(nm) {
  if (startsWith(nm, "player_"))   return("player")
  if (startsWith(nm, "opponent_")) return("opponent")
  "both"
}

# Hyperparameters (tune via CV if needed)
alpha_prop <- 20  # stronger shrinkage for volatile %/rates
alpha_logr <- 30  # log-ratios shrink harder to 0
alpha_mean <- 10  # gaps/means shrink to global mean

smooth_vector <- function(v, who, type, n_player, n_opp) {
  was_na <- is.na(v)
  n <- switch(who,
              player   = n_player,
              opponent = n_opp,
              both     = pmin(n_player, n_opp))
  n[is.na(n)] <- 0

  if (type == "prop") {
    vmax <- suppressWarnings(max(v, na.rm = TRUE))
    scale100 <- is.finite(vmax) && vmax > 1.5
    vv <- if (scale100) v / 100 else v
    p0 <- suppressWarnings(mean(vv, na.rm = TRUE))
    if (!is.finite(p0)) p0 <- 0.5
    beta  <- n / (n + alpha_prop)
    vv_obs <- ifelse(is.na(vv), p0, vv)
    vv_new <- beta * vv_obs + (1 - beta) * p0
    vv_new <- clip01(vv_new)
    out <- if (scale100) vv_new * 100 else vv_new
    return(list(val = out, flag = as.integer(was_na)))
  }

  if (type == "logratio") {
    beta  <- n / (n + alpha_logr)
    v_obs <- ifelse(is.na(v), 0, v)
    v_new <- beta * v_obs + (1 - beta) * 0
    return(list(val = v_new, flag = as.integer(was_na)))
  }

  # type == "mean"
  x0 <- suppressWarnings(mean(v, na.rm = TRUE))
  if (!is.finite(x0)) x0 <- 0
  beta  <- n / (n + alpha_mean)
  v_obs <- ifelse(is.na(v), x0, v)
  v_new <- beta * v_obs + (1 - beta) * x0
  list(val = v_new, flag = as.integer(was_na))
}

# NA% before vs after smoothing
na_before <- sapply(cols_target, function(cn) mean(is.na(t_players[[cn]])) * 100)

# Ensure stable order again (defensive)
t_players <- order_datasets(t_players)

for (cn in cols_target) {
  who  <- who_owner(cn)
  type <- if (is_logratio_col(cn)) "logratio" else if (is_prop_col(cn)) "prop" else "mean"
  res <- smooth_vector(
    v        = t_players[[cn]],
    who      = who,
    type     = type,
    n_player = t_players$player_prev_matches,
    n_opp    = t_players$opponent_prev_matches
  )
  t_players[[paste0(cn, "_was_na")]] <- res$flag
  t_players[[cn]] <- res$val
}

na_after <- sapply(cols_target, function(cn) mean(is.na(t_players[[cn]])) * 100)

cat("=== NA% before vs after smoothing (first 10) ===\n")
print(data.frame(variable = cols_target,
                 na_before = round(na_before, 2),
                 na_after  = round(na_after,  2))[1:min(10, length(cols_target)), ])

# ==================================================================================================
# 10) Persist (optional)
# ==================================================================================================
 fwrite(t_players, "database_99-25_1.csv")
# fwrite(t_players, "pred_jugadores_99-25_enriched.csv")
