# ======================================================================================
# ATP Elo Enrichment (1968–1998 pre-seed + 1999–2025 round-safe updates) — Detailed Notes
# --------------------------------------------------------------------------------------
# What this script does
#   • Builds an Elo rating baseline from historical Jeff Sackmann match data (1968–1998)
#     and uses it to initialize players’ ratings at the start of the modern window.
#   • Enriches a player-centric match dataset (1999–2025) with:
#       - player_elo_pre / opponent_elo_pre  : Elo for each side *before* the match
#       - player_win_prob / opponent_win_prob: Elo-implied win probabilities
#       - elo_diff                           : player_elo_pre − opponent_elo_pre
#   • Updates Elo *without intra-round leakage*: all matches in the same round of a
#     tournament are evaluated against the same “pre-round” ratings snapshot; the
#     rating changes (deltas) are accumulated and applied only after the round ends.
#
# File I/O & expectations
#   • Inputs:
#       - /.../JeffSackman/all_matches.csv  (full archive; we use rows with year < 1999)
#       - pred_jugadores_99-25.csv          (player-centric, two rows per match id)
#     The player-centric file must contain: id, match_result ("win"/"loss"), player_code,
#     opponent_code, tournament_id, tournament_name, tournament_start_dtm, stadie_id,
#     match_order. If a phantom id like "0-0-0-0-0" exists, it is filtered out.
#   • Output:
#       - pred_jugadores_99-25.csv is overwritten with added Elo columns.
#
# Ordering & round semantics (critical for no-leakage updates)
#   1) We define an explicit round order: c("Q1","Q2","Q3","BR","RR","R128","R64","R32",
#      "R16","QF","SF","F","3P") and convert stadie_id to an ordered factor.
#   2) We globally order matches by (tournament_start_dtm, tournament_name, tournament_id,
#      stadie_id, match_order). This creates a deterministic processing sequence.
#   3) For Elo updates, we group by (tournament_start_dtm, tournament_id, stadie_id),
#      i.e., we batch all matches in the same round together.
#   4) Within a round:
#        - For each match we read the *current* ratings (the snapshot before this round).
#        - We compute per-player deltas but DO NOT update ratings yet.
#        - After *all* matches of the round are processed, we apply the accumulated deltas.
#      This ensures a semifinal result cannot “leak” into the other semifinal’s pre-match
#      ratings, and both finalists face each other using ratings that reflect all prior
#      rounds but not the opponent’s ongoing round.
#
# Elo model details
#   • Base parameters:
#       mu = 1500               # initial rating
#       K_prov = 40             # provisional K for players with N < 20 matches
#       K_base = 20             # standard K afterwards
#       prov_threshold = 20     # provisional-to-standard transition point
#   • Expected score for player A vs B:
#       P(A) = 1 / (1 + 10^((R_B - R_A) / 400)) = 1 / (1 + 10^{-(R_A - R_B)/400})
#   • Update for a completed match (winner W, loser L):
#       Δ = K_adj * (1 − P(W))
#       R_W ← R_W + Δ
#       R_L ← R_L − Δ
#     where K_adj is the effective K for the pairing, chosen as:
#       - K_adj = max(K_W, K_L)                       # symmetric pairing K
#       - If match_ret == "(RET)" → K_adj ← 0.5 * K   # half-impact for retirements
#       - If walkover "(W/O)"      → K_adj ← 0        # no rating impact
#     and K_X = K_prov if player X has < 20 career matches, otherwise K_base.
#
# Two-stage timeline
#   • Stage A — Pre-seeding (1968–1998):
#       We loop through the historical archive once, sorted by date/tournament/round,
#       and apply the standard Elo rule to obtain an end-of-1998 rating per player,
#       plus a cumulative match count. These become initial conditions for 1999.
#   • Stage B — Modern era (1999–2025), round-safe updates:
#       We initialize each player in the 1999–2025 dataset from the pre-seed
#       (or 1500/0 if absent in the pre-99 dictionary) and then:
#         1) Pair the two rows per match id; skip malformed ids with != 2 rows.
#         2) Group match pairs by round; inside each group:
#              - write pre-match ratings & probabilities into both rows,
#              - compute and accumulate Elo deltas,
#              - apply all deltas to the global rating vector *after* the group finishes.
#
# Columns written to the dataset
#   • player_elo_pre    : Elo of the row’s player before the match
#   • opponent_elo_pre  : Elo of the opponent before the match
#   • player_win_prob   : 1 / (1 + 10^{-(player_elo_pre − opponent_elo_pre)/400})
#   • opponent_win_prob : 1 − player_win_prob
#   • elo_diff          : player_elo_pre − opponent_elo_pre
#
# Edge cases & safeguards
#   • Missing/placeholder ids: rows with id == "0-0-0-0-0" are removed; ids with not
#     exactly 2 rows are skipped for updating (but still may receive pre-match ratings
#     if a safe pairing is available).
#   • Missing results: if match_result is NA/invalid for a pair, we do not update Elo.
#   • Retirement/walkover: handled via K_adj as described above.
#   • Factor order stability: round labels outside the defined set are tolerated (as NA),
#     but order_datasets relies on meaningful stadie_id levels to be fully effective.
#
# Performance & determinism
#   • data.table is used for vectorized joins and in-place updates; pre-allocations
#     avoid repeated re-sizing of large vectors.
#   • Sorting + explicit factor levels → deterministic runs (given identical input).
#   • A progress bar shows round-batch progress, which is helpful for long seasons.
#
# Limitations & extensions (intentionally not covered here)
#   • No surface-/round-specific K, no decay/aging factor, no margin-of-victory scaling.
#   • Doubles, retirements with score-based weighting, or country/home bias are not modeled.
#   • Possible enhancements: surface-specific Elo, per-series K, exponential decay over
#     time, injury/layoff modifiers, or integration with serve/return stat-based models.
# ======================================================================================

library(data.table)
library(dplyr)
library(progress)

setwd("")

# ----------------------
# Input data
# ----------------------
data_pre99 <- read.csv("JeffSackman/all_matches.csv")
data_pre99 <- data_pre99[data_pre99$year < 1999, ]  # 1968–1998 window

t_players <- read.csv("pred_jugadores_99-25.csv")

# Round ordering for modern dataset (matches-level tie-breakers)
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

# Some sources leave a "0-0-0-0-0" placeholder; drop those safely (keep NAs)
t_players <- t_players %>%
  filter(is.na(id) | id != "0-0-0-0-0")

# Utility: stable ordering of matches within tournament and round
order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # chronological
      tournament_name,       # secondary disambiguation
      tournament_id,         # group by tournament
      stadie_id,             # within-tournament round order
      match_order            # final tie-breaker
    )
}

# Convert to data.table for speed
setDT(t_players)
setDT(data_pre99)

# ----------------------
# Elo parameters
# ----------------------
mu             <- 1500  # base rating
K_base         <- 20    # post-provisional K
K_prov         <- 40    # provisional K
prov_threshold <- 20    # matches threshold for provisional status

# ======================================================================================
# 1) Pre-1999 Elo seeding from Jeff Sackmann (1968–1998)
# ======================================================================================
pre_dt <- as.data.table(data_pre99)
pre_dt[, `:=`(
  winner_code = as.character(winner_code),
  loser_code  = as.character(loser_code)
)]
pre_dt[, match_date := as.Date(as.character(tourney_date), format = "%Y%m%d")]
pre_dt <- pre_dt[!is.na(match_date) & !is.na(winner_code) & !is.na(loser_code)]

# Pre-99 rounds include "ER" in some archives; keep ordered factor for stable processing
orden_fases_pre99 <- c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F")
pre_dt[, round := factor(round, levels = orden_fases_pre99, ordered = TRUE)]
setorder(pre_dt, match_date, tourney_id, round, match_num, winner_code, loser_code)

# State for Elo and match counts during pre-99 pass
R <- numeric(0); names(R) <- character(0)  # ratings
N <- integer(0); names(N) <- character(0)  # match counts

get_R <- function(code){
  if (!nzchar(code)) return(mu)
  if (!code %in% names(R)) R[code] <<- mu
  R[code]
}
get_N <- function(code){
  if (!nzchar(code)) return(0L)
  if (!code %in% names(N)) N[code] <<- 0L
  N[code]
}

# Single-pass Elo over 1968–1998
for (i in seq_len(nrow(pre_dt))) {
  w <- pre_dt$winner_code[i]; l <- pre_dt$loser_code[i]
  if (is.na(w) || is.na(l) || !nzchar(w) || !nzchar(l)) next
  Rw <- get_R(w); Rl <- get_R(l)
  Nw <- get_N(w); Nl <- get_N(l)

  Pw <- 1 / (1 + 10^(-(Rw - Rl) / 400))         # expected win prob for winner
  Kw <- if (Nw < prov_threshold) K_prov else K_base
  Kl <- if (Nl < prov_threshold) K_prov else K_base
  K  <- max(Kw, Kl)                              # symmetric pairing K

  delta <- K * (1 - Pw)                          # winner gain, loser loss
  R[w] <- Rw + delta; R[l] <- Rl - delta
  N[w] <- Nw + 1L;    N[l] <- Nl + 1L
}

# Pre-99 seed dictionary
pre99_elo_dt <- data.table(
  player_code        = names(R),
  elo_pre99          = as.numeric(R),
  match_count_pre99  = as.integer(N[names(R)])
)
setkey(pre99_elo_dt, player_code)

# ======================================================================================
# 2) Prepare 1999–2025 dataset and seed with pre-99 Elo
# ======================================================================================
t_players_dt <- as.data.table(t_players)
t_players_dt[, `:=`(
  tournament_start_dtm = as.Date(tournament_start_dtm),
  player_code          = as.character(player_code),
  opponent_code        = as.character(opponent_code)
)]
t_players_dt <- order_datasets(t_players_dt)

# All unique players across both roles
all_players  <- unique(c(t_players_dt$player_code, t_players_dt$opponent_code))
all_players  <- all_players[!is.na(all_players) & nzchar(all_players)]
player_index <- setNames(seq_along(all_players), all_players)

# Initialize Elo and match counters
n_players   <- length(all_players)
elo_vector  <- rep(mu, n_players); names(elo_vector)  <- all_players
match_count <- integer(n_players); names(match_count) <- all_players

# Seed with pre-99 Elo where available
for (i in seq_len(nrow(pre99_elo_dt))) {
  player <- pre99_elo_dt$player_code[i]
  if (player %in% all_players) {
    elo_vector[player]  <- pre99_elo_dt$elo_pre99[i]
    match_count[player] <- pre99_elo_dt$match_count_pre99[i]
  }
}

# Pre-allocate outputs
n_rows <- nrow(t_players_dt)
player_elo_pre_vec     <- rep(NA_real_, n_rows)
opponent_elo_pre_vec   <- rep(NA_real_, n_rows)
player_win_prob_vec    <- rep(NA_real_, n_rows)
opponent_win_prob_vec  <- rep(NA_real_, n_rows)

t_players_dt <- order_datasets(t_players_dt)

# ======================================================================================
# 3) Elo updates WITHOUT intra-round leakage (apply deltas at round end)
# ======================================================================================

# Build pairs of row indices per match id; keep only well-formed matches (2 rows)
pairs <- t_players_dt[!is.na(id) & nzchar(id), .(rows = list(.I)), by = id]
pairs <- pairs[lengths(rows) == 2L]

# Warn on malformed matches (not fatal; they will be skipped)
bad_ids_n <- t_players_dt[, .N, by = id][N != 2L, .N]
if (bad_ids_n > 0L) {
  message("Warning: ", bad_ids_n, " matches with != 2 rows; skipping Elo update for those.")
}

# Attach round metadata to each match id to group “by round”
pairs <- pairs[
  t_players_dt[, .(id, tournament_start_dtm, tournament_id, stadie_id)],
  on = "id", mult = "first"
]

# Sort pairs by (date → tournament → round)
t_players_dt[, stadie_id := factor(stadie_id, levels = orden_fases, ordered = TRUE)]
setorder(pairs, tournament_start_dtm, tournament_id, stadie_id)
t_players_dt <- order_datasets(t_players_dt)

# Unique round groups
rondas <- unique(pairs[, .(tournament_start_dtm, tournament_id, stadie_id)])

# Progress bar across round groups
pb <- progress_bar$new(
  total  = nrow(rondas),
  format = "  Elo (round-batched) [:bar] :percent :current/:total eta: :eta"
)

t_players_dt <- order_datasets(t_players_dt)

for (g in seq_len(nrow(rondas))) {
  pb$tick()
  grp <- rondas[g]

  # Matches (as row-index pairs) belonging to this round
  pairs_grp <- pairs[
    tournament_start_dtm == grp$tournament_start_dtm &
      tournament_id      == grp$tournament_id &
      stadie_id          == grp$stadie_id
  ]
  if (nrow(pairs_grp) == 0L) next

  # Accumulators to be applied AFTER the round finishes
  delta_by_player <- numeric(0)  # named: code -> sum(delta)
  cnt_by_player   <- integer(0)  # named: code -> matches played in round

  # ---- Pass 1: compute Elo PRE and probs for all matches; accumulate deltas (no updates yet)
  for (rows_idx in pairs_grp$rows) {
    idx <- rows_idx
    i1 <- idx[1L]; i2 <- idx[2L]

    p1 <- t_players_dt$player_code[i1]
    p2 <- t_players_dt$player_code[i2]

    p1_idx <- player_index[p1]
    p2_idx <- player_index[p2]

    R1 <- elo_vector[p1_idx]
    R2 <- elo_vector[p2_idx]

    # Win probabilities from Elo
    P1 <- 1 / (1 + 10^(-(R1 - R2) / 400))
    P2 <- 1 - P1

    # Write pre-match Elo/probabilities to BOTH rows (player/opponent views)
    player_elo_pre_vec[i1]   <- R1; opponent_elo_pre_vec[i1] <- R2
    player_elo_pre_vec[i2]   <- R2; opponent_elo_pre_vec[i2] <- R1
    player_win_prob_vec[i1]  <- P1; opponent_win_prob_vec[i1] <- P2
    player_win_prob_vec[i2]  <- P2; opponent_win_prob_vec[i2] <- P1

    # Identify winner/loser from one row (both rows agree)
    mr1 <- t_players_dt$match_result[i1]
    mr2 <- t_players_dt$match_result[i2]
    is_missing_scalar <- function(x) length(x) != 1L || is.na(x)
    if (is_missing_scalar(mr1) || is_missing_scalar(mr2)) next

    if (mr1 == "win") {
      w_code <- p1; l_code <- p2; Rw <- R1; Rl <- R2
      mr     <- if ("match_ret" %in% names(t_players_dt)) t_players_dt$match_ret[i1] else NA_character_
      w_idx  <- p1_idx; l_idx <- p2_idx
    } else {
      w_code <- p2; l_code <- p1; Rw <- R2; Rl <- R1
      mr     <- if ("match_ret" %in% names(t_players_dt)) t_players_dt$match_ret[i2] else NA_character_
      w_idx  <- p2_idx; l_idx <- p1_idx
    }

    Nw <- match_count[w_idx]
    Nl <- match_count[l_idx]
    Pw <- 1 / (1 + 10^(-(Rw - Rl) / 400))
    Kw <- if (Nw < prov_threshold) K_prov else K_base
    Kl <- if (Nl < prov_threshold) K_prov else K_base
    Kp <- max(Kw, Kl)  # pairing K

    # Adjust K for special results
    K_adj <- if (is.na(mr)) {
      Kp
    } else if (mr == "(RET)") {
      Kp * 0.5
    } else if (mr %in% c("(W/O)", "W/O")) {
      0
    } else {
      Kp
    }
    if (K_adj <= 0) next

    # Elo delta for winner (loser gets the symmetric negative)
    delta <- K_adj * (1 - Pw)

    # Accumulate by player (winner)
    if (!w_code %in% names(delta_by_player)) delta_by_player[w_code] <- 0
    delta_by_player[w_code] <- delta_by_player[w_code] + delta

    # Accumulate by player (loser)
    if (!l_code %in% names(delta_by_player)) delta_by_player[l_code] <- 0
    delta_by_player[l_code] <- delta_by_player[l_code] - delta

    # Count match appearances (both sides)
    if (!w_code %in% names(cnt_by_player)) cnt_by_player[w_code] <- 0L
    if (!l_code %in% names(cnt_by_player)) cnt_by_player[l_code] <- 0L
    cnt_by_player[w_code] <- cnt_by_player[w_code] + 1L
    cnt_by_player[l_code] <- cnt_by_player[l_code] + 1L
  }

  # ---- Pass 2: apply all Elo deltas and match counts AFTER the round
  if (length(delta_by_player)) {
    for (code in names(delta_by_player)) {
      idx <- player_index[code]
      elo_vector[idx] <- elo_vector[idx] + delta_by_player[code]
    }
  }
  if (length(cnt_by_player)) {
    for (code in names(cnt_by_player)) {
      idx <- player_index[code]
      match_count[idx] <- match_count[idx] + cnt_by_player[code]
    }
  }
}

t_players_dt <- order_datasets(t_players_dt)

# ----------------------
# 4) Assign computed columns
# ----------------------
t_players_dt[, player_elo_pre    := player_elo_pre_vec]
t_players_dt[, opponent_elo_pre  := opponent_elo_pre_vec]
t_players_dt[, player_win_prob   := player_win_prob_vec]
t_players_dt[, opponent_win_prob := opponent_win_prob_vec]
t_players_dt[, elo_diff          := player_elo_pre - opponent_elo_pre]

# ----------------------
# 5) Final ordering and copy back to data.frame
# ----------------------
t_players_dt <- order_datasets(t_players_dt)
t_players    <- order_datasets(t_players)

# Copy selected columns to original data.frame (keeps all existing variables)
cols_add <- c("player_elo_pre", "opponent_elo_pre", "player_win_prob", "opponent_win_prob", "elo_diff")
for (cc in cols_add) {
  t_players[[cc]] <- t_players_dt[[cc]]
}

# ----------------------
# 6) Save & quick sanity prints
# ----------------------
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)

cat("Elo enrichment complete.\n")
cat("Unique players processed:", length(all_players), "\n")
cat("Elo range (post-processing):", paste(range(elo_vector), collapse = " .. "), "\n")
cat("Rows with non-NA player_elo_pre:", sum(!is.na(t_players$player_elo_pre)), "\n")
