# =============================================================================
# ATP Ranking Trends & Enrichment (Players + Opponents) — 1999–2025
# -----------------------------------------------------------------------------
# Purpose
#   Enrich a player-centric matches dataset with:
#     • ATP rankings as of the day BEFORE each match’s tournament start
#     • Short-term ranking trends (4 and 12 weeks) for both player & opponent
#     • Adaptive trend categories ("subida", "estable", "bajada")
#     • Rank differentials (opponent − player)
#     • Log features: log(opponent/player) and distance-to-peak (if peaks exist)
#     • Home flags (citizenship == tournament country)
#
# Notes
#   • Uses data.table for efficient rolling joins (no look-ahead).
#   • Trends use symmetric adaptive thresholds based on max(r_t, r_t-N).
#   • Output overwrites: pred_jugadores_99-25.csv
#   • The script prints compact summaries of trend category proportions and NA rates.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

# -----------------------------
# Round order (draw phases)
# -----------------------------
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

# dplyr-friendly ordering for data.frames
order_datasets_df <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # primary: chronological
      tournament_name,       # tie-break by tournament name
      tournament_id,         # group within tournament
      stadie_id,             # phase order within tournament
      match_order
    )
}

# -----------------------------
# Paths
# -----------------------------
players_path  <- ""
rankings_path <- "rankings csv" #REMINDER THAT YOU CAN SCRAPE THIS RANKINGS ON YOUR OWN AND I ALSO DOCUMENT IT ON THIS REPOSITORIE

# -----------------------------
# 1) Load player-centric dataset
# -----------------------------
setwd(players_path)
stopifnot(file.exists("pred_jugadores_99-25.csv"))
t_players    <- fread("pred_jugadores_99-25.csv", stringsAsFactors = FALSE)
t_players_dt <- as.data.table(t_players)

# Key types
t_players_dt[, tournament_start_dtm := as.Date(tournament_start_dtm)]
t_players_dt[, player_code   := as.character(player_code)]
t_players_dt[, opponent_code := as.character(opponent_code)]

# -----------------------------
# 2) Load ALL ranking snapshots (1973..)
#     Expect filenames like: rankings_YYYY-MM-DD.csv
# -----------------------------
rank_files <- list.files(
  path = rankings_path,
  pattern = "^rankings_\\d{4}-\\d{2}-\\d{2}\\.csv$",
  full.names = TRUE
)

detect_and_rename_rank_col <- function(DT) {
  rank_candidates <- c("player_atp_ranking", "atp_rank", "player_rank", "ranking", "rank")
  hit <- intersect(rank_candidates, names(DT))
  if (length(hit) == 0L) stop("No ranking column found in a rankings file.")
  setnames(DT, hit[1], "ranking")
  invisible(DT)
}

rankings_list <- lapply(rank_files, function(f) {
  dt <- fread(f, stringsAsFactors = FALSE)
  if (!"player_code" %in% names(dt)) {
    stop(sprintf("File %s is missing 'player_code'.", basename(f)))
  }
  dt[, player_code := as.character(player_code)]
  detect_and_rename_rank_col(dt)
  date_str <- sub("^rankings_(\\d{4}-\\d{2}-\\d{2})\\.csv$", "\\1", basename(f))
  dt[, snapshot_date := as.Date(date_str)]
  dt[, .(player_code, ranking, snapshot_date)]
})

rankings_dt <- rbindlist(rankings_list, use.names = TRUE)
# Keep valid ranks (>=1)
rankings_dt <- rankings_dt[!is.na(ranking) & ranking >= 1L]
setorder(rankings_dt, player_code, snapshot_date)
setkey(rankings_dt, player_code, snapshot_date)

# -----------------------------
# 3) Player ranking at t, t-4w, t-12w (strictly past: day-before)
# -----------------------------
t_players_dt[, date_for_rank     := tournament_start_dtm - 1L]
t_players_dt[, date_for_rank_4w  := date_for_rank - 28L]
t_players_dt[, date_for_rank_12w := date_for_rank - 84L]
t_players_dt[, row_id := .I]  # row id to re-align joins

# Generic rolling-join fetcher
get_rank_at <- function(DT_matches, date_col, out_col) {
  idx <- DT_matches[, .(row_id, player_code, target_date = get(date_col))]
  res <- rankings_dt[
    idx, on = .(player_code, snapshot_date = target_date),
    roll = Inf, mult = "last"
  ][, .(row_id, value = ranking)]
  setnames(res, "value", out_col)
  setkey(res, row_id)
  res
}

# Fetch ranks
rank_now <- get_rank_at(t_players_dt, "date_for_rank",     "player_rank_t")
rank_4w  <- get_rank_at(t_players_dt, "date_for_rank_4w",  "player_rank_t_4w")
rank_12w <- get_rank_at(t_players_dt, "date_for_rank_12w", "player_rank_t_12w")

# Inject back (by reference)
setkey(t_players_dt, row_id)
t_players_dt[rank_now,  player_rank_t     := i.player_rank_t]
t_players_dt[rank_4w,   player_rank_t_4w  := i.player_rank_t_4w]
t_players_dt[rank_12w,  player_rank_t_12w := i.player_rank_t_12w]

# -----------------------------
# 4) Player ranking trends & categories
#     trend = r(t-N) - r(t); positive => improvement (lower rank value now)
# -----------------------------
t_players_dt[
  , `:=`(
    player_rank_trend_4w  = ifelse(!is.na(player_rank_t) & !is.na(player_rank_t_4w),
                                   player_rank_t_4w  - player_rank_t, NA_integer_),
    player_rank_trend_12w = ifelse(!is.na(player_rank_t) & !is.na(player_rank_t_12w),
                                   player_rank_t_12w - player_rank_t, NA_integer_)
  )
]

# Adaptive thresholds (conservative, symmetric)
t_players_dt[
  , `:=`(
    thr_4w  = ifelse(!is.na(player_rank_t),
                     pmax(1L, ceiling(0.02 * pmax(player_rank_t, player_rank_t_4w))),  NA_integer_),
    thr_12w = ifelse(!is.na(player_rank_t),
                     pmax(1L, ceiling(0.05 * pmax(player_rank_t, player_rank_t_12w))), NA_integer_)
  )
]

# Categories
t_players_dt[, player_rank_trend_4w_cat :=
               fifelse(is.na(player_rank_trend_4w) | is.na(thr_4w), NA_character_,
                       fifelse(player_rank_trend_4w >=  thr_4w, "subida",
                               fifelse(player_rank_trend_4w <= -thr_4w, "bajada", "estable")))]

t_players_dt[, player_rank_trend_12w_cat :=
               fifelse(is.na(player_rank_trend_12w) | is.na(thr_12w), NA_character_,
                       fifelse(player_rank_trend_12w >=  thr_12w, "subida",
                               fifelse(player_rank_trend_12w <= -thr_12w, "bajada", "estable")))]

# -----------------------------
# 5) Opponent ranking at t, t-4w, t-12w and trends
# -----------------------------
t_players_dt[, date_for_rank     := tournament_start_dtm - 1L]  # rebuild helper dates
t_players_dt[, date_for_rank_4w  := date_for_rank - 28L]
t_players_dt[, date_for_rank_12w := date_for_rank - 84L]
t_players_dt[, row_id_opp := .I]

get_opp_rank_at <- function(DT_matches, date_col, out_col) {
  idx <- DT_matches[, .(row_id_opp, player_code = opponent_code, target_date = get(date_col))]
  res <- rankings_dt[
    idx, on = .(player_code, snapshot_date = target_date),
    roll = Inf, mult = "last"
  ][, .(row_id_opp, value = ranking)]
  setnames(res, "value", out_col)
  setkey(res, row_id_opp)
  res
}

opp_rank_now  <- get_opp_rank_at(t_players_dt, "date_for_rank",     "opponent_rank_t")
opp_rank_4w   <- get_opp_rank_at(t_players_dt, "date_for_rank_4w",  "opponent_rank_t_4w")
opp_rank_12w  <- get_opp_rank_at(t_players_dt, "date_for_rank_12w", "opponent_rank_t_12w")

setkey(t_players_dt, row_id_opp)
t_players_dt[opp_rank_now,  opponent_rank_t      := i.opponent_rank_t]
t_players_dt[opp_rank_4w,   opponent_rank_t_4w   := i.opponent_rank_t_4w]
t_players_dt[opp_rank_12w,  opponent_rank_t_12w  := i.opponent_rank_t_12w]

t_players_dt[
  , `:=`(
    opponent_rank_trend_4w  = ifelse(!is.na(opponent_rank_t) & !is.na(opponent_rank_t_4w),
                                     opponent_rank_t_4w  - opponent_rank_t, NA_integer_),
    opponent_rank_trend_12w = ifelse(!is.na(opponent_rank_t) & !is.na(opponent_rank_t_12w),
                                     opponent_rank_t_12w - opponent_rank_t, NA_integer_)
  )
]

# Opponent thresholds (symmetric)
t_players_dt[
  , `:=`(
    opp_thr_4w  = ifelse(!is.na(opponent_rank_t) & !is.na(opponent_rank_t_4w),
                         pmax(1L, ceiling(0.02 * pmax(opponent_rank_t, opponent_rank_t_4w))),  NA_integer_),
    opp_thr_12w = ifelse(!is.na(opponent_rank_t) & !is.na(opponent_rank_t_12w),
                         pmax(1L, ceiling(0.05 * pmax(opponent_rank_t, opponent_rank_t_12w))), NA_integer_)
  )
]

t_players_dt[, opponent_rank_trend_4w_cat :=
               fifelse(is.na(opponent_rank_trend_4w) | is.na(opp_thr_4w), NA_character_,
                       fifelse(opponent_rank_trend_4w >=  opp_thr_4w, "subida",
                               fifelse(opponent_rank_trend_4w <= -opp_thr_4w, "bajada", "estable")))]

t_players_dt[, opponent_rank_trend_12w_cat :=
               fifelse(is.na(opponent_rank_trend_12w) | is.na(opp_thr_12w), NA_character_,
                       fifelse(opponent_rank_trend_12w >=  opp_thr_12w, "subida",
                               fifelse(opponent_rank_trend_12w <= -opp_thr_12w, "bajada", "estable")))]

# Clean helper date columns for opponent block
t_players_dt[, c("row_id_opp", "date_for_rank", "date_for_rank_4w", "date_for_rank_12w") := NULL]

# -----------------------------
# 6) Rank differentials (opponent − player)
# -----------------------------
t_players[["rank_diff_t"]]   <- as.numeric(t_players[["opponent_atp_ranking"]]) -
                                as.numeric(t_players[["player_atp_ranking"]])

t_players[["trend_diff_4w"]]  <- as.numeric(t_players_dt[["opponent_rank_trend_4w"]]) -
                                 as.numeric(t_players_dt[["player_rank_trend_4w"]])

t_players[["trend_diff_12w"]] <- as.numeric(t_players_dt[["opponent_rank_trend_12w"]]) -
                                 as.numeric(t_players_dt[["player_rank_trend_12w"]])

# -----------------------------
# 7) Log features (robust to NA; only for positive ranks)
#     log_rank_ratio_t = log(opponent) − log(player)
#     log_dist_to_peak = log(current) − log(best)  (>= 0; 0 at peak)
# -----------------------------
t_players_dt[, log_rank_ratio_t := {
  p <- as.numeric(player_atp_ranking)
  o <- as.numeric(opponent_atp_ranking)
  out <- rep(NA_real_, .N)
  ok  <- !is.na(p) & !is.na(o) & p > 0 & o > 0
  out[ok] <- log(o[ok]) - log(p[ok])
  out
}]

t_players_dt[, log_player_dist_to_peak := {
  p <- as.numeric(player_atp_ranking)
  h <- if ("player_highest_atp_ranking" %in% names(t_players_dt)) as.numeric(get("player_highest_atp_ranking")) else rep(NA_real_, .N)
  out <- rep(NA_real_, .N)
  ok  <- !is.na(p) & !is.na(h) & p > 0 & h > 0
  out[ok] <- log(p[ok]) - log(h[ok])
  out
}]

t_players_dt[, log_opponent_dist_to_peak := {
  o <- as.numeric(opponent_atp_ranking)
  h <- if ("opponent_highest_atp_ranking" %in% names(t_players_dt)) as.numeric(get("opponent_highest_atp_ranking")) else rep(NA_real_, .N)
  out <- rep(NA_real_, .N)
  ok  <- !is.na(o) & !is.na(h) & o > 0 & h > 0
  out[ok] <- log(o[ok]) - log(h[ok])
  out
}]

# Copy log columns to the data.frame (keeps original object shape)
for (cc in c("log_rank_ratio_t", "log_player_dist_to_peak", "log_opponent_dist_to_peak")) {
  t_players[[cc]] <- t_players_dt[[cc]]
}

# -----------------------------
# 8) Home flags (exact country match)
# -----------------------------
t_players_dt[, `:=`(
  player_citizenship   = as.character(player_citizenship),
  opponent_citizenship = as.character(opponent_citizenship),
  tournament_country   = as.character(tournament_country)
)]

t_players_dt[, player_home :=
               as.integer(!is.na(player_citizenship) & !is.na(tournament_country) &
                          player_citizenship == tournament_country)]
t_players_dt[, opponent_home :=
               as.integer(!is.na(opponent_citizenship) & !is.na(tournament_country) &
                          opponent_citizenship == tournament_country)]

t_players$player_home   <- t_players_dt$player_home
t_players$opponent_home <- t_players_dt$opponent_home

# -----------------------------
# 9) Attach trend categories back to data.frame
# -----------------------------
cols_add <- c(
  "player_rank_trend_4w_cat", "player_rank_trend_12w_cat",
  "opponent_rank_trend_4w_cat", "opponent_rank_trend_12w_cat",
  "player_rank_trend_4w", "player_rank_trend_12w",
  "opponent_rank_trend_4w", "opponent_rank_trend_12w"
)
for (cc in cols_add) {
  if (cc %in% names(t_players_dt)) {
    t_players[[cc]] <- t_players_dt[[cc]]
  } else {
    t_players[[cc]] <- NA
    warning(sprintf("Column '%s' not found in t_players_dt; created as NA.", cc))
  }
}

# -----------------------------
# 10) Compact summaries (proportions & NA table)
# -----------------------------
percent <- function(x) sprintf("%.2f%%", 100 * x)

cats <- c("subida","estable","bajada")
tab4  <- table(factor(t_players_dt$player_rank_trend_4w_cat,  levels = cats))
tab12 <- table(factor(t_players_dt$player_rank_trend_12w_cat, levels = cats))
p4  <- if (sum(tab4)  > 0) prop.table(tab4)  else tab4
p12 <- if (sum(tab12) > 0) prop.table(tab12) else tab12

cat("\nPlayer trend categories (4w / 12w):\n")
print(data.frame(categoria = cats, `4w` = percent(as.numeric(p4)), `12w` = percent(as.numeric(p12))))

opp_cats  <- c("subida","estable","bajada")
opp_tab4  <- table(factor(t_players_dt$opponent_rank_trend_4w_cat,  levels = opp_cats))
opp_tab12 <- table(factor(t_players_dt$opponent_rank_trend_12w_cat, levels = opp_cats))
opp_p4  <- if (sum(opp_tab4)  > 0) prop.table(opp_tab4)  else opp_tab4
opp_p12 <- if (sum(opp_tab12) > 0) prop.table(opp_tab12) else opp_tab12

cat("\nOpponent trend categories (4w / 12w):\n")
print(data.frame(categoria = opp_cats, `4w_opp` = percent(as.numeric(opp_p4)), `12w_opp` = percent(as.numeric(opp_p12))))

DT <- as.data.table(t_players)
na_counts <- colSums(is.na(DT))
na_pct    <- round(100 * na_counts / nrow(DT), 2)
na_table  <- data.table(variable = names(na_counts), n_na = as.integer(na_counts), pct_na = na_pct)[order(-pct_na, -n_na)]
cat("\nTop NA columns:\n")
print(head(na_table, 25))

# -----------------------------
# 11) Final ordering (data.frame) & persist
# -----------------------------
t_players <- order_datasets_df(t_players)
fwrite(t_players, "pred_jugadores_99-25.csv")

cat("\n✔ Saved enriched dataset: pred_jugadores_99-25.csv\n")
