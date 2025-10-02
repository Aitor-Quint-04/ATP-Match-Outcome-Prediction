# =============================================================================
# ATP Player Dataset — Historical ATP Ranking Enrichment (1999–2025)
# -----------------------------------------------------------------------------
# What this script does:
#   1) Reads a player-centric matches dataset (two perspectives per match).
#   2) Reads a directory of historical ranking snapshots (CSV per date).
#   3) For each match row, attaches the player’s and opponent’s ATP ranking
#      as of the day BEFORE the tournament start (no look-ahead).
#   4) Initializes each player’s/opponent’s “career-best ATP ranking to date”
#      using either:
#         - Their best pre-1999 ranking between [turned_pro, 1998], OR
#         - Their ranking at first appearance in the 1999–2025 data (fallback).
#   5) Updates a cumulative “best-so-far” ranking per row (monotone non-increasing).
#   6) Performs sanity checks (first-appearance initialization and monotony).
#   7) Writes the enriched dataset back to disk.
#
# Implementation notes:
#   • data.table is used for efficient rolling joins on dates and cumulative logic.
#   • Round order is enforced to guarantee deterministic within-tournament ordering.
#   • Pre-1999 best ranking computation never looks into the future relative to
#     turned_pro and the 1999 cutoff.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(data.table)
})

# -----------------------------
# Round ordering (draw phases)
# -----------------------------
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

# dplyr-friendly ordering for data.frames
order_datasets_df <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # chronological primary key
      tournament_name,       # tie-breaker by tournament name
      tournament_id,         # group within tournament
      stadie_id,             # within-tournament phase order
      match_order
    )
}

# data.table-friendly ordering (in-place)
order_datasets_dt <- function(DT) {
  DT[, stadie_id := factor(stadie_id, levels = orden_fases, ordered = TRUE)]
  setorder(DT, tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order)
  invisible(DT)
}

# -----------------------------
# 1) Load your player-centric dataset
# -----------------------------
setwd("")
t_players <- read.csv("pred_jugadores_99-25.csv", stringsAsFactors = FALSE, check.names = FALSE)

# Convert to data.table and ensure types
t_players_dt <- as.data.table(t_players)
t_players_dt[, tournament_start_dtm := as.Date(tournament_start_dtm)]
t_players_dt[, player_code   := as.character(player_code)]
t_players_dt[, opponent_code := as.character(opponent_code)]
t_players_dt[, stadie_ord := match(stadie_id, orden_fases)]

# For ranking lookup we use the day BEFORE the event starts (strictly past info)
t_players_dt[, date_for_rank := tournament_start_dtm - 1L]

# -----------------------------
# 2) Read ALL ranking snapshots from a folder
#     Expect files like: rankings_YYYY-MM-DD.csv
# -----------------------------
#Another extra-scrapping documented in the repositorie ;)

rankings_path <- "Scrapping de Rankings/rankings csv"
rank_files <- list.files(
  path = rankings_path,
  pattern = "^rankings_\\d{4}-\\d{2}-\\d{2}\\.csv$",
  full.names = TRUE
)

# Helper: normalize the ranking column name to 'ranking'
detect_and_rename_rank_col <- function(DT) {
  rank_candidates <- c("player_atp_ranking", "atp_rank", "player_rank", "ranking", "rank")
  hit <- intersect(rank_candidates, names(DT))
  if (length(hit) == 0L) {
    stop("No ranking column found in a rankings file.")
  }
  setnames(DT, hit[1], "ranking")
  invisible(DT)
}

# Load all ranking files, enforce schema, attach snapshot_date
rankings_list <- lapply(rank_files, function(f) {
  dt <- fread(f, stringsAsFactors = FALSE)
  if (!"player_code" %in% names(dt)) {
    stop(sprintf("File %s is missing column 'player_code'.", basename(f)))
  }
  dt[, player_code := as.character(player_code)]
  detect_and_rename_rank_col(dt)
  date_str <- sub("^rankings_(\\d{4}-\\d{2}-\\d{2})\\.csv$", "\\1", basename(f))
  dt[, snapshot_date := as.Date(date_str)]
  dt[, .(player_code, ranking, snapshot_date)]
})

# Stack and index
rankings_dt <- rbindlist(rankings_list, use.names = TRUE)
setorder(rankings_dt, player_code, snapshot_date)
setkey(rankings_dt, player_code, snapshot_date)

# -----------------------------
# 3) Rolling join rankings for player and opponent (strictly <= day-before)
# -----------------------------
player_join <- rankings_dt[
  t_players_dt[, .(player_code, date_for_rank)],
  on   = .(player_code, snapshot_date = date_for_rank),
  roll = Inf,                 # carry last observation backward in time
  mult = "last"
][, .(player_atp_ranking = ranking)]

opponent_join <- rankings_dt[
  t_players_dt[, .(player_code = opponent_code, date_for_rank)],
  on   = .(player_code, snapshot_date = date_for_rank),
  roll = Inf,
  mult = "last"
][, .(opponent_atp_ranking = ranking)]

# Attach as new columns
t_players_dt[, player_atp_ranking   := player_join$player_atp_ranking]
t_players_dt[, opponent_atp_ranking := opponent_join$opponent_atp_ranking]

# Quick diagnostic (optional)
cat(sprintf("NA rate in opponent_atp_ranking: %.2f%%\n",
            mean(is.na(t_players_dt$opponent_atp_ranking)) * 100))

# --------------------------------------------------------------------
# SOLO PLAYER SECTION — Career-best ATP ranking (no look-ahead)
# --------------------------------------------------------------------

# Ensure types
t_players_dt[, `:=`(
  tournament_start_dtm = as.Date(tournament_start_dtm),
  player_code          = as.character(player_code),
  player_turned_pro    = as.integer(player_turned_pro)
)]

# 1) Keep valid rankings and compute 'best_so_far' per snapshot (global, not used directly later)
rankings_dt <- rankings_dt[!is.na(ranking) & ranking >= 1L]
setorder(rankings_dt, player_code, snapshot_date)
rankings_dt[, best_so_far := cummin(ranking), by = player_code]
setkey(rankings_dt, player_code, snapshot_date)

# 2) Prepare row-wise reference date and an explicit row id
t_players_dt[, date_for_rank := as.Date(tournament_start_dtm) - 1L]
t_players_dt[, row_id := .I]

# 3) If you want the global best-so-far up to that date (not used later, but illustrative)
best_join <- rankings_dt[
  t_players_dt[, .(player_code, date_for_rank, row_id)],
  on = .(player_code, snapshot_date = date_for_rank),
  roll = Inf, mult = "last"
][, .(row_id, best_so_far_upto_date = best_so_far)]

setkey(best_join, row_id)
t_players_dt <- best_join[t_players_dt, on = .(row_id)]

# 4) Stable ordering and first appearance flag per player
t_players_dt[, stadie_ord := match(stadie_id, orden_fases)]
order_datasets_dt(t_players_dt)
setorder(t_players_dt, player_code, tournament_start_dtm, stadie_ord, match_order, id)
t_players_dt[, is_first_appearance_player := seq_len(.N) == 1L, by = player_code]

# 4.b) Compute best pre-1999 ranking in [turned_pro, 1998] (inclusive)
# Clean plausible turned_pro for pre-1999 path
t_players_dt[
  , player_turned_pro_clean := fifelse(!is.na(player_turned_pro) &
                                         player_turned_pro >= 1900 & player_turned_pro < 1999,
                                       player_turned_pro, NA_integer_)
]
players_tp <- unique(t_players_dt[, .(player_code, player_turned_pro_clean)])

# Add a snapshot year column for filtering
rank_pre1999 <- copy(rankings_dt)
rank_pre1999[, snapshot_year := as.integer(format(snapshot_date, "%Y"))]
rank_pre1999 <- rank_pre1999[snapshot_year < 1999]

# Join the turned_pro window and restrict to [turned_pro, 1998]
rank_pre1999 <- merge(rank_pre1999, players_tp, by = "player_code", all.x = TRUE)
rank_pre1999 <- rank_pre1999[
  !is.na(player_turned_pro_clean) & snapshot_year >= player_turned_pro_clean
]

# Best pre-1999 ranking per player (lower is better)
pre1999_best <- rank_pre1999[, .(best_pre1999 = min(ranking, na.rm = TRUE)), by = player_code]
setkey(pre1999_best, player_code)

# 5) Initialization rules at first appearance
#    a) If turned_pro < 1999 and we have pre-1999 rankings → use best_pre1999
t_players_dt[
  is_first_appearance_player == TRUE & !is.na(player_turned_pro_clean),
  player_initial_highest := pre1999_best[.SD, on = .(player_code), x.best_pre1999]
]

#    b) Otherwise → use ranking at first appearance
t_players_dt[
  is_first_appearance_player == TRUE & is.na(player_initial_highest),
  player_initial_highest := player_atp_ranking
]

# 6) Accumulate “best-so-far” ranking per player across matches (monotone non-increasing)
t_players_dt[
  , player_highest_atp_ranking := {
    r <- player_atp_ranking               # observed ranking at each match date (may be NA)
    init <- player_initial_highest[1L]    # initialized at first appearance
    acc <- vector("integer", length(r))
    acc[1L] <- init
    if (length(r) > 1L) {
      for (k in 2:length(r)) {
        acc[k] <- if (is.na(r[k])) acc[k-1L] else min(acc[k-1L], r[k], na.rm = TRUE)
      }
    }
    acc
  },
  by = player_code
]

# 7) Checks (player)
check_monotony <- function(v) {
  vv <- data.table::nafill(v, type = "locf")
  if (all(is.na(vv))) return(TRUE)
  all(diff(vv) <= 0, na.rm = TRUE)
}

# 7.1 First appearance: expected vs computed
player_first <- t_players_dt[
  is_first_appearance_player == TRUE,
  .(player_code, player_name, player_turned_pro, player_atp_ranking, player_highest_atp_ranking)
]
player_first <- merge(player_first, pre1999_best, by = "player_code", all.x = TRUE)

player_first[, expected_initial :=
               fifelse(!is.na(player_turned_pro) & player_turned_pro < 1999 & !is.na(best_pre1999),
                       best_pre1999,
                       player_atp_ranking)
]

player_init_mismatches <- player_first[
  !( (is.na(expected_initial) & is.na(player_highest_atp_ranking)) |
       (!is.na(expected_initial) & expected_initial == player_highest_atp_ranking) )
]

cat(sprintf("PLAYER ▶ first-appearance init mismatches: %d\n", nrow(player_init_mismatches)))
if (nrow(player_init_mismatches) > 0) {
  cat("Examples (max 10):\n")
  print(head(player_init_mismatches[
    , .(player_code, player_name, player_turned_pro,
        expected_initial,
        computed = player_highest_atp_ranking,
        first_appearance_rank = player_atp_ranking)
  ], 10))
}

# 7.2 Monotony
player_mono <- t_players_dt[
  , .(ok_monotony = check_monotony(player_highest_atp_ranking)), by = player_code
]
n_bad <- sum(!player_mono$ok_monotony)
cat(sprintf("PLAYER ▶ monotony violations: %d\n", n_bad))

# 7.3 Trace a random player (10 rows)
set.seed(123)
if (n_bad > 0) {
  pick_code <- sample(player_mono[ok_monotony == FALSE, player_code], 1L)
  cat(sprintf("Trace (violating) player_code = %s (first 10 rows):\n", pick_code))
} else {
  pick_code <- sample(unique(t_players_dt$player_code), 1L)
  cat(sprintf("Trace (random OK) player_code = %s (first 10 rows):\n", pick_code))
}
print(
  t_players_dt[player_code == pick_code,
               .(player_code, player_name, tournament_start_dtm,
                 player_atp_ranking, player_highest_atp_ranking)]
  [order(tournament_start_dtm)][1:10]
)

# Clean temporary columns (player side)
t_players_dt[, c("is_first_appearance_player",
                 "player_initial_highest",
                 "row_id",
                 "player_turned_pro_clean") := NULL]
order_datasets_dt(t_players_dt)

# --------------------------------------------------------------------
# SOLO OPPONENT SECTION — Career-best ATP ranking for opponents
# --------------------------------------------------------------------

# Ensure types
t_players_dt[, `:=`(
  opponent_code       = as.character(opponent_code),
  opponent_turned_pro = as.integer(opponent_turned_pro)
)]

# 1) Pre-1999 windows for opponents
opps_tp <- unique(t_players_dt[, .(opponent_code, opponent_turned_pro)])
opps_tp[, opponent_turned_pro_clean :=
          fifelse(!is.na(opponent_turned_pro) & opponent_turned_pro >= 1900 & opponent_turned_pro < 1999,
                  opponent_turned_pro, NA_integer_)]

# Reuse rankings_dt with a snapshot_year helper
rank_pre1999_opp <- copy(rankings_dt)
rank_pre1999_opp[, snapshot_year := as.integer(format(snapshot_date, "%Y"))]
rank_pre1999_opp <- merge(
  rank_pre1999_opp,
  opps_tp[, .(player_code = opponent_code, opponent_turned_pro_clean)],
  by = "player_code", all.x = TRUE
)
rank_pre1999_opp <- rank_pre1999_opp[
  !is.na(opponent_turned_pro_clean) &
    snapshot_year < 1999 &
    snapshot_year >= opponent_turned_pro_clean
]

pre1999_best_opp <- rank_pre1999_opp[
  , .(best_pre1999 = min(ranking, na.rm = TRUE)), by = player_code
]
setnames(pre1999_best_opp, "player_code", "opponent_code")
setkey(pre1999_best_opp, opponent_code)

# 2) First appearance flag per opponent
t_players_dt[, stadie_ord := match(stadie_id, orden_fases)]
order_datasets_dt(t_players_dt)
setorder(t_players_dt, opponent_code, tournament_start_dtm, stadie_ord, match_order, id)
t_players_dt[, is_first_appearance_opp := seq_len(.N) == 1L, by = opponent_code]

# 3) Opponent initialization rules
t_players_dt[
  is_first_appearance_opp == TRUE & !is.na(opponent_turned_pro) & opponent_turned_pro < 1999,
  opponent_initial_highest := pre1999_best_opp[.SD, on = .(opponent_code), x.best_pre1999]
]
t_players_dt[
  is_first_appearance_opp == TRUE & (is.na(opponent_turned_pro) | opponent_turned_pro >= 1999),
  opponent_initial_highest := opponent_atp_ranking
]
t_players_dt[
  is_first_appearance_opp == TRUE & is.na(opponent_initial_highest),
  opponent_initial_highest := opponent_atp_ranking
]

# 4) Accumulate best-so-far ranking (opponent)
t_players_dt[
  , opponent_highest_atp_ranking := {
    r <- opponent_atp_ranking
    init <- opponent_initial_highest[1L]
    acc <- vector("integer", length(r))
    acc[1L] <- init
    if (length(r) > 1L) {
      for (k in 2:length(r)) {
        acc[k] <- if (is.na(r[k])) acc[k-1L] else min(acc[k-1L], r[k], na.rm = TRUE)
      }
    }
    acc
  },
  by = opponent_code
]

# 5) Checks (opponent)

# 5.1 First appearance: expected vs computed
opp_first <- t_players_dt[
  is_first_appearance_opp == TRUE,
  .(opponent_code, opponent_name, opponent_turned_pro,
    opponent_atp_ranking, opponent_highest_atp_ranking)
]
opp_first <- merge(opp_first, pre1999_best_opp, by = "opponent_code", all.x = TRUE)

opp_first[, expected_initial :=
            fifelse(!is.na(opponent_turned_pro) & opponent_turned_pro < 1999 & !is.na(best_pre1999),
                    best_pre1999,
                    opponent_atp_ranking)
]

opp_init_mismatches <- opp_first[
  !( (is.na(expected_initial) & is.na(opponent_highest_atp_ranking)) |
       (!is.na(expected_initial) & expected_initial == opponent_highest_atp_ranking) )
]

cat(sprintf("OPPONENT ▶ first-appearance init mismatches: %d\n", nrow(opp_init_mismatches)))
if (nrow(opp_init_mismatches) > 0) {
  cat("Examples (max 10):\n")
  print(head(opp_init_mismatches[
    , .(opponent_code, opponent_name, opponent_turned_pro,
        expected_initial,
        computed = opponent_highest_atp_ranking,
        first_appearance_rank = opponent_atp_ranking)
  ], 10))
}

# 5.2 Monotony
opp_mono <- t_players_dt[
  , .(ok_monotony = check_monotony(opponent_highest_atp_ranking)), by = opponent_code
]
n_bad_opp <- sum(!opp_mono$ok_monotony)
cat(sprintf("OPPONENT ▶ monotony violations: %d\n", n_bad_opp))

# 5.3 Trace a random opponent (10 rows)
set.seed(456)
if (n_bad_opp > 0) {
  pick_code_opp <- sample(opp_mono[ok_monotony == FALSE, opponent_code], 1L)
  cat(sprintf("Trace (violating) opponent_code = %s (first 10 rows):\n", pick_code_opp))
} else {
  pick_code_opp <- sample(unique(t_players_dt$opponent_code), 1L)
  cat(sprintf("Trace (random OK) opponent_code = %s (first 10 rows):\n", pick_code_opp))
}
print(
  t_players_dt[opponent_code == pick_code_opp,
               .(opponent_code, opponent_name, tournament_start_dtm,
                 opponent_atp_ranking, opponent_highest_atp_ranking)]
  [order(tournament_start_dtm)][1:10]
)

# 6) Cleanup aux columns and final order
t_players_dt[, c("is_first_appearance_opp", "opponent_initial_highest") := NULL]
order_datasets_dt(t_players_dt)

# Drop helper columns not needed in output
t_players_dt[, c("best_so_far_upto_date", "date_for_rank", "stadie_ord") := NULL]

# -----------------------------
# Persist enriched dataset
# -----------------------------
t_players <- copy(t_players_dt)
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
cat("✔ Saved enriched dataset: pred_jugadores_99-25.csv\n")
