####################################################################################################
# Match-Level Rolling Serve KPIs (player & opponent) with strict anti-leakage guards
# --------------------------------------------------------------------------------------------------
# What this script does (high-level)
#   • Profiles missingness on the wide match-stat dataset (t_data).
#   • Computes per-match serve KPIs for both sides (player_* and opponent_*) and converts them to
#     *lagged cumulative averages* so that each row (a player’s perspective for a given match) only
#     sees information from *past* matches — never the current one (no target leakage).
#   • KPIs covered (for both player and opponent where sensible):
#       1) First-serve in %                    -> *_serve_1st_in_pct_avg
#       2) First-serve points won %            -> *_serve_1st_won_pct_avg
#       3) Second-serve points won %           -> *_serve_2nd_won_pct_avg
#       4) Double-fault rate (DF / 1st serves) -> *_double_faults_pct_avg
#       5) Aces per match                      -> *_aces_per_match_avg
#       6) Service games won %                 -> *_service_games_won_pct_avg
#       7) Break points saved %                -> *_break_points_saved_pct_avg
#
# Key design choices (keep semantics identical to your original code)
#   • Ordering: before each rolling computation we enforce chronological stability using
#     setorder(..., tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id).
#   • Leakage control: rolling means are computed with a lag(1). The current match contributes
#     only AFTER this row, so model-time features reflect history strictly prior to the match.
#   • Robustness: when a denominator is 0 or NA, the rate is set to NA_real_. For some features,
#     we only expose an average if at least 5 prior non-NA matches exist (your original threshold),
#     otherwise NA.
#   • Joins: all features are merged back into t_players by (id, player_code) or (id, opponent_code),
#     which is 1:1 in a player-centric table (two rows per match).
#
# Notes
#   • We intentionally keep multiple order_datasets()/setorder() calls to preserve your original
#     evaluation order and avoid subtle dependency bugs.
#   • Any change that could affect logic or distributions has been avoided. Micro-cleanups only.
####################################################################################################

library(data.table)
library(dplyr)

setwd("/home/aitor/Descargas/Project/Data/Msolonskyi")

# ------------------------------------------------------------------
# Load
# ------------------------------------------------------------------
t_players <- fread("pred_jugadores_99-25.csv")
t_data    <- fread("data_jugadores_99-25.csv")

# Canonical round order (kept identical to your pipeline)
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

# Stable tournament ordering used across the pipeline
order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,   # chronological
      tournament_name,        # deterministic tie-break
      tournament_id,          # group by tournament
      stadie_id,              # round within tournament
      match_order             # within-round order
    )
}

# ------------------------------------------------------------------
# Quick NA profile for t_data (wide stats table)
# ------------------------------------------------------------------
na_percentage <- function(df) {
  na_perc  <- sapply(df, function(x) mean(is.na(x)) * 100)
  na_count <- sapply(df, function(x) sum(is.na(x)))
  data.table(
    variable   = names(na_perc),
    na_percent = round(na_perc, 2),
    na_count   = as.integer(na_count)
  )[order(-na_percent)]
}

res <- na_percentage(t_data)
print(res, nrow = nrow(res))  # full print for auditability

# ------------------------------------------------------------------
# Ensure dates are Date and global ordering is stable
# ------------------------------------------------------------------
t_players <- order_datasets(t_players)
t_data    <- order_datasets(t_data)

t_data[,    tournament_start_dtm := as.Date(tournament_start_dtm)]
t_players[, tournament_start_dtm := as.Date(tournament_start_dtm)]

# Helper: cumulative average with anti-leak (lag 1) by player_code
calculate_cumulative_avg <- function(data, var_name) {
  data[, paste0(var_name, "_avg") := {
    v         <- get(var_name)
    cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
    cum_count <- cumsum(!is.na(v))
    temp_avg  <- fifelse(cum_count > 0, cum_sum / cum_count, NA_real_)
    shift(temp_avg, n = 1, type = "lag")   # strict past only
  }, by = player_code]
}

# Helper: cumulative average with anti-leak + min N prior matches
calculate_cumulative_avg_minN <- function(data, var_name, min_n = 5L) {
  data[, paste0(var_name, "_avg") := {
    v         <- get(var_name)
    cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
    cum_count <- cumsum(!is.na(v))
    temp_avg  <- fifelse(cum_count >= min_n, cum_sum / cum_count, NA_real_)
    shift(temp_avg, n = 1, type = "lag")
  }, by = player_code]
}

# ------------------------------------------------------------------
# 1) First-serve IN % (player & opponent) -> *_serve_1st_in_pct_avg
# ------------------------------------------------------------------
t_data[, player_serve_1st_in_pct   := fifelse(player_first_serves_total   > 0,
                                              player_first_serves_in / player_first_serves_total, NA_real_)]
t_data[, opponent_serve_1st_in_pct := fifelse(opponent_first_serves_total > 0,
                                              opponent_first_serves_in / opponent_first_serves_total, NA_real_)]

# Player side
setorder(t_data, player_code, tournament_start_dtm, stadie_id, tournament_id, match_order)
t_players <- order_datasets(t_players)
calculate_cumulative_avg(t_data, "player_serve_1st_in_pct")
t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_serve_1st_in_pct_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent side
setorder(t_data, opponent_code, tournament_start_dtm, stadie_id, tournament_id, match_order)
t_data[, opponent_serve_1st_in_pct_avg := {
  v         <- opponent_serve_1st_in_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count > 0, cum_sum / cum_count, NA_real_)
  shift(temp_avg, n = 1, type = "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_serve_1st_in_pct_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

cat("NA % player_serve_1st_in_pct_avg: ",
    mean(is.na(t_players$player_serve_1st_in_pct_avg)) * 100, "%\n", sep = "")
cat("NA % opponent_serve_1st_in_pct_avg: ",
    mean(is.na(t_players$opponent_serve_1st_in_pct_avg)) * 100, "%\n", sep = "")

# ------------------------------------------------------------------
# 2) First/Second-serve POINTS WON % (player & opponent)
#     -> *_serve_1st_won_pct_avg, *_serve_2nd_won_pct_avg
# ------------------------------------------------------------------
t_data[, player_serve_1st_won_pct := fifelse(player_first_serve_points_total  > 0,
                                             player_first_serve_points_won / player_first_serve_points_total, NA_real_)]
t_data[, player_serve_2nd_won_pct := fifelse(player_second_serve_points_total > 0,
                                             player_second_serve_points_won / player_second_serve_points_total, NA_real_)]

t_data[, opponent_serve_1st_won_pct := fifelse(opponent_first_serve_points_total  > 0,
                                               opponent_first_serve_points_won / opponent_first_serve_points_total, NA_real_)]
t_data[, opponent_serve_2nd_won_pct := fifelse(opponent_second_serve_points_total > 0,
                                               opponent_second_serve_points_won / opponent_second_serve_points_total, NA_real_)]

# Player rolling (no min-N for these two in your code)
setorder(t_data, player_code, tournament_start_dtm, stadie_id, tournament_name, tournament_id, match_order)
calculate_cumulative_avg(t_data, "player_serve_1st_won_pct")
calculate_cumulative_avg(t_data, "player_serve_2nd_won_pct")

t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_serve_1st_won_pct_avg, player_serve_2nd_won_pct_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent rolling
setorder(t_data, opponent_code, tournament_start_dtm, stadie_id, tournament_name, tournament_id, match_order)
t_data[, opponent_serve_1st_won_pct_avg := {
  v <- opponent_serve_1st_won_pct
  cum_sum <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp <- fifelse(cum_count > 0, cum_sum / cum_count, NA_real_)
  shift(temp, 1, "lag")
}, by = opponent_code]

t_data[, opponent_serve_2nd_won_pct_avg := {
  v <- opponent_serve_2nd_won_pct
  cum_sum <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp <- fifelse(cum_count > 0, cum_sum / cum_count, NA_real_)
  shift(temp, 1, "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_serve_1st_won_pct_avg, opponent_serve_2nd_won_pct_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players)
cat("NA % player_serve_1st_won_pct_avg: ",
    mean(is.na(t_players$player_serve_1st_won_pct_avg))*100, "%\n", sep = "")
cat("NA % player_serve_2nd_won_pct_avg: ",
    mean(is.na(t_players$player_serve_2nd_won_pct_avg))*100, "%\n", sep = "")
cat("NA % opponent_serve_1st_won_pct_avg: ",
    mean(is.na(t_players$opponent_serve_1st_won_pct_avg))*100, "%\n", sep = "")
cat("NA % opponent_serve_2nd_won_pct_avg: ",
    mean(is.na(t_players$opponent_serve_2nd_won_pct_avg))*100, "%\n", sep = "")

# ------------------------------------------------------------------
# 3) Double-fault rate (DF / first serves) with min 5 prior matches
#     -> *_double_faults_pct_avg
# ------------------------------------------------------------------
t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

t_data[, player_double_faults_pct := fifelse(player_first_serves_total > 0,
                                             player_double_faults / player_first_serves_total, NA_real_)]

setorder(t_data, player_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
# min-N = 5 prior matches
t_data[, player_double_faults_pct_avg := {
  v         <- player_double_faults_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = player_code]

t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_double_faults_pct_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent
t_data[, opponent_double_faults_pct := fifelse(opponent_first_serves_total > 0,
                                               opponent_double_faults / opponent_first_serves_total, NA_real_)]

setorder(t_data, opponent_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, opponent_double_faults_pct_avg := {
  v         <- opponent_double_faults_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_double_faults_pct_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players)
cat("NA % player_double_faults_pct_avg: ",
    mean(is.na(t_players$player_double_faults_pct_avg))*100, "%\n", sep = "")
cat("NA % opponent_double_faults_pct_avg: ",
    mean(is.na(t_players$opponent_double_faults_pct_avg))*100, "%\n", sep = "")

# ------------------------------------------------------------------
# 4) Aces per match (min 5 prior matches) -> *_aces_per_match_avg
# ------------------------------------------------------------------
t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

setorder(t_data, player_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, player_aces_per_match_avg := {
  v         <- player_aces
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = player_code]

t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_aces_per_match_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent side
setorder(t_data, opponent_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, opponent_aces_per_match_avg := {
  v         <- opponent_aces
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_aces_per_match_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)
cat("NA % player_aces_per_match_avg: ",
    mean(is.na(t_players$player_aces_per_match_avg))*100, "%\n", sep = "")
cat("NA % opponent_aces_per_match_avg: ",
    mean(is.na(t_players$opponent_aces_per_match_avg))*100, "%\n", sep = "")

# ------------------------------------------------------------------
# 5) Service games WON % (derive svc games won = games_won - breaks converted)
#     -> *_service_games_won_pct_avg  (min 5 prior matches)
# ------------------------------------------------------------------
t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

t_data[, player_service_games_won := {
  gw   <- player_games_won
  brk  <- player_break_points_converted
  s_gp <- player_service_games_played
  # clamp to [0, s_gp] if computed
  fifelse(is.na(gw) | is.na(brk) | is.na(s_gp), NA_real_,
          pmax(0, pmin(s_gp, gw - brk)))
}]

t_data[, player_service_games_won_pct := fifelse(player_service_games_played > 0,
                                                 player_service_games_won / player_service_games_played, NA_real_)]

setorder(t_data, player_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, player_service_games_won_pct_avg := {
  v         <- player_service_games_won_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = player_code]

t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_service_games_won_pct_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent mirror
t_data[, opponent_service_games_won := {
  gw   <- opponent_games_won
  brk  <- opponent_break_points_converted
  s_gp <- opponent_service_games_played
  fifelse(is.na(gw) | is.na(brk) | is.na(s_gp), NA_real_,
          pmax(0, pmin(s_gp, gw - brk)))
}]

t_data[, opponent_service_games_won_pct := fifelse(opponent_service_games_played > 0,
                                                   opponent_service_games_won / opponent_service_games_played, NA_real_)]

setorder(t_data, opponent_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, opponent_service_games_won_pct_avg := {
  v         <- opponent_service_games_won_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_service_games_won_pct_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)
cat("NA % player_service_games_won_pct_avg: ",
    mean(is.na(t_players$player_service_games_won_pct_avg))*100, "%\n", sep = "")
cat("NA % opponent_service_games_won_pct_avg: ",
    mean(is.na(t_players$opponent_service_games_won_pct_avg))*100, "%\n", sep = "")

# ------------------------------------------------------------------
# 6) Break points SAVED % with min 5 prior matches
#     -> *_break_points_saved_pct_avg
# ------------------------------------------------------------------
t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)

t_data[, player_break_points_saved_pct := fifelse(player_break_points_serve_total > 0,
                                                  player_break_points_saved / player_break_points_serve_total, NA_real_)]

setorder(t_data, player_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, player_break_points_saved_pct_avg := {
  v         <- player_break_points_saved_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = player_code]

t_players <- merge(
  t_players,
  t_data[, .(id, player_code, player_break_points_saved_pct_avg)],
  by = c("id", "player_code"), all.x = TRUE
)

# Opponent mirror
t_data[, opponent_break_points_saved_pct := fifelse(opponent_break_points_serve_total > 0,
                                                    opponent_break_points_saved / opponent_break_points_serve_total, NA_real_)]

setorder(t_data, opponent_code, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order, id)
t_data[, opponent_break_points_saved_pct_avg := {
  v         <- opponent_break_points_saved_pct
  cum_sum   <- cumsum(fifelse(is.na(v), 0, v))
  cum_count <- cumsum(!is.na(v))
  temp_avg  <- fifelse(cum_count >= 5, cum_sum / cum_count, NA_real_)
  shift(temp_avg, 1, "lag")
}, by = opponent_code]

t_players <- merge(
  t_players,
  t_data[, .(id, opponent_code, opponent_break_points_saved_pct_avg)],
  by = c("id", "opponent_code"), all.x = TRUE
)

t_players <- order_datasets(t_players); t_data <- order_datasets(t_data)
cat("NA % player_break_points_saved_pct_avg: ",
    mean(is.na(t_players$player_break_points_saved_pct_avg))*100, "%\n", sep = "")
cat("NA % opponent_break_points_saved_pct_avg: ",
    mean(is.na(t_players$opponent_break_points_saved_pct_avg))*100, "%\n", sep = "")

# ------------------------------------------------------------------
# Persist enriched player-centric table
# ------------------------------------------------------------------
fwrite(t_players, "pred_jugadores_99-25.csv")

