############################################################################################
# Player/Surface Historical Enrichment + Progressive Win-Rate by Surface + Match Metadata
# ------------------------------------------------------------------------------------------
# Purpose
#   This script enriches a player-centric ATP dataset (1999–2025) with:
#     1) Pre-1999 surface-normalized historical context (wins/matches by surface)
#     2) “Favourite surface” flags per player/opponent based on long-run win rates
#     3) Progressive (time-aware, no-leakage) win-rate by surface at match time
#        for both the focal player and the opponent (seeded with pre-1999 stats)
#     4) Match score injection and inference of best_of (3 or 5) using score strings
#     5) Tournament-level fatigue proxies: cumulative sets played by player/opponent
#
# Data assumptions
#   • pred_jugadores_99-25.csv  : one row per player per match (two rows per id),
#                                 includes match_result ("win"/"loss"), tournament_*,
#                                 stadie_id, match_order, surface, and turned_pro fields.
#   • Jeff Sackmann all_matches.csv (year < 1999): columns winner_code, loser_code, surface,
#                                 tourney_date, round, tourney_id, match_num.
#   • data_jugadores_99-25.csv  : provides match_score by (id, player_code).
#
# Key ideas & guardrails
#   • Surface normalization collapses raw labels to {Clay, Grass, Carpet, Hard}.
#   • Pre-1999 (1968–1998) wins/matches by surface are computed and *only* used as
#     seeds (priors) when building progressive (pre-match) win rates in 1999–2025.
#   • Progressive rates are computed vectorially, in time order, and respect causality:
#     for each match, win_rate_before = (seed_wins + cumulative_wins_so_far) /
#                                       (seed_matches + cumulative_matches_so_far).
#     This is done separately for (player_code, surface) and for (opponent_code, surface).
#   • Favourite surface flags equal 1 if the current match’s surface matches the player’s
#     long-run argmax surface (highest observed surface win rate), 0 otherwise. NAs default to 0.
#   • best_of is set to 5 for Grand Slams (“gs”), otherwise inferred from the first valid
#     score in the tournament (RET/W/O/ABN ignored); fallback = 3 when score inference fails.
#   • Tournament “workload” features player_sets_played_tournament and
#     opponent_sets_played_tournament count the sets completed *prior to the current match*
#     within the same tournament (stable chronological ordering ensures no leakage).
#
# Output
#   • Overwrites pred_jugadores_99-25.csv, adding:
#       - player_favourite_surface, opponent_favourite_surface (binary flags)
#       - player_win_rate_surface_progressive, opponent_win_rate_surface_progressive
#       - match_score (joined from data_jugadores_99-25.csv)
#       - best_of (3 or 5)
#       - player_sets_played_tournament, opponent_sets_played_tournament
############################################################################################

library(data.table)
library(dplyr)
library(progress)

# ------------------------------------------------------------------------------------------
# Setup & IO
# ------------------------------------------------------------------------------------------
setwd("")
t_players <- fread("pred_jugadores_99-25.csv", stringsAsFactors = FALSE)

data_pre99 <- read.csv("JeffSackman/all_matches.csv")
data_pre99 <- data_pre99[data_pre99$year < 1999, ]  # 1968–1998

# Round ordering for stable tournament sequencing
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,
      tournament_name,
      tournament_id,
      stadie_id,
      match_order
    )
}

# Promote to data.table for vectorized operations
setDT(t_players)
setDT(data_pre99)

# ------------------------------------------------------------------------------------------
# 1) Surface normalization helpers + pre-1999 per-surface seeds
# ------------------------------------------------------------------------------------------
norm_surface <- function(s) {
  x <- tolower(trimws(as.character(s)))
  fifelse(grepl("clay",   x), "Clay",
  fifelse(grepl("grass",  x), "Grass",
  fifelse(grepl("carpet", x), "Carpet",
  fifelse(grepl("hard",   x), "Hard", NA_character_))))
}

# Normalize surface in pre-99 matches
data_pre99[, surface_norm := norm_surface(surface)]

# Pre-99 per-surface wins & losses per player
winner_stats <- data_pre99[, .(wins = .N, losses = 0), by = .(player_code = winner_code, surface_norm)]
loser_stats  <- data_pre99[, .(wins = 0,  losses = .N), by = .(player_code = loser_code,  surface_norm)]
pre99_stats  <- rbind(winner_stats, loser_stats)
pre99_stats  <- pre99_stats[, .(wins = sum(wins), losses = sum(losses)), by = .(player_code, surface_norm)]
pre99_stats[, total_matches := wins + losses]

# Pre-99 seeds table (wins/matches) by player & surface
pre99_win_rates <- pre99_stats[, .(wins = wins, matches = total_matches), by = .(player_code, surface_norm)]

# Use 1999–2025 debut years to filter pre-99 seeds to players who indeed existed pre-1999
player_debut <- unique(t_players[, .(player_code, player_turned_pro)])
pre99_stats  <- pre99_stats[player_code %in% player_debut[player_turned_pro < 1999, player_code]]

# ------------------------------------------------------------------------------------------
# 2) Favourite surface flags (player/opponent) using long-run win rates
# ------------------------------------------------------------------------------------------
# Work on a temporary copy with normalized surface
t_players_temp <- copy(t_players)
t_players_temp[, surface_norm := norm_surface(surface)]

# Aggregate 1999–2025 results by (player_code, surface)
stats_player <- t_players_temp[, .(
  wins = sum(match_result == "win", na.rm = TRUE),
  total_matches = .N
), by = .(player_code, surface_norm)]

# Merge with pre-99 seeds, sum wins/matches, compute rate
stats_player <- merge(stats_player, pre99_stats, by = c("player_code", "surface_norm"),
                      all.x = TRUE, suffixes = c("", "_pre99"))
stats_player[!is.na(wins_pre99),            wins := wins + wins_pre99]
stats_player[!is.na(total_matches_pre99),   total_matches := total_matches + total_matches_pre99]
stats_player[, player_win_rate_surface := wins / total_matches]

# Opponent perspective (opponent_code’s wins are match_result == "loss")
stats_opponent <- t_players_temp[, .(
  wins = sum(match_result == "loss", na.rm = TRUE),
  total_matches = .N
), by = .(opponent_code, surface_norm)]

stats_opponent <- merge(stats_opponent, pre99_stats,
                        by.x = c("opponent_code", "surface_norm"),
                        by.y = c("player_code",   "surface_norm"),
                        all.x = TRUE, suffixes = c("", "_pre99"))
stats_opponent[!is.na(wins_pre99),            wins := wins + wins_pre99]
stats_opponent[!is.na(total_matches_pre99),   total_matches := total_matches + total_matches_pre99]
stats_opponent[, opponent_win_rate_surface := wins / total_matches]

# Argmax surface per entity → favourite
favourite_player   <- stats_player[,   .SD[which.max(player_win_rate_surface)],   by = player_code]
setnames(favourite_player, "surface_norm", "player_favourite_surface_name")

favourite_opponent <- stats_opponent[, .SD[which.max(opponent_win_rate_surface)], by = opponent_code]
setnames(favourite_opponent, "surface_norm", "opponent_favourite_surface_name")

# Join favourite surface names onto matches
t_players_temp <- favourite_player[t_players_temp,   on = .(player_code)]
t_players_temp <- favourite_opponent[t_players_temp, on = .(opponent_code)]

# Binary indicators for current match’s surface == favourite surface
t_players_temp[, player_favourite_surface   := as.integer(surface_norm == player_favourite_surface_name)]
t_players_temp[, opponent_favourite_surface := as.integer(surface_norm == opponent_favourite_surface_name)]

# Handle NAs → 0
t_players_temp[is.na(player_favourite_surface),   player_favourite_surface := 0]
t_players_temp[is.na(opponent_favourite_surface), opponent_favourite_surface := 0]

# Extract just the flags and copy back to main table
new_cols <- t_players_temp[, .(player_favourite_surface, opponent_favourite_surface)]
t_players[,  player_favourite_surface := new_cols$player_favourite_surface]
t_players[,  opponent_favourite_surface := new_cols$opponent_favourite_surface]

# Clean temporaries
rm(t_players_temp, stats_player, stats_opponent, favourite_player, favourite_opponent, new_cols,
   winner_stats, loser_stats, pre99_stats, player_debut)

# ------------------------------------------------------------------------------------------
# 3) Progressive, pre-match surface win-rate (vectorized, no leakage)
# ------------------------------------------------------------------------------------------
# Normalize surface in t_players
t_players[, surface_norm := norm_surface(surface)]
t_players <- order_datasets(t_players)

# Player universe and indices for vectorization
all_players <- unique(c(t_players$player_code, t_players$opponent_code, pre99_win_rates$player_code))
all_players <- all_players[!is.na(all_players) & all_players != ""]
player_index <- setNames(seq_along(all_players), all_players)

surfaces <- c("Clay", "Grass", "Carpet", "Hard")
surface_index <- setNames(seq_along(surfaces), surfaces)

# Initialize destinations
t_players[, player_win_rate_surface_progressive   := NA_real_]
t_players[, opponent_win_rate_surface_progressive := NA_real_]

# Keep only matches with exactly two rows per id (player/opponent perspectives)
id_counts <- t_players[, .N, by = id]
valid_ids <- id_counts[N == 2, id]

# One row per match id with resolved winner/loser codes and the normalized surface
M <- t_players[id %in% valid_ids,
               .(
                 tournament_start_dtm = tournament_start_dtm[1],
                 tournament_name      = tournament_name[1],
                 tournament_id        = tournament_id[1],
                 match_order          = match_order[1],
                 surface_norm         = na.omit(surface_norm)[1],
                 winner_code          = player_code[match_result == "win"][1],
                 loser_code           = player_code[match_result == "loss"][1]
               ),
               by = id
]
# Restrict to canonical surfaces
M <- M[surface_norm %in% surfaces]

# Participation table → two rows per match (winner/loser), in stable chronological order
P <- rbind(
  M[, .(id, player_code = winner_code, won = 1L, surface_norm,
        tournament_start_dtm, tournament_name, tournament_id, match_order)],
  M[, .(id, player_code = loser_code,  won = 0L, surface_norm,
        tournament_start_dtm, tournament_name, tournament_id, match_order)]
)
setorder(P, tournament_start_dtm, tournament_name, tournament_id, match_order, id)

# Pre-99 seeds (wins/matches) aligned by (player_code, surface_norm)
seed <- data.table(pre99_win_rates)  # columns: player_code, surface_norm, wins, matches
setnames(seed, c("wins", "matches"), c("seed_wins", "seed_matches"))
P <- seed[P, on = .(player_code, surface_norm)]
P[is.na(seed_wins),    seed_wins    := 0L]
P[is.na(seed_matches), seed_matches := 0L]

# Progressive counts BEFORE the current match (strictly prior)
P[, `:=`(
  cum_matches = seed_matches + shift(cumsum(1L),    type = "lag", fill = 0L),
  cum_wins    = seed_wins    + shift(cumsum(won),   type = "lag", fill = 0L)
), by = .(player_code, surface_norm)]

P[, rate_before := fifelse(cum_matches > 0, cum_wins / cum_matches, NA_real_)]

# Join back to the player-centric table (no reorder)
rates_by_player <- P[, .(id, player_code,  rate_before)]
rates_by_opp    <- copy(rates_by_player); setnames(rates_by_opp, "player_code", "opponent_code")

data.table::setindexv(t_players, c("id", "player_code"))
data.table::setindexv(t_players, c("id", "opponent_code"))

t_players[rates_by_player, on = .(id, player_code),
          player_win_rate_surface_progressive := i.rate_before]
t_players[rates_by_opp,    on = .(id, opponent_code),
          opponent_win_rate_surface_progressive := i.rate_before]

# Clean large temporaries
rm(M, P, seed, rates_by_player, rates_by_opp)

# ------------------------------------------------------------------------------------------
# 4) Inject match_score, infer best_of (3/5), and compute cumulative sets per tournament
# ------------------------------------------------------------------------------------------
# Bring match_score from the wide data file
data_jugadores     <- read.csv("data_jugadores_99-25.csv", stringsAsFactors = FALSE)
data_jugadores_sub <- data_jugadores[, c("id", "player_code", "match_score")]
setDT(data_jugadores_sub)

t_players <- data_jugadores_sub[t_players, on = .(id, player_code)]

# Place match_score right after match_result
match_result_pos <- which(names(t_players) == "match_result")
new_col_order <- c(
  names(t_players)[1:match_result_pos],
  "match_score",
  names(t_players)[(match_result_pos + 1):ncol(t_players)]
)
# Keep only the first "match_score" location
new_col_order <- new_col_order[new_col_order != "match_score" |
                                 seq_along(new_col_order) == (match_result_pos + 1)]
setcolorder(t_players, new_col_order)

# Helpers to parse set scores
count_sets_won <- function(score) {
  if (is.na(score) || score == "") return(NA)
  if (grepl("(W/O|RET|ABN)", score, ignore.case = TRUE)) return(NA)
  sets <- strsplit(score, " ")[[1]]
  wins <- 0
  for (s in sets) {
    s_clean <- gsub("\\(.*\\)", "", s)  # strip tiebreak markers
    n <- nchar(s_clean)
    if (n == 0) next
    if (n == 2) {
      winner_games <- as.numeric(substr(s_clean, 1, 1))
      loser_games  <- as.numeric(substr(s_clean, 2, 2))
    } else if (n == 3) {
      winner_games <- as.numeric(substr(s_clean, 1, 2))
      loser_games  <- as.numeric(substr(s_clean, 3, 3))
    } else if (n == 4) {
      winner_games <- as.numeric(substr(s_clean, 1, 2))
      loser_games  <- as.numeric(substr(s_clean, 3, 4))
    } else {
      winner_games <- as.numeric(substr(s_clean, 1, 2))
      loser_games  <- as.numeric(substr(s_clean, 3, n))
    }
    if (is.na(winner_games) || is.na(loser_games)) next
    if (winner_games > loser_games) wins <- wins + 1
  }
  wins
}
determine_best_of_from_score <- function(score) {
  wins <- count_sets_won(score)
  if (is.na(wins)) return(NA_integer_)
  if (wins == 2) return(3L)
  if (wins >= 3) return(5L)
  NA_integer_
}

# Default best_of: 5 for Grand Slams, else inferred from any valid score in that tournament
t_players[, best_of := ifelse(tournament_category == "gs", 5L, NA_integer_)]

non_gs_tournaments <- unique(t_players[is.na(best_of)]$tournament_id)

best_of_map <- list()
pb <- progress_bar$new(total = length(non_gs_tournaments),
                       format = "  Inferring best_of [:bar] :percent :eta")
for (tourney in non_gs_tournaments) {
  pb$tick()
  scores <- t_players[
    tournament_id == tourney & !is.na(match_score) &
      !grepl("(W/O|RET|ABN)", match_score, ignore.case = TRUE),
    match_score
  ]
  best_of_val <- NA_integer_
  for (score in scores) {
    best_of_candidate <- determine_best_of_from_score(score)
    if (!is.na(best_of_candidate)) { best_of_val <- best_of_candidate; break }
  }
  if (is.na(best_of_val)) best_of_val <- 3L
  best_of_map[[tourney]] <- best_of_val
}
# Assign inferred values to non-GS rows; fallback NAs to 3
t_players[is.na(best_of), best_of := best_of_map[tournament_id]]
t_players[is.na(best_of), best_of := 3L]

# Reposition best_of after match_result
match_result_pos <- which(names(t_players) == "match_result")
current_cols <- names(t_players)
current_cols <- current_cols[current_cols != "best_of"]
match_result_index <- which(current_cols == "match_result")
new_col_order <- c(
  current_cols[1:match_result_index],
  "best_of",
  current_cols[(match_result_index + 1):length(current_cols)]
)
setcolorder(t_players, new_col_order)

# Remove helper surface_norm (will recompute if needed later)
t_players$surface_norm <- NULL

# ------------------------------------------------------------------------------------------
# 5) Tournament workload features: sets played to-date (player/opponent)
# ------------------------------------------------------------------------------------------
t_players <- order_datasets((t_players))

get_sets_played <- function(score) {
  if (is.na(score) || score == "" || grepl("(W/O|RET|ABN)", score, ignore.case = TRUE)) return(0L)
  length(strsplit(score, " ")[[1]])
}

# Sets in this match, then running sum within (player_code, tournament_id)
t_players[, sets_in_match := sapply(match_score, get_sets_played)]

# Stable ordering across tournament timeline
t_players[, stadie_id := factor(stadie_id, levels = orden_fases, ordered = TRUE)]
t_players <- t_players[order(
  tournament_start_dtm,
  tournament_name,
  tournament_id,
  match_order,
  id
)]

# Cumulative sets *before* current match
t_players[,  cumulative_sets  := cumsum(sets_in_match), by = .(player_code,   tournament_id)]
t_players[,  cumulative_sets1 := cumsum(sets_in_match), by = .(opponent_code, tournament_id)]
t_players[,  player_sets_played_tournament   := cumulative_sets  - sets_in_match]
t_players[,  opponent_sets_played_tournament := cumulative_sets1 - sets_in_match]

# Drop temporaries
t_players[, c("sets_in_match", "cumulative_sets1") := NULL]

# ------------------------------------------------------------------------------------------
# Save
# ------------------------------------------------------------------------------------------
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)

# Quick sanity
mean(is.na(t_players$opponent_sets_played_tournament))
