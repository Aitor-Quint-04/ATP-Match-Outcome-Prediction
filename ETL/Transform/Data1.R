## ================================================================
# Player-centric dataset builder for ATP matches (1999–2025)
# NOTE: We also create a separate file with raw per-match gameplay statistics
# (e.g., aces, serve/return splits, points won, etc.) and keep it out of the
# main modeling dataset because the very large number of features is not
# immediately relevant to prediction. This companion file is preserved for
# later use to compute historical/rolling statistics and richer aggregates.
# - Reads all_matches_99-25.csv (match-level, two players per row)
# - Produces a player-centric table with one row per player per match
# - Writes a dedicated match-stats artifact (e.g., match_stats_99-25.csv)
#   that contains the per-match gameplay metrics
# - Enriches with historical counts (<1999) if a Sackmann CSV is present
# - Filters to players with > THRESHOLD_MIN_MATCHES total matches (OPTIONAL)
#   • Improves robustness of features by removing very small samples
#   • BUT drops valuable information about rookies/rare players
#   → Left commented out below; enable if you prefer stability > coverage
# - Writes:
#     - pred_jugadores_99-25.csv (player-centric, optionally filtered)
#     - data_jugadores_99-25.csv (player-centric, optionally filtered, full columns)
#     - match_stats_99-25.csv (raw per-match gameplay stats for later FE)
# ================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# -----------------------------
# Config
# -----------------------------
INPUT_MATCHES_CSV    <- "all_matches_99-25.csv"
INPUT_HISTORICAL_CSV <- ""  # optional
#IMPORTANT: NOW ON I WILL USE THIS HISTORICAL CSV (WHICH IS EXTRACTED FROM THE JEFF SACKMAN HISTORICAL DATASET)
#TO USE IT AS SEEDING FOR THE FEATURES AND HAVE SOME INITIAL VALUES FOR THEM. IF YOU ARE ABLE TO SCRAPE ALL THE DATA
#ACROSS THE HISTORY IN THE ATP WEB Y REALLY RECOMMEND YOU TO READ CAREFULLY THE CODES AND CHANGE THE PRE-SEEDING FOR YOUR OWN SCRAPPED DATA.
THRESHOLD_MIN_MATCHES <- 20L  # threshold for OPTIONAL low-sample filtering

OUT_PLAYER_PRED <- "pred_jugadores_99-25.csv"
OUT_PLAYER_DATA <- "data_jugadores_99-25.csv"

# -----------------------------
# Helpers
# -----------------------------

# Derive year from 'tournament_id' when a dedicated 'year' column is not provided.
derive_year_from_tournament_id <- function(tournament_id) {
  # Expecting IDs like "YYYY-CODE" or "YYYY-<something>"
  suppressWarnings(as.integer(sub("-.*", "", tournament_id)))
}

# Safely rename columns by regex; only affects present columns.
safe_rename_with <- function(df, pattern, replacement) {
  cols <- grep(pattern, names(df), value = TRUE)
  if (length(cols) == 0) return(df)
  rename(df, !!!setNames(cols, sub(pattern, replacement, cols)))
}

# -----------------------------
# 1) Read base matches
# -----------------------------
stopifnot(file.exists(INPUT_MATCHES_CSV))
t <- read.csv(INPUT_MATCHES_CSV, check.names = FALSE)

# Ensure key identifiers exist
if (!"id" %in% names(t)) stop("Column 'id' is required in all_matches_99-25.csv.")
if (!"tournament_id" %in% names(t)) stop("Column 'tournament_id' is required in all_matches_99-25.csv.")

# If no 'year' column, derive it from 'tournament_id'
if (!"year" %in% names(t)) {
  t$year <- derive_year_from_tournament_id(t$tournament_id)
}

# -----------------------------
# 2) Build player-centric view
# -----------------------------
# Winner perspective → player_, Opponent ← opponent_
t_win <- t %>%
  safe_rename_with("^(win_|winner_)",    "player_")   %>%
  safe_rename_with("^(los_|loser_)",     "opponent_") %>%
  mutate(match_result = "win")

# Loser perspective → player_, Opponent ← opponent_
t_los <- t %>%
  safe_rename_with("^(los_|loser_)",     "player_")   %>%
  safe_rename_with("^(win_|winner_)",    "opponent_") %>%
  mutate(match_result = "loss")

# Stack both perspectives
t_players <- bind_rows(t_win, t_los)

# If player/opponent names are not present, fall back to codes to avoid joins here.
if (!"player_name" %in% names(t_players) && "player_code" %in% names(t_players)) {
  t_players <- t_players %>% mutate(player_name = player_code)
}
if (!"opponent_name" %in% names(t_players) && "opponent_code" %in% names(t_players)) {
  t_players <- t_players %>% mutate(opponent_name = opponent_code)
}

# Order rows for stability
t_players <- t_players %>%
  arrange(id, dplyr::across(dplyr::any_of(c("player_code", "opponent_code"))))

# Preferred column order (only those that exist will be placed up front)
preferred_front <- c("id", "tournament_id", "year", "stadie_id", "match_result",
                     "player_code", "player_name", "opponent_code", "opponent_name")
front <- intersect(preferred_front, names(t_players))
rest  <- setdiff(names(t_players), front)
t_players <- t_players %>% select(dplyr::all_of(c(front, rest)))

# -----------------------------
# 3) Drop lightweight, non-essential columns (if present)
# -----------------------------
cols_to_remove <- c("match_score", "match_ret", "stats_url")  # 'match_score' may not exist; 'score' is kept
t_players <- t_players %>% select(-dplyr::any_of(cols_to_remove))

# -----------------------------
# 4) Separate current-match stats (optional)
# -----------------------------
match_stats_cols <- c(
  "player_sets_won", "opponent_sets_won",
  "player_games_won", "opponent_games_won",
  "player_tiebreaks_won", "opponent_tiebreaks_won",
  "player_aces", "opponent_aces",
  "player_double_faults", "opponent_double_faults",
  "player_first_serves_in", "opponent_first_serves_in",
  "player_first_serves_total", "opponent_first_serves_total",
  "player_first_serve_points_won", "opponent_first_serve_points_won",
  "player_first_serve_points_total", "opponent_first_serve_points_total",
  "player_second_serve_points_won", "opponent_second_serve_points_won",
  "player_second_serve_points_total", "opponent_second_serve_points_total",
  "player_break_points_saved", "opponent_break_points_saved",
  "player_break_points_serve_total", "opponent_break_points_serve_total",
  "player_service_points_won", "opponent_service_points_won",
  "player_service_points_total", "opponent_service_points_total",
  "player_first_serve_return_won", "opponent_first_serve_return_won",
  "player_first_serve_return_total", "opponent_first_serve_return_total",
  "player_second_serve_return_won", "opponent_second_serve_return_won",
  "player_second_serve_return_total", "opponent_second_serve_return_total",
  "player_break_points_converted", "opponent_break_points_converted",
  "player_break_points_return_total", "opponent_break_points_return_total",
  "player_service_games_played", "opponent_service_games_played",
  "player_return_games_played", "opponent_return_games_played",
  "player_return_points_won", "opponent_return_points_won",
  "player_return_points_total", "opponent_return_points_total",
  "player_total_points_won", "opponent_total_points_won",
  "player_total_points_total", "opponent_total_points_total",
  "player_winners", "opponent_winners",
  "player_forced_errors", "opponent_forced_errors",
  "player_unforced_errors", "opponent_unforced_errors",
  "player_net_points_won", "opponent_net_points_won",
  "player_net_points_total", "opponent_net_points_total",
  "player_fastest_first_serves_kmh", "opponent_fastest_first_serves_kmh",
  "player_average_first_serves_kmh", "opponent_average_first_serves_kmh",
  "player_fastest_second_serve_kmh", "opponent_fastest_second_serve_kmh",
  "player_average_second_serve_kmh", "opponent_average_second_serve_kmh"
)

present_stat_cols <- intersect(match_stats_cols, names(t_players))
match_stats <- if (length(present_stat_cols)) t_players[, present_stat_cols, drop = FALSE] else NULL
t_players   <- t_players %>% select(-dplyr::any_of(present_stat_cols))

# Keep a copy before OPTIONAL filtering (full column set)
t_data <- t_players

# ================================================================
# Historical enrichment and OPTIONAL filtering by total matches
# ================================================================

# 5) Read pre-1999 historical (optional). If not available, proceed without it.
historical_counts <- tibble(code = character(), name = character(), partidos_historicos = integer())

if (file.exists(INPUT_HISTORICAL_CSV)) {
  matches_pre_all <- read.csv(INPUT_HISTORICAL_CSV, check.names = FALSE)
  if (!"year" %in% names(matches_pre_all)) {
    warning("Historical CSV does not contain 'year'; skipping historical enrichment.")
  } else {
    matches_pre99 <- matches_pre_all %>% filter(.data$year < 1999)
    # Expecting winner_code/loser_code & winner_name/loser_name; if names missing, fallback to codes
    w <- matches_pre99 %>%
      transmute(code = .data$winner_code,
                name = dplyr::coalesce(.data$winner_name, .data$winner_code))
    l <- matches_pre99 %>%
      transmute(code = .data$loser_code,
                name = dplyr::coalesce(.data$loser_name, .data$loser_code))
    historical_counts <- bind_rows(w, l) %>%
      group_by(code, name) %>%
      summarise(partidos_historicos = n(), .groups = "drop")
  }
} else {
  message("⚠ Historical CSV not found: skipping pre-1999 enrichment -> ", INPUT_HISTORICAL_CSV)
}

# 6) Recent counts in current player-centric table
recent_counts <- t_players %>%
  group_by(player_code, player_name) %>%
  summarise(partidos_recientes = n(), .groups = "drop") %>%
  rename(code = player_code, name = player_name)

# 7) Merge historical + recent, compute totals
total_counts <- full_join(historical_counts, recent_counts, by = c("code", "name")) %>%
  mutate(
    partidos_historicos = tidyr::replace_na(partidos_historicos, 0L),
    partidos_recientes  = tidyr::replace_na(partidos_recientes,  0L),
    total_partidos = partidos_historicos + partidos_recientes
  ) %>%
  arrange(total_partidos)

# 8) Descriptive stats for the small-sample group (≤ THRESHOLD)
players_low_n <- total_counts %>%
  filter(total_partidos <= THRESHOLD_MIN_MATCHES)

cat("=== Players with ≤ ", THRESHOLD_MIN_MATCHES, " total matches ===\n", sep = "")
cat("- Players affected:", nrow(players_low_n), "\n")
cat("- Share of all players:",
    if (nrow(total_counts) > 0) round(nrow(players_low_n) / nrow(total_counts) * 100, 1) else 0, "%\n")
if (nrow(players_low_n)) {
  cat("- Min matches:", min(players_low_n$total_partidos, na.rm = TRUE), "\n")
  cat("- Max (within group):", max(players_low_n$total_partidos, na.rm = TRUE), "\n\n")
}

# ----------------------------------------------------------------
# OPTIONAL FILTERING (commented out by default)
# Trade-off:
#   + Improves feature stability by removing tiny-sample players
#   − Loses potentially important signal about rookies/rare players
# Enable if you prefer stability > coverage:
# ----------------------------------------------------------------
# valid_players <- total_counts %>%
#   filter(total_partidos > THRESHOLD_MIN_MATCHES) %>%
#   pull(code)
#
# t_players <- t_players %>%
#   filter(player_code %in% valid_players,
#          opponent_code %in% valid_players)
#
# t_data <- t_data %>%
#   filter(player_code %in% valid_players,
#          opponent_code %in% valid_players)

# 9) Dataset diagnostics (after optional filtering, if applied)
cat("=== Dataset summary (after optional filtering, if applied) ===\n")
cat("- Unique players:", dplyr::n_distinct(t_players$player_code), "\n")
cat("- Rows in t_players:", nrow(t_players), "\n")
cat("- Unique matches:", dplyr::n_distinct(t_players$id), "\n\n")

players_dist <- t_players %>%
  left_join(total_counts, by = c("player_code" = "code", "player_name" = "name")) %>%
  group_by(player_code, player_name) %>%
  summarise(
    partidos_recientes = n(),
    partidos_historicos = dplyr::first(partidos_historicos),
    total_partidos = dplyr::first(total_partidos),
    .groups = "drop"
  )

if (nrow(players_dist)) {
  cat("Min total matches per player:", min(players_dist$total_partidos, na.rm = TRUE), "\n")
  cat("Median total matches per player:", stats::median(players_dist$total_partidos, na.rm = TRUE), "\n")
}

# -----------------------------
# 10) Write outputs
# -----------------------------
write.csv(t_players, OUT_PLAYER_PRED, row.names = FALSE)
write.csv(t_data,    OUT_PLAYER_DATA, row.names = FALSE)

cat("✔ Written:\n - ", OUT_PLAYER_PRED, "\n - ", OUT_PLAYER_DATA, "\n", sep = "")
