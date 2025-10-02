####################################################################################################
# Return KPIs + Log-Ratios + Clutch Gaps (strict anti-leakage, symmetric player/opponent)
# --------------------------------------------------------------------------------------------------
# High-level
#   • From per-match raw stats (t_data), build *lagged cumulative averages* for return efficiency
#     metrics on both roles (player_* and opponent_*), then merge them into the player-centric table
#     (t_players). Current match does NOT contaminate its own features (no leakage).
#   • KPIs computed (for both player and opponent, where applicable):
#       1) Return points won vs 1st serve        -> *_return_1st_won_pct_avg
#       2) Return points won vs 2nd serve        -> *_return_2nd_won_pct_avg
#       3) Return games won %                    -> *_return_games_won_pct_avg     (min 5 prior)
#       4) Break points converted %              -> *_break_points_converted_pct_avg (min 5 prior)
#       5) Total points won %                    -> *_total_points_won_pct_avg     (min 5 prior)
#       6) Tie-breaks won %                      -> *_tiebreaks_won_pct_avg        (min 5 prior)
#   • Additionally:
#       • 13 log-ratio features: log(player_avg+eps) − log(opponent_avg+eps) for each KPI.
#       • 3 “clutch” gaps contrasting pressure vs baseline (serve BP saved, return BP converted, TB).
#
# Design guards (preserves your original semantics)
#   • Chronology: before each rolling computation we enforce a stable order:
#       setorderv(..., c(group_col, "tournament_start_dtm","tournament_name","tournament_id",
#                        "stadie_id","match_order","id"))
#   • Strict past only: rolling means use lag(1); the current row only “sees” history *before* it.
#   • Robustness: rates are NA when denominators are 0/NA. Some KPIs are exposed only if the player
#     has ≥ 5 prior non-NA matches; otherwise NA (unchanged from your logic).
#   • Symmetry & safety: opponent features are computed by role (group = opponent_code), then merged
#     1:1 into t_players by (id, opponent_code). No non-equi joins → no duplications.
#
# Notes
#   • We removed temporary tables that were not used in the final joins and factorized repeated code
#     into small helpers to reduce redundancy (without altering outputs).
#   • Column names and formulas remain unchanged to avoid breaking downstream steps.
####################################################################################################

library(data.table)
library(dplyr)

# ----------------------------------------------------------------------------------------
# Load
# ----------------------------------------------------------------------------------------
setwd("/home/aitor/Descargas/Project/Data/Msolonskyi")
t_players <- fread("pred_jugadores_99-25.csv")
t_data    <- fread("data_jugadores_99-25.csv")

# Canonical round order (consistent across pipeline)
orden_fases <- c("Q1","Q2","Q3","BR","RR","R128","R64","R32","R16","QF","SF","F","3P")

# Stable tournament ordering used across the pipeline
order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # chronological
      tournament_name,       # deterministic tie-break
      tournament_id,         # group by tournament
      stadie_id,             # round within tournament
      match_order            # within-round order
    )
}

# Ensure dates are Date and global ordering is stable
t_players <- order_datasets(t_players)
t_data    <- order_datasets(t_data)
t_players[, tournament_start_dtm := as.Date(tournament_start_dtm)]
t_data[,    tournament_start_dtm := as.Date(tournament_start_dtm)]

# ----------------------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------------------

# 1) Order by role + stable tournament keys (works for player_code / opponent_code)
ord_by_role <- function(dt, group_col) {
  setorderv(dt, c(group_col,
                  "tournament_start_dtm","tournament_name","tournament_id",
                  "stadie_id","match_order","id"))
}

# 2) Cumulative average with anti-leak. If min_n is provided, expose avg only after min_n prior rows.
cumavg_by_role <- function(dt, value_col, group_col, out_col, min_n = NULL) {
  ord_by_role(dt, group_col)
  dt[, (out_col) := {
    v         <- get(value_col)
    cum_sum   <- cumsum(ifelse(is.na(v), 0, v))
    cum_count <- cumsum(!is.na(v))
    avg_now   <- ifelse(cum_count > 0, cum_sum / cum_count, NA_real_)
    if (!is.null(min_n)) avg_now <- ifelse(cum_count >= min_n, avg_now, NA_real_)
    shift(avg_now, n = 1, type = "lag")   # strict past only
  }, by = group_col]
}

# 3) Safe log-ratio: log((p+eps)/(o+eps))
safe_log_ratio <- function(p, o, eps = 1e-6) {
  out <- rep(NA_real_, length(p))
  ok  <- !is.na(p) & !is.na(o)
  out[ok] <- log(p[ok] + eps) - log(o[ok] + eps)
  out
}

# ----------------------------------------------------------------------------------------
# BLOCK A — Return efficiency vs 1st/2nd serve
# ----------------------------------------------------------------------------------------

# % return points won vs 1st serve
t_data[, player_return_1st_won_pct   := ifelse(player_first_serve_return_total   > 0,
                                               player_first_serve_return_won / player_first_serve_return_total, NA_real_)]
t_data[, opponent_return_1st_won_pct := ifelse(opponent_first_serve_return_total > 0,
                                               opponent_first_serve_return_won / opponent_first_serve_return_total, NA_real_)]

cumavg_by_role(t_data, "player_return_1st_won_pct",   "player_code",   "player_return_1st_won_pct_avg")
cumavg_by_role(t_data, "opponent_return_1st_won_pct", "opponent_code", "opponent_return_1st_won_pct_avg")

t_players <- merge(t_players, t_data[, .(id, player_code,   player_return_1st_won_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_return_1st_won_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

# % return points won vs 2nd serve
t_data[, player_return_2nd_won_pct   := ifelse(player_second_serve_return_total   > 0,
                                               player_second_serve_return_won / player_second_serve_return_total, NA_real_)]
t_data[, opponent_return_2nd_won_pct := ifelse(opponent_second_serve_return_total > 0,
                                               opponent_second_serve_return_won / opponent_second_serve_return_total, NA_real_)]

cumavg_by_role(t_data, "player_return_2nd_won_pct",   "player_code",   "player_return_2nd_won_pct_avg")
cumavg_by_role(t_data, "opponent_return_2nd_won_pct", "opponent_code", "opponent_return_2nd_won_pct_avg")

t_players <- merge(t_players, t_data[, .(id, player_code,   player_return_2nd_won_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_return_2nd_won_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_return_1st_won_pct_avg: ",
    mean(is.na(t_players$player_return_1st_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_return_1st_won_pct_avg: ",
    mean(is.na(t_players$opponent_return_1st_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % player_return_2nd_won_pct_avg: ",
    mean(is.na(t_players$player_return_2nd_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_return_2nd_won_pct_avg: ",
    mean(is.na(t_players$opponent_return_2nd_won_pct_avg)) * 100, "%\n", sep = "")

# ----------------------------------------------------------------------------------------
# BLOCK B — Return games won % (min 5 prior)
# ----------------------------------------------------------------------------------------

# % return games won = breaks converted / return games played
t_data[, player_return_games_won_pct   := ifelse(player_return_games_played   > 0,
                                                 player_break_points_converted / player_return_games_played, NA_real_)]
t_data[, opponent_return_games_won_pct := ifelse(opponent_return_games_played > 0,
                                                 opponent_break_points_converted / opponent_return_games_played, NA_real_)]

cumavg_by_role(t_data, "player_return_games_won_pct",   "player_code",   "player_return_games_won_pct_avg",   min_n = 5L)
cumavg_by_role(t_data, "opponent_return_games_won_pct", "opponent_code", "opponent_return_games_won_pct_avg", min_n = 5L)

t_players <- merge(t_players, t_data[, .(id, player_code,   player_return_games_won_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_return_games_won_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_return_games_won_pct_avg: ",
    mean(is.na(t_players$player_return_games_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_return_games_won_pct_avg: ",
    mean(is.na(t_players$opponent_return_games_won_pct_avg)) * 100, "%\n", sep = "")

# ----------------------------------------------------------------------------------------
# BLOCK C — Break points converted % (min 5 prior)
# ----------------------------------------------------------------------------------------

t_data[, player_break_points_converted_pct   := ifelse(player_break_points_return_total   > 0,
                                                       player_break_points_converted / player_break_points_return_total, NA_real_)]
t_data[, opponent_break_points_converted_pct := ifelse(opponent_break_points_return_total > 0,
                                                       opponent_break_points_converted / opponent_break_points_return_total, NA_real_)]

cumavg_by_role(t_data, "player_break_points_converted_pct",   "player_code",
               "player_break_points_converted_pct_avg",   min_n = 5L)
cumavg_by_role(t_data, "opponent_break_points_converted_pct", "opponent_code",
               "opponent_break_points_converted_pct_avg", min_n = 5L)

t_players <- merge(t_players, t_data[, .(id, player_code,   player_break_points_converted_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_break_points_converted_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_break_points_converted_pct_avg: ",
    mean(is.na(t_players$player_break_points_converted_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_break_points_converted_pct_avg: ",
    mean(is.na(t_players$opponent_break_points_converted_pct_avg)) * 100, "%\n", sep = "")

# ----------------------------------------------------------------------------------------
# BLOCK D — Total points won % (min 5 prior)
# ----------------------------------------------------------------------------------------

t_data[, player_total_points_won_pct   := ifelse(player_total_points_total   > 0,
                                                 player_total_points_won / player_total_points_total, NA_real_)]
t_data[, opponent_total_points_won_pct := ifelse(opponent_total_points_total > 0,
                                                 opponent_total_points_won / opponent_total_points_total, NA_real_)]

cumavg_by_role(t_data, "player_total_points_won_pct",   "player_code",
               "player_total_points_won_pct_avg",   min_n = 5L)
cumavg_by_role(t_data, "opponent_total_points_won_pct", "opponent_code",
               "opponent_total_points_won_pct_avg", min_n = 5L)

t_players <- merge(t_players, t_data[, .(id, player_code,   player_total_points_won_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_total_points_won_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_total_points_won_pct_avg: ",
    mean(is.na(t_players$player_total_points_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_total_points_won_pct_avg: ",
    mean(is.na(t_players$opponent_total_points_won_pct_avg)) * 100, "%\n", sep = "")

# ----------------------------------------------------------------------------------------
# BLOCK E — Tie-breaks won % (min 5 prior)
# ----------------------------------------------------------------------------------------

# Denominator is total tie-breaks in the match (player + opponent)
t_data[, player_tiebreaks_won_pct   := ifelse((player_tiebreaks_won + opponent_tiebreaks_won) > 0,
                                              player_tiebreaks_won / (player_tiebreaks_won + opponent_tiebreaks_won), NA_real_)]
t_data[, opponent_tiebreaks_won_pct := ifelse((player_tiebreaks_won + opponent_tiebreaks_won) > 0,
                                              opponent_tiebreaks_won / (player_tiebreaks_won + opponent_tiebreaks_won), NA_real_)]

cumavg_by_role(t_data, "player_tiebreaks_won_pct",   "player_code",   "player_tiebreaks_won_pct_avg",   min_n = 5L)
cumavg_by_role(t_data, "opponent_tiebreaks_won_pct", "opponent_code", "opponent_tiebreaks_won_pct_avg", min_n = 5L)

t_players <- merge(t_players, t_data[, .(id, player_code,   player_tiebreaks_won_pct_avg)],
                   by = c("id", "player_code"), all.x = TRUE)
t_players <- merge(t_players, t_data[, .(id, opponent_code, opponent_tiebreaks_won_pct_avg)],
                   by = c("id", "opponent_code"), all.x = TRUE)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_tiebreaks_won_pct_avg: ",
    mean(is.na(t_players$player_tiebreaks_won_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_tiebreaks_won_pct_avg: ",
    mean(is.na(t_players$opponent_tiebreaks_won_pct_avg)) * 100, "%\n", sep = "")

# ----------------------------------------------------------------------------------------
# BLOCK F — Log-ratios (player vs opponent) for 13 bases
# ----------------------------------------------------------------------------------------

eps <- 1e-6
bases <- c(
  "serve_1st_in_pct_avg",
  "serve_1st_won_pct_avg",
  "serve_2nd_won_pct_avg",
  "double_faults_pct_avg",
  "aces_per_match_avg",
  "service_games_won_pct_avg",
  "break_points_saved_pct_avg",
  "return_1st_won_pct_avg",
  "return_2nd_won_pct_avg",
  "return_games_won_pct_avg",
  "break_points_converted_pct_avg",
  "total_points_won_pct_avg",
  "tiebreaks_won_pct_avg"
)

for (b in bases) {
  player_col   <- paste0("player_",   b)
  opponent_col <- paste0("opponent_", b)
  out_col      <- paste0("log_ratio_", sub("_avg$", "", b))
  if (!(player_col %in% names(t_players))) stop("Missing column: ", player_col)
  if (!(opponent_col %in% names(t_players))) stop("Missing column: ", opponent_col)
  t_players[, (out_col) := safe_log_ratio(get(player_col), get(opponent_col), eps = eps)]
}

# Optional NA audit on new log-ratio features
new_cols <- paste0("log_ratio_", sub("_avg$", "", bases))
for (cn in new_cols) cat(sprintf("NA %% in %s: %.4f %%\n", cn, mean(is.na(t_players[[cn]])) * 100))

# ----------------------------------------------------------------------------------------
# BLOCK G — “Clutch” contrasts (pressure vs baseline)
# ----------------------------------------------------------------------------------------

# 1) Serve pressure: BP saved % vs service games won %
t_players[, player_clutch_bp_save_gap   := player_break_points_saved_pct_avg   - player_service_games_won_pct_avg]
t_players[, opponent_clutch_bp_save_gap := opponent_break_points_saved_pct_avg - opponent_service_games_won_pct_avg]

# 2) Return pressure: BP converted % vs return games won %
t_players[, player_clutch_bp_conv_gap   := player_break_points_converted_pct_avg   - player_return_games_won_pct_avg]
t_players[, opponent_clutch_bp_conv_gap := opponent_break_points_converted_pct_avg - opponent_return_games_won_pct_avg]

# 3) Tie-break clutch: TB win % vs total points won %
t_players[, player_clutch_tiebreak_adj   := player_tiebreaks_won_pct_avg   - player_total_points_won_pct_avg]
t_players[, opponent_clutch_tiebreak_adj := opponent_tiebreaks_won_pct_avg - opponent_total_points_won_pct_avg]

# Quick NA check on clutch vars
for (cn in c("player_clutch_bp_save_gap","opponent_clutch_bp_save_gap",
             "player_clutch_bp_conv_gap","opponent_clutch_bp_conv_gap",
             "player_clutch_tiebreak_adj","opponent_clutch_tiebreak_adj")) {
  cat(sprintf("NA %% in %s: %.4f %%\n", cn, mean(is.na(t_players[[cn]])) * 100))
}

# ----------------------------------------------------------------------------------------
# Persist
# ----------------------------------------------------------------------------------------
fwrite(t_players, "pred_jugadores_99-25.csv")
