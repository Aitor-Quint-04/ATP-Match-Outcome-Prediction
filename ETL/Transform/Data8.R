############################################################################################
# Recent-Form Features (Rolling Win Rates) + "Won Previous Tournament" Flags + Housekeeping
# ------------------------------------------------------------------------------------------
# Objective
#   Enrich a player-centric ATP dataset (1999–2025) with:
#     1) Leak-free rolling win-rate features over the last 5 and 10 matches per player,
#        *seeded* with pre-1999 (1968–1998) results from Jeff Sackmann to provide historical
#        continuity. These are computed on a unified chronological history and then lagged,
#        so each match only "sees" past information.
#     2) Opponent-mirrored rolling win-rate features (same logic for the opponent).
#     3) Momentum and trend features:
#          - momentum_diff_5 / momentum_diff_10
#          - player_trend / opponent_trend (short-term vs mid-term)
#          - consistency metrics (absolute short–mid difference)
#     4) Binary flags indicating whether a player/opponent arrives at this tournament
#        *after having won their previous tournament appearance*. This is computed by
#        reconstructing a unified timeline of player tournaments (pre-99 + 1999–2025),
#        finding each player’s last tournament before the current one, and checking if
#        they won that previous tournament (final-round winner).
#     5) Column ordering: enforce a consistent set of leading columns to ease inspection.
#
# Key Details / Guardrails
#   • "order_datasets()" imposes a stable, causal match ordering within tournaments.
#   • A synthetic "match_key" = paste(tournament_id, match_order) is used to map
#     per-row player features back into t_players without breaking 2-rows-per-match design.
#   • Rolling win rates are done with zoo::rollapplyr over the binary win_flag and then
#     *lagged one match* to prevent target leakage.
#   • Non-equi join (data.table) is used to find the immediate previous tournament per player.
#   • The script prints sanity stats and an example verification with Roger Federer.
#   • No modeling decisions are made here; this strictly prepares features.
############################################################################################

library(data.table)
library(zoo)
library(dplyr)

# ------------------------------------------------------------------
# I/O and basic setup
# ------------------------------------------------------------------
setwd("/home/aitor/Descargas/Project/Data/Msolonskyi")

# Player-centric dataset (two rows per match id: player/opponent perspectives)
t_players <- fread("pred_jugadores_99-25.csv")

# Historical matches (1968–1998) to seed rolling windows with older results
data_pre99 <- fread("/home/aitor/Descargas/Project/Data/JeffSackman/all_matches.csv")
data_pre99 <- data_pre99[year < 1999, ]  # 1968–1998

# Canonical round orders (post-99 and pre-99)
orden_fases        <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")
orden_fases_pre99  <- c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F")
data_pre99[, stadie_id_pre99 := factor(round, levels = orden_fases_pre99, ordered = TRUE)]

# Stable tournament ordering for deterministic, causal processing
order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # primary chronological sort
      tournament_name,       # tie-break within day
      tournament_id,         # group by tournament
      stadie_id,             # consistent round ordering
      match_order            # final tie-breaker inside each round
    )
}

t_players <- order_datasets(t_players)

# ------------------------------------------------------------------
# 1) Build unified chronological history and compute rolling win rates
# ------------------------------------------------------------------

# Prepare ordering helpers in t_players
t_players[, stadie_ord := as.integer(factor(stadie_id, levels = orden_fases, ordered = TRUE))]
t_players[, match_key  := paste(tournament_id, match_order, sep = "_")]  # 1 match_key per match row

# Minimal history from post-99 perspective
t_players_history <- t_players[, .(
  player_code,
  date       = as.Date(tournament_start_dtm),
  result     = match_result,
  match_key,
  stadie_ord,
  match_order
)]

# Pre-99 long format: winner/loser to rows with dates and ordered rounds
data_pre99[, date := as.Date(as.character(tourney_date), format = "%Y%m%d")]

data_pre99_long <- rbind(
  data_pre99[, .(
    player_code = winner_code,
    result      = "win",
    date,
    stadie_ord  = as.integer(stadie_id_pre99),
    match_key   = NA_character_,
    match_order = NA_integer_
  )],
  data_pre99[, .(
    player_code = loser_code,
    result      = "loss",
    date,
    stadie_ord  = as.integer(stadie_id_pre99),
    match_key   = NA_character_,
    match_order = NA_integer_
  )]
)

# Merge pre-99 + post-99, then strictly order within player timeline
full_history <- rbindlist(list(data_pre99_long, t_players_history), use.names = TRUE, fill = TRUE)
setorder(full_history, player_code, date, stadie_ord, match_order, match_key)

# Binary flag per row → rolling mean over last N matches, then lag(1) to avoid leakage
full_history[, win_flag := ifelse(result == "win", 1, 0)]

full_history[, player_win_ratio_last_5_matches :=
               rollapplyr(win_flag, width = 5,  FUN = mean, fill = NA, align = "right", partial = TRUE),
             by = player_code]

full_history[, player_win_ratio_last_10_matches :=
               rollapplyr(win_flag, width = 10, FUN = mean, fill = NA, align = "right", partial = TRUE),
             by = player_code]

# Causality: push the computed ratios back one match so current row does not see itself
full_history[, player_win_ratio_last_5_matches  := shift(player_win_ratio_last_5_matches,  n = 1, type = "lag"),
             by = player_code]
full_history[, player_win_ratio_last_10_matches := shift(player_win_ratio_last_10_matches, n = 1, type = "lag"),
             by = player_code]

# Keep only rows that correspond to t_players (have match_key)
full_history_tplayers <- full_history[!is.na(match_key), ]
full_history_tplayers <- unique(full_history_tplayers, by = c("match_key", "player_code"))

# Join player-side rolling features back to t_players on (match_key, player_code)
t_players <- merge(
  t_players,
  full_history_tplayers[, .(match_key, player_code, player_win_ratio_last_5_matches, player_win_ratio_last_10_matches)],
  by = c("match_key", "player_code"),
  all.x = TRUE
)

# Build opponent-side features by renaming player_code → opponent_code and joining
opponent_ratios <- full_history_tplayers[, .(
  match_key,
  opponent_code = player_code,
  opponent_win_ratio_last_5_matches  = player_win_ratio_last_5_matches,
  opponent_win_ratio_last_10_matches = player_win_ratio_last_10_matches
)]
opponent_ratios <- unique(opponent_ratios, by = c("match_key", "opponent_code"))

t_players <- merge(
  t_players,
  opponent_ratios,
  by = c("match_key", "opponent_code"),
  all.x = TRUE
)

# Housekeeping: match_key was only needed for joins
t_players[, match_key := NULL]

# Sanity check: no unexpected duplication
cat("Número de filas en t_players:", nrow(t_players), "\n")
cat("Número de filas únicas:",      nrow(unique(t_players)), "\n")
if (nrow(t_players) != nrow(unique(t_players))) {
  warning("¡Hay filas duplicadas en el dataset final!")
}

t_players <- order_datasets(t_players)

# ------------------------------------------------------------------
# 2) Momentum & trend features from rolling win rates
# ------------------------------------------------------------------

# Player vs opponent short/medium horizon differences
t_players[, momentum_diff_5  := player_win_ratio_last_5_matches  - opponent_win_ratio_last_5_matches]
t_players[, momentum_diff_10 := player_win_ratio_last_10_matches - opponent_win_ratio_last_10_matches]

# Trend = short-term minus mid-term (positive ⇒ improving)
t_players[, player_trend   := player_win_ratio_last_5_matches   - player_win_ratio_last_10_matches]
t_players[, opponent_trend := opponent_win_ratio_last_5_matches - opponent_win_ratio_last_10_matches]

# Simple “good form” flags (tunable thresholds)
t_players[, player_good_form_5    := as.integer(player_win_ratio_last_5_matches    > 0.7)]
t_players[, player_good_form_10   := as.integer(player_win_ratio_last_10_matches   > 0.7)]
t_players[, opponent_good_form_5  := as.integer(opponent_win_ratio_last_5_matches  > 0.7)]
t_players[, opponent_good_form_10 := as.integer(opponent_win_ratio_last_10_matches > 0.7)]

# Consistency = absolute gap between short and mid horizons
t_players[, player_consistency   := abs(player_win_ratio_last_5_matches   - player_win_ratio_last_10_matches)]
t_players[, opponent_consistency := abs(opponent_win_ratio_last_5_matches - opponent_win_ratio_last_10_matches)]

##############################################################################################
# 3) “Won previous tournament” flags (player/opponent)
##############################################################################################

t_players <- order_datasets(t_players)

# Tournament winners (post-99)
tournament_winners_tplayers <- t_players[stadie_id == "F" & match_result == "win",
                                         .(player_code, tournament_id, tournament_start_dtm)]

# Tournament winners (pre-99)
data_pre99[, tournament_start_dtm := as.Date(as.character(tourney_date), format = "%Y%m%d")]
data_pre99_winners <- data_pre99[round == "F",
                                 .(player_code = winner_code,
                                   tournament_id = as.character(tourney_id),
                                   tournament_start_dtm)]

tournament_winners <- unique(rbind(tournament_winners_tplayers, data_pre99_winners))

# All player–tournament participations (pre-99 + post-99)
player_tournaments_pre99 <- data_pre99[, .(
  player_code = c(winner_code, loser_code),
  tournament_id = as.character(tourney_id),
  tournament_start_dtm
)]
player_tournaments_tplayers <- unique(t_players[, .(
  player_code, tournament_id, tournament_start_dtm
)])
all_player_tournaments <- unique(rbind(player_tournaments_pre99, player_tournaments_tplayers))

# For each (player, current tournament) find their immediately previous tournament
setorder(all_player_tournaments, player_code, tournament_start_dtm)
all_player_tournaments[, join_time := tournament_start_dtm]  # explicit key for readability

previous_tournaments <- all_player_tournaments[
  all_player_tournaments,
  on = .(player_code, tournament_start_dtm < tournament_start_dtm),
  mult = "last",
  .(player_code,
    current_tournament_id  = i.tournament_id,
    previous_tournament_id = x.tournament_id,
    previous_tournament_date = x.tournament_start_dtm)
]

# Mark if the previous tournament was won
previous_tournaments <- merge(
  previous_tournaments,
  tournament_winners[, .(player_code, tournament_id, won_tournament = 1)],
  by.x = c("player_code", "previous_tournament_id"),
  by.y = c("player_code", "tournament_id"),
  all.x = TRUE
)
previous_tournaments[is.na(won_tournament), won_tournament := 0]

# Attach to main table (player side)
t_players <- merge(
  t_players,
  previous_tournaments[, .(player_code, current_tournament_id, won_tournament)],
  by.x = c("player_code", "tournament_id"),
  by.y = c("player_code", "current_tournament_id"),
  all.x = TRUE
)
t_players[is.na(won_tournament), won_tournament := 0]
setnames(t_players, "won_tournament", "player_won_previous_tournament")

# Opponent side: reuse same structure with renamed keys
setnames(previous_tournaments,
         c("player_code", "won_tournament"),
         c("opponent_code", "opponent_won_tournament"))

t_players <- merge(
  t_players,
  previous_tournaments[, .(opponent_code, current_tournament_id, opponent_won_tournament)],
  by.x = c("opponent_code", "tournament_id"),
  by.y = c("opponent_code", "current_tournament_id"),
  all.x = TRUE
)

t_players <- order_datasets(t_players)

t_players[is.na(opponent_won_tournament), opponent_won_tournament := 0]
setnames(t_players, "opponent_won_tournament", "opponent_won_previous_tournament")

# Quick distributions
cat("Distribución de player_won_previous_tournament:\n");   print(table(t_players$player_won_previous_tournament))
cat("Distribución de opponent_won_previous_tournament:\n"); print(table(t_players$opponent_won_previous_tournament))

# Example check with Roger Federer
roger_federer_code <- t_players[player_name == "Roger Federer", player_code][1]
cat("Código de Roger Federer:", roger_federer_code, "\n")

federer_wins <- t_players[player_code == roger_federer_code & stadie_id == "F" & match_result == "win",
                          .(tournament_id, tournament_name, tournament_start_dtm, match_result)]
cat("Torneos ganados por Federer (finales):\n"); print(federer_wins)

basel_2019 <- federer_wins[tournament_start_dtm == as.Date("2019-10-21")]
cat("\nTorneo de Basel 2019:\n"); print(basel_2019)

next_tournament <- t_players[player_code == roger_federer_code &
                               tournament_start_dtm > as.Date("2019-10-21"),
                             .(tournament_id, tournament_name, tournament_start_dtm,
                               player_won_previous_tournament)][1]
cat("\nSiguiente torneo de Federer después de Basel 2019:\n"); print(next_tournament)

if (nrow(next_tournament) > 0) {
  cat("\n¿Federer venía de ganar el torneo anterior? (player_won_previous_tournament):",
      next_tournament$player_won_previous_tournament, "\n")
  if (next_tournament$player_won_previous_tournament == 1) {
    cat("✓ La variable está correctamente configurada como 1\n")
  } else {
    cat("✗ La variable debería ser 1 pero es", next_tournament$player_won_previous_tournament, "\n")
    cat("\nDepuración - Torneos de Federer alrededor de Basel 2019:\n")
    federer_tournaments <- all_player_tournaments[player_code == roger_federer_code &
                                                    tournament_start_dtm <= as.Date("2019-10-21")]
    setorder(federer_tournaments, -tournament_start_dtm)
    print(federer_tournaments)
  }
} else {
  cat("No se encontró un torneo posterior para Federer\n")
}

# ------------------------------------------------------------------
# 4) Column ordering: bring key identifiers to the front (fails fast if missing)
# ------------------------------------------------------------------
t_players_df <- as.data.frame(t_players)
all_cols     <- names(t_players_df)

first_cols <- c("id", "tournament_id", "year", "player_code", "player_name",
                "stadie_id", "match_order", "player_citizenship", "player_age",
                "opponent_code", "opponent_name")

missing_cols <- setdiff(first_cols, all_cols)
if (length(missing_cols) > 0) {
  stop("Las siguientes columnas no existen en el dataset: ", paste(missing_cols, collapse = ", "))
}

other_cols <- setdiff(all_cols, first_cols)
new_order  <- c(first_cols, other_cols)

t_players_df <- t_players_df[, new_order]
t_players    <- as.data.table(t_players_df)
t_players    <- order_datasets(t_players)

# Final quick check and write
table(t_players$opponent_won_previous_tournament)
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
