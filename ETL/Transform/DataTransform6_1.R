############################################################################################
# ATP Surface-Specific Elo Enrichment (1968–1998 pre-seed + 1999–2025 updates)
# ------------------------------------------------------------------------------------------
# Goal
#   Compute and inject *surface-aware* Elo features into a player-centric ATP dataset.
#   The pipeline:
#     1) Builds a per-surface Elo baseline (1968–1998) from Jeff Sackmann’s archive.
#     2) Seeds 1999–2025 ratings on first appearance (pre-99 Elo if available, else 1500).
#     3) Updates Elo per match in 1999–2025 with a fast matrix-based implementation.
#     4) Emits informative features comparing *general* vs *surface* strength and win probs.
#
# Inputs
#   • pred_jugadores_99-25.csv : player-centric view (two rows per match id) enriched
#                                previamente con Elo general (player_elo_pre / opponent_elo_pre)
#                                y probabilidades generales (player_win_prob / opponent_win_prob).
#                                Must include: id, player_code, opponent_code, match_result
#                                ("win"/"loss"), surface, match_ret (optional), tournament_*,
#                                stadie_id, match_order.
#   • Jeff Sackmann all_matches.csv (we consume year < 1999) with winner_code, loser_code,
#     tourney_date, round, surface, tourney_id, match_num.
#
# Outputs (overwrites pred_jugadores_99-25.csv)
#   • player_elo_surface_pre / opponent_elo_surface_pre : pre-match Elo on the event surface
#   • player_win_prob_surface / opponent_win_prob_surface : Elo-implied win probabilities
#     on that surface
#   • player_surface_specialization / opponent_surface_specialization : surface Elo – general Elo
#   • surface_specialization_diff : player_surface_specialization − opponent_surface_specialization
#   • player_consistency_log_ratio / opponent_consistency_log_ratio : log(Elo_surface / Elo_general)
#   • consistency_log_ratio_diff : player_consistency_log_ratio − opponent_consistency_log_ratio
#   • player_win_prob_diff_general_vs_surface / opponent_* : general − surface probability
#   • player_win_prob_log_ratio / opponent_* : log(surface_prob / general_prob)
#
# Surface normalization
#   All surfaces are mapped into {Clay, Grass, Carpet, Hard} via string matching:
#     "clay"   -> "Clay"
#     "grass"  -> "Grass"
#     "carpet" -> "Carpet"
#     "hard"   -> "Hard"
#   Others/NAs are dropped for pre-99 training (and treated as neutral 1500 in 99–25 if needed).
#
# Elo model (per surface)
#   • Initial rating (μ)     : 1500
#   • K-factor (provisional) : 40  for players with < 20 career matches (global count)
#   • K-factor (base)        : 20  otherwise
#   • Expected score          P(W) = 1 / (1 + 10^(-(R_W − R_L)/400))
#   • Update for a completed match:
#       Δ = K_adj * (1 − P(W))
#       R_W ← R_W + Δ,  R_L ← R_L − Δ
#     where K_adj = max(K_W, K_L) and is adjusted for match_ret:
#       - "(RET)" → K_adj ← 0.5 * K_adj   (half impact on retirements)
#       - "W/O"   → K_adj ← 0             (walkovers do not move rating)
#       - else    → K_adj unchanged
#   • Provisional threshold is counted *globally* (not per surface), following common practice.
#
# Update semantics
#   This surface Elo uses an *online* update per match pair in 1999–2025 (faster version).
#   If your pipeline enforces round-safe batching for general Elo elsewhere, you can apply the
#   same idea here by accumulating per-round deltas and committing at the end of each round.
#   (This script keeps per-match updates for the surface model to maximize throughput.)
#
# Feature intuition
#   • Specialization (Elo_surface − Elo_general) > 0 implies the player is stronger on the
#     current surface compared to their overall level; < 0 indicates a relative weakness.
#   • Consistency log ratio log(Elo_surface / Elo_general) is scale-stable (additive in log),
#     useful when Elo magnitudes differ across eras/samples.
#   • Probability deltas/ratios quantify how much the surface-specific rating *revises*
#     the general-win estimate (useful for model stacking or meta-learning).
############################################################################################

library(data.table)
library(dplyr)
library(progress)

# ----------------------------------------------------------------------------------------
# 0) Load data and helpers
# ----------------------------------------------------------------------------------------
setwd("/home/aitor/Descargas/Project/Data/Msolonskyi")
t_players <- read.csv("pred_jugadores_99-25.csv", stringsAsFactors = FALSE)

data_pre99 <- read.csv("/home/aitor/Descargas/Project/Data/JeffSackman/all_matches.csv")
data_pre99 <- data_pre99[data_pre99$year < 1999, ]  # 1968–1998

# Round ordering for stable tournament sequencing
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # primary chronological order
      tournament_name,       # tie-break by tournament name
      tournament_id,         # group by full tournament id
      stadie_id,             # within-tournament round order
      match_order            # within-round match order if available
    )
}

# ----------------------------------------------------------------------------------------
# 1) Surface-specific Elo pre-seed (1968–1998)
# ----------------------------------------------------------------------------------------
pre_dt <- as.data.table(data_pre99)
pre_dt[, `:=`(
  winner_code = as.character(winner_code),
  loser_code  = as.character(loser_code)
)]
pre_dt[, match_date := as.Date(as.character(tourney_date), format = "%Y%m%d")]

# Normalize surface labels to 4 canonical buckets
norm_surface <- function(s) {
  x <- tolower(trimws(as.character(s)))
  fifelse(grepl("clay",   x), "Clay",
  fifelse(grepl("grass",  x), "Grass",
  fifelse(grepl("carpet", x), "Carpet",
  fifelse(grepl("hard",   x), "Hard", NA_character_))))
}

pre_dt[, surface_std := norm_surface(surface)]
pre_dt <- pre_dt[!is.na(match_date) & !is.na(winner_code) & !is.na(loser_code) & !is.na(surface_std)]

# Deterministic ordering (Jeff’s rounds include "ER")
pre_dt[, stadie_id := factor(
  round,
  levels = c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F"),
  ordered = TRUE
)]
setorder(pre_dt, match_date, tourney_id, stadie_id, match_num, winner_code, loser_code)

# Elo parameters
mu <- 1500
K_base <- 20L
K_prov <- 40L
prov_threshold <- 20L  # global (not per surface)

# State:
#   - R_s: rating by (player|surface) in a named numeric vector
#   - N_total: global career match count by player for provisional K logic
R_s <- numeric(0); names(R_s) <- character(0)      # key "player|surface"
N_total <- integer(0); names(N_total) <- character(0)

key_ps <- function(p, s) paste0(p, "|", s)

get_Rs <- function(p, s) {
  if (is.na(p) || !nzchar(p) || is.na(s) || !nzchar(s)) return(mu)
  k <- key_ps(p, s)
  v <- R_s[k]
  if (is.na(v)) { R_s[k] <<- mu; v <- mu }
  v
}
set_Rs <- function(p, s, val) {
  R_s[key_ps(p, s)] <<- val
}
get_N <- function(p) {
  if (is.na(p) || !nzchar(p)) return(0L)
  v <- N_total[p]
  if (is.na(v)) { N_total[p] <<- 0L; v <- 0L }
  v
}
inc_N <- function(p) { N_total[p] <<- get_N(p) + 1L }

# Train surface-specific Elo on 1968–1998
for (i in seq_len(nrow(pre_dt))) {
  w <- pre_dt$winner_code[i]
  l <- pre_dt$loser_code[i]
  s <- pre_dt$surface_std[i]
  if (is.na(w) || is.na(l) || !nzchar(w) || !nzchar(l) || is.na(s)) next
  
  Rw <- get_Rs(w, s); Rl <- get_Rs(l, s)
  Nw <- get_N(w);     Nl <- get_N(l)
  
  Pw <- 1.0 / (1.0 + 10^(-(Rw - Rl)/400))
  Kw <- if (Nw < prov_threshold) K_prov else K_base
  Kl <- if (Nl < prov_threshold) K_prov else K_base
  Kp <- max(Kw, Kl)
  
  delta <- Kp * (1 - Pw)
  set_Rs(w, s, Rw + delta)
  set_Rs(l, s, Rl - delta)
  
  inc_N(w); inc_N(l)
}

# Pre-99 dictionary: Elo(player, surface)
pre99_surface_elo_dt <- if (length(R_s) > 0) {
  data.table(
    player_code = sub("\\|.*$", "", names(R_s)),
    surface_std = sub("^.*\\|", "", names(R_s)),
    elo_pre99_surface = as.numeric(R_s)
  )
} else {
  data.table(player_code=character(), surface_std=character(), elo_pre99_surface=numeric())
}
setkey(pre99_surface_elo_dt, player_code, surface_std)

# ----------------------------------------------------------------------------------------
# 2) Seed surface Elo on first appearance in 1999–2025
# ----------------------------------------------------------------------------------------
t_players_dt <- as.data.table(t_players)
t_players_dt[, `:=`(
  tournament_start_dtm = as.Date(tournament_start_dtm),
  player_code          = as.character(player_code),
  opponent_code        = as.character(opponent_code),
  player_turned_pro    = as.integer(player_turned_pro),
  opponent_turned_pro  = as.integer(opponent_turned_pro)
)]
t_players_dt <- order_datasets(t_players_dt)

# Canonical surface in the 99–25 frame
t_players_dt[, surface_std := norm_surface(surface)]

# Prepare output cols (only first appearances will be non-NA at this point)
t_players_dt[, `:=`(
  player_elo_surface_pre   = as.numeric(NA),
  opponent_elo_surface_pre = as.numeric(NA)
)]

# First appearance flags per code (player/opponent perspective separately)
t_players_dt[, is_first_player := seq_len(.N) == 1L, by = player_code]
t_players_dt[, is_first_opp    := seq_len(.N) == 1L, by = opponent_code]

# Player seed: debut < 1999 and has pre-99 surface Elo → use it, else 1500
t_players_dt[
  is_first_player == TRUE & !is.na(player_turned_pro) & player_turned_pro < 1999,
  player_elo_surface_pre := pre99_surface_elo_dt[.SD[, .(player_code, surface_std)],
                                                 on = .(player_code, surface_std),
                                                 x.elo_pre99_surface]
]
t_players_dt[
  is_first_player == TRUE & (is.na(player_elo_surface_pre) | is.na(player_turned_pro) | player_turned_pro >= 1999),
  player_elo_surface_pre := mu
]

# Opponent seed: analogous
t_players_dt[
  is_first_opp == TRUE & !is.na(opponent_turned_pro) & opponent_turned_pro < 1999,
  opponent_elo_surface_pre := pre99_surface_elo_dt[.SD[, .(player_code = opponent_code, surface_std)],
                                                   on = .(player_code, surface_std),
                                                   x.elo_pre99_surface]
]
t_players_dt[
  is_first_opp == TRUE & (is.na(opponent_elo_surface_pre) | is.na(opponent_turned_pro) | opponent_turned_pro >= 1999),
  opponent_elo_surface_pre := mu
]

# Drop helper flags
t_players_dt[, c("is_first_player","is_first_opp") := NULL]

# Quick sanity checks
cat("player_elo_surface_pre non-NA (first appearances only): ",
    sum(!is.na(t_players_dt$player_elo_surface_pre)), "\n")
cat("opponent_elo_surface_pre non-NA (first appearances only): ",
    sum(!is.na(t_players_dt$opponent_elo_surface_pre)), "\n")

# ----------------------------------------------------------------------------------------
# 3) Fast, online surface Elo updates for 1999–2025
# ----------------------------------------------------------------------------------------

# Pre-99 global match counts → provisional logic in the 99–25 window
pre99_n_dt <- if (length(N_total) > 0) {
  data.table(player_code = names(N_total), n_pre99 = as.integer(N_total))
} else data.table(player_code = character(), n_pre99 = integer())
setkey(pre99_n_dt, player_code)

t <- copy(t_players_dt)
t <- order_datasets(t)
setDT(t)

# Numeric indices for players and surfaces → matrix-friendly state
all_players <- unique(c(t$player_code, t$opponent_code))
all_players <- all_players[!is.na(all_players) & nzchar(all_players)]
player_index  <- setNames(seq_along(all_players), all_players)

surfaces <- c("Clay", "Grass", "Carpet", "Hard")
surface_index <- setNames(seq_along(surfaces), surfaces)

# Elo state: matrix [player x surface] + global match counters
n_players  <- length(all_players)
n_surfaces <- length(surfaces)

elo_matrix <- matrix(mu, nrow = n_players, ncol = n_surfaces,
                     dimnames = list(all_players, surfaces))
match_count <- integer(n_players); names(match_count) <- all_players

# Fill from pre-99 per-surface Elo (if present)
if (nrow(pre99_surface_elo_dt) > 0) {
  for (i in seq_len(nrow(pre99_surface_elo_dt))) {
    p <- pre99_surface_elo_dt$player_code[i]
    s <- pre99_surface_elo_dt$surface_std[i]
    v <- pre99_surface_elo_dt$elo_pre99_surface[i]
    if (p %in% all_players && s %in% surfaces) {
      elo_matrix[p, s] <- v
    }
  }
}
# Fill pre-99 global counts
if (nrow(pre99_n_dt) > 0) {
  for (i in seq_len(nrow(pre99_n_dt))) {
    p <- pre99_n_dt$player_code[i]
    n <- pre99_n_dt$n_pre99[i]
    if (p %in% all_players) match_count[p] <- n
  }
}

# Pre-allocate outputs
n_rows <- nrow(t)
player_elo_pre_vec                <- rep(NA_real_, n_rows)
opponent_elo_pre_vec              <- rep(NA_real_, n_rows)
player_win_prob_surface_vec       <- rep(NA_real_, n_rows)
opponent_win_prob_surface_vec     <- rep(NA_real_, n_rows)

# Pair two rows per match id; skip malformed ids
pairs <- t[!is.na(id) & nzchar(id), .(rows = list(.I), first_idx = min(.I)), by = id]
pairs <- pairs[lengths(rows) == 2L][order(first_idx)]

bad_ids_n <- t[, .N, by = id][N != 2L, .N]
if (bad_ids_n > 0L) {
  message("Warning: ", bad_ids_n, " matches have != 2 rows; skipping Elo updates on those ids.")
}

# Progress bar for long runs
if (nrow(pairs) > 0) {
  pb <- progress_bar$new(
    total = nrow(pairs),
    format = "  Surface Elo [:bar] :percent :current/:total eta: :eta"
  )
  
  for (j in seq_len(nrow(pairs))) {
    pb$tick()
    
    idx <- pairs$rows[[j]]
    i1 <- idx[1L]; i2 <- idx[2L]
    
    p1 <- t$player_code[i1]; p2 <- t$player_code[i2]
    s  <- t$surface_std[i1]
    
    # No surface → neutral ratings/probabilities
    if (is.na(s) || !nzchar(s)) {
      player_elo_pre_vec[i1]            <- mu
      opponent_elo_pre_vec[i1]          <- mu
      player_elo_pre_vec[i2]            <- mu
      opponent_elo_pre_vec[i2]          <- mu
      player_win_prob_surface_vec[i1]   <- 0.5
      opponent_win_prob_surface_vec[i1] <- 0.5
      player_win_prob_surface_vec[i2]   <- 0.5
      opponent_win_prob_surface_vec[i2] <- 0.5
      next
    }
    
    # Indices
    p1_idx <- player_index[p1]
    p2_idx <- player_index[p2]
    s_idx  <- surface_index[s]
    
    # Pre-match ratings on surface
    R1 <- elo_matrix[p1_idx, s_idx]
    R2 <- elo_matrix[p2_idx, s_idx]
    
    # Elo-implied probabilities on surface
    P1 <- 1 / (1 + 10^(-(R1 - R2)/400))
    P2 <- 1 - P1
    
    # Store pre-match state for both rows
    player_elo_pre_vec[i1]            <- R1
    opponent_elo_pre_vec[i1]          <- R2
    player_elo_pre_vec[i2]            <- R2
    opponent_elo_pre_vec[i2]          <- R1
    player_win_prob_surface_vec[i1]   <- P1
    opponent_win_prob_surface_vec[i1] <- P2
    player_win_prob_surface_vec[i2]   <- P2
    opponent_win_prob_surface_vec[i2] <- P1
    
    # Winner/loser resolution from two perspectives
    mr1 <- t$match_result[i1]
    mr2 <- t$match_result[i2]
    if (is.na(mr1) || is.na(mr2)) next
    
    # Fallback-safe access to match_ret
    mr_i1 <- if ("match_ret" %in% names(t)) t$match_ret[i1] else NA_character_
    mr_i2 <- if ("match_ret" %in% names(t)) t$match_ret[i2] else NA_character_
    
    if (mr1 == "win") {
      w <- p1; l <- p2
      Rw <- R1; Rl <- R2
      w_idx <- p1_idx; l_idx <- p2_idx
      mr <- mr_i1
    } else {
      w <- p2; l <- p1
      Rw <- R2; Rl <- R1
      w_idx <- p2_idx; l_idx <- p1_idx
      mr <- mr_i2
    }
    
    # K-factor with provisional logic (global count)
    Nw <- match_count[w_idx]
    Nl <- match_count[l_idx]
    Pw <- 1.0 / (1.0 + 10^(-(Rw - Rl)/400))
    Kw <- if (Nw < prov_threshold) K_prov else K_base
    Kl <- if (Nl < prov_threshold) K_prov else K_base
    Kp <- max(Kw, Kl)
    
    # RET/W.O. handling
    K_adj <- if (is.na(mr)) {
      Kp
    } else if (mr == "(RET)") {
      Kp * 0.5
    } else if (mr %in% c("(W/O)", "W/O")) {
      0
    } else {
      Kp
    }
    
    # Apply update
    if (K_adj > 0) {
      delta <- K_adj * (1 - Pw)
      elo_matrix[w_idx, s_idx] <- Rw + delta
      elo_matrix[l_idx, s_idx] <- Rl - delta
      match_count[w_idx] <- Nw + 1L
      match_count[l_idx] <- Nl + 1L
    }
  }
}

# Assign vectors back
t[, player_elo_surface_pre       := player_elo_pre_vec]
t[, opponent_elo_surface_pre     := opponent_elo_pre_vec]
t[, player_win_prob_surface      := player_win_prob_surface_vec]
t[, opponent_win_prob_surface    := opponent_win_prob_surface_vec]

t_players_dt <- order_datasets(t)

cat("\n[Surface Elo] Updated with RET/W.O. handling\n",
    "Examples: min/max player_elo_surface_pre = ",
    paste(range(t_players_dt$player_elo_surface_pre, na.rm = TRUE), collapse = " / "),
    " | min/max opponent_elo_surface_pre = ",
    paste(range(t_players_dt$opponent_elo_surface_pre, na.rm = TRUE), collapse = " / "),
    "\n", sep = "")

# ----------------------------------------------------------------------------------------
# 4) Feature engineering: general vs surface deltas/ratios
# ----------------------------------------------------------------------------------------

# Specialization (surface strength over general strength)
t_players_dt[, player_surface_specialization   := player_elo_surface_pre   - player_elo_pre]
t_players_dt[, opponent_surface_specialization := opponent_elo_surface_pre - opponent_elo_pre]
t_players_dt[, surface_specialization_diff     := player_surface_specialization - opponent_surface_specialization]

# Consistency log-ratios (scale-stable)
t_players_dt[, player_consistency_log_ratio   := log(player_elo_surface_pre   / player_elo_pre)]
t_players_dt[, opponent_consistency_log_ratio := log(opponent_elo_surface_pre / opponent_elo_pre)]
t_players_dt[, consistency_log_ratio_diff     := player_consistency_log_ratio - opponent_consistency_log_ratio]

# Relative effect within each surface cohort (z-ish ratio; centered by surface mean)
t_players_dt[, player_surface_effect   := player_elo_surface_pre   / mean(player_elo_surface_pre,   na.rm = TRUE), by = surface_std]
t_players_dt[, opponent_surface_effect := opponent_elo_surface_pre / mean(opponent_elo_surface_pre, na.rm = TRUE), by = surface_std]

# Probability deltas and log ratios: how much surface Elo revises the general prediction
t_players_dt[, player_win_prob_diff_general_vs_surface   := player_win_prob   - player_win_prob_surface]
t_players_dt[, opponent_win_prob_diff_general_vs_surface := opponent_win_prob - opponent_win_prob_surface]
t_players_dt[, player_win_prob_log_ratio                 := log(player_win_prob_surface   / player_win_prob)]
t_players_dt[, opponent_win_prob_log_ratio               := log(opponent_win_prob_surface / opponent_win_prob)]

# Drop helper
t_players_dt[, surface_std := NULL]

# ----------------------------------------------------------------------------------------
# 5) Save
# ----------------------------------------------------------------------------------------
t_players <- as.data.frame(order_datasets(t_players_dt))
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
