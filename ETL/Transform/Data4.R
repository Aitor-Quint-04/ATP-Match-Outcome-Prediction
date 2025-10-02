# =============================================================================
# Career & Titles Enrichment for Player-Centric ATP Datasets (1999–2025)
# -----------------------------------------------------------------------------
# This script augments two player-centric datasets with:
#   1) Debut/turned-pro reconciliation and years of experience per player.
#   2) Pre-1999 career aggregates (matches, wins) from Jeff Sackmann’s archive,
#      merged with since-1999 rolling counts to form total wins/matches and win rate
#      at the time of each match (no look-ahead).
#   3) Cumulative prestigious titles (GS/1000/500/250/ATP Finals/OG) per player and
#      opponent across the timeline, seeded with pre-1999 titles.
#   4) Separate accumulation for Grand Slam titles only, likewise pre-seeded.
#
# Ordering is deterministic within tournament by (date, name, id, round, match_order),
# so cumulative features are time-consistent and leakage-free.
#
# Inputs:
#   - pred_jugadores_99-25.csv  (player-centric, modeling-friendly)
#   - data_jugadores_99-25.csv  (player-centric, full columns)
#   - tournaments.csv            (tournament master, used here for some joins/checks)
#   - player_debuts.csv          (player debut years; used to fill missing turned_pro)
#   - JeffSackmann all_matches.csv (historic matches; pre-1999 used for seeding)
#
# Outputs (in-place overwrite):
#   - pred_jugadores_99-25.csv
#   - data_jugadores_99-25.csv
#
# Notes:
#   • All cumulative metrics are computed strictly up to (not including) the row’s match.
#   • Round ordering is enforced via ordered factors to guarantee stable cumulation.
#   • Sanity checks at the end verify counters increase immediately after a title is won.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

setwd("")
options(max.print = 100)

# -----------------------------
# Load inputs
# -----------------------------
t_data       <- read.csv("data_jugadores_99-25.csv", stringsAsFactors = FALSE, check.names = FALSE)
t_players    <- read.csv("pred_jugadores_99-25.csv", stringsAsFactors = FALSE, check.names = FALSE)
torneos      <- read.csv("tournaments.csv",            stringsAsFactors = FALSE, check.names = FALSE)

#####################################################
#####################################################
#I had to do some extra web scraping to find the player debuts whose debut year was NA. 
#I'll leave that as homework to whoever's reading this.
##############################################################
#############################################################
debuts <- read.csv(
  "player_debuts.csv",
  stringsAsFactors = FALSE, check.names = FALSE
)

matches_pre99_all <- read.csv(
  "JeffSackman/all_matches.csv",
  stringsAsFactors = FALSE, check.names = FALSE
)

# -----------------------------
# Prepare pre-1999 matches
# -----------------------------
matches_pre99 <- matches_pre99_all %>%
  filter(year < 1999) %>%
  rename(
    stadie_id       = round,
    tournament_id   = tourney_id,
    tournament_category = tourney_level
  ) %>%
  mutate(
    # Map Sackmann levels to your internal categories (partial map as in original)
    tournament_category = case_when(
      tournament_category == "G" ~ "gs",
      tournament_category == "M" ~ "1000",
      tournament_category == "A" ~ "atp500",
      TRUE ~ tournament_category
    )
  )

# -----------------------------
# Round ordering helpers
# -----------------------------
orden_fases        <- c("Q1","Q2","Q3","BR","RR","R128","R64","R32","R16","QF","SF","F","3P")
orden_fases_pre99  <- c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F")

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

# -----------------------------
# 1) Update debut / turned_pro using debut file
# -----------------------------
update_debut_years <- function(df, debut_df) {
  df %>%
    left_join(
      debut_df %>% select(player_code = player_code, player_debut = debut_year),
      by = "player_code"
    ) %>%
    left_join(
      debut_df %>% select(opponent_code = player_code, opponent_debut = debut_year),
      by = "opponent_code"
    ) %>%
    mutate(
      player_turned_pro   = coalesce(player_turned_pro,   player_debut),
      opponent_turned_pro = coalesce(opponent_turned_pro, opponent_debut)
    ) %>%
    select(-player_debut, -opponent_debut)
}

t_data    <- update_debut_years(t_data, debuts)
t_players <- update_debut_years(t_players, debuts)

# Drop rows missing turned_pro on either side (report how many)
drop_na_turnpro <- function(df, label) {
  n_before <- nrow(df)
  df2 <- df %>% filter(!is.na(player_turned_pro), !is.na(opponent_turned_pro))
  n_after <- nrow(df2)
  cat(sprintf("%s: removed %s rows due to missing turned_pro (%s -> %s)\n",
              label,
              format(n_before - n_after, big.mark = ","),
              format(n_before,            big.mark = ","),
              format(n_after,             big.mark = ",")))
  df2
}

t_data    <- drop_na_turnpro(t_data,    "t_data")
t_players <- drop_na_turnpro(t_players, "t_players")

# -----------------------------
# 2) Years of experience (at match year)
# -----------------------------
add_experience <- function(df) {
  df %>%
    mutate(
      across(c(year, player_turned_pro, opponent_turned_pro),
             ~ suppressWarnings(as.numeric(.))),
      player_years_experience   = year - player_turned_pro,
      opponent_years_experience = year - opponent_turned_pro
    )
}

t_players <- add_experience(t_players)
t_data    <- add_experience(t_data)

# -----------------------------
# 3) Pre-1999 ordering & aggregates (no look-ahead)
# -----------------------------
matches_pre99 <- matches_pre99 %>%
  mutate(
    match_date = as.Date(as.character(tourney_date), "%Y%m%d"),
    stadie_id  = factor(stadie_id, levels = orden_fases_pre99, ordered = TRUE)
  ) %>%
  arrange(match_date, tournament_id, stadie_id, match_num)

# Pre-1999 career counts by name
pre99_stats <- bind_rows(
  matches_pre99 %>% transmute(name = winner_name, result = "win"),
  matches_pre99 %>% transmute(name = loser_name,  result = "loss")
) %>%
  group_by(name) %>%
  summarise(
    pre99_matches = n(),
    pre99_wins    = sum(result == "win"),
    .groups = "drop"
  )

# -----------------------------
# 4) Cumulative since-1999 + pre-1999 seed = career stats at match time
# -----------------------------
calculate_career_stats <- function(df, pre99_df) {
  # Player-side accumulation (wins for player == match_result == "win")
  player_stats <- df %>%
    group_by(player_name) %>%
    arrange(
      tournament_start_dtm,
      factor(stadie_id, levels = orden_fases, ordered = TRUE),
      match_order,
      id,
      .by_group = TRUE
    ) %>%
    mutate(
      wins_since99    = lag(cumsum(match_result == "win"), default = 0L),
      matches_since99 = row_number() - 1L
    ) %>%
    ungroup() %>%
    left_join(pre99_df, by = c("player_name" = "name")) %>%
    mutate(
      pre99_wins        = coalesce(pre99_wins, 0L),
      pre99_matches     = coalesce(pre99_matches, 0L),
      player_matches_won   = pre99_wins + wins_since99,
      player_total_matches = pre99_matches + matches_since99,
      player_win_rate      = ifelse(player_total_matches > 0,
                                    player_matches_won / player_total_matches,
                                    NA_real_)
    ) %>%
    select(id, player_name, player_matches_won, player_total_matches, player_win_rate)

  # Opponent-side accumulation (wins for opponent == match_result == "loss")
  opponent_stats <- df %>%
    group_by(opponent_name) %>%
    arrange(
      tournament_start_dtm,
      factor(stadie_id, levels = orden_fases, ordered = TRUE),
      match_order,
      id,
      .by_group = TRUE
    ) %>%
    mutate(
      wins_since99    = lag(cumsum(match_result == "loss"), default = 0L),
      matches_since99 = row_number() - 1L
    ) %>%
    ungroup() %>%
    left_join(pre99_df, by = c("opponent_name" = "name")) %>%
    mutate(
      pre99_wins             = coalesce(pre99_wins, 0L),
      pre99_matches          = coalesce(pre99_matches, 0L),
      opponent_matches_won   = pre99_wins + wins_since99,
      opponent_total_matches = pre99_matches + matches_since99,
      opponent_win_rate      = ifelse(opponent_total_matches > 0,
                                      opponent_matches_won / opponent_total_matches,
                                      NA_real_)
    ) %>%
    select(id, opponent_name, opponent_matches_won, opponent_total_matches, opponent_win_rate)

  # Combine onto original rows
  df %>%
    left_join(player_stats,   by = c("id", "player_name")) %>%
    left_join(opponent_stats, by = c("id", "opponent_name"))
}

# Ensure ordered before accumulations
t_players <- order_datasets(t_players)
t_data    <- order_datasets(t_data)

# Apply career stats
t_players <- calculate_career_stats(t_players, pre99_stats)
t_data    <- calculate_career_stats(t_data,    pre99_stats)

# -----------------------------
# 5) Prestigious titles accumulation (GS/1000/500/250/ATP Finals/OG)
# -----------------------------
prestigious_titles <- c("gs", "1000", "atp500", "atp250", "atpFinal", "og")
all_players <- unique(t_players$player_name)

# Seed pre-1999 prestigious titles
pre99_prestigious_titles <- data.frame(
  player = all_players,
  pre99_prestigious_titles = 0L,
  stringsAsFactors = FALSE
)

# Count prestigious finals won pre-1999 (winner_name in your cohort)
prestigious_wins <- matches_pre99 %>%
  filter(
    stadie_id == "F",
    tournament_category %in% prestigious_titles,
    winner_name %in% all_players
  ) %>%
  group_by(winner_name) %>%
  summarise(actual_titles = n(), .groups = "drop")

pre99_prestigious_titles <- pre99_prestigious_titles %>%
  left_join(prestigious_wins, by = c("player" = "winner_name")) %>%
  mutate(
    pre99_prestigious_titles = ifelse(!is.na(actual_titles), actual_titles, pre99_prestigious_titles)
  ) %>%
  select(-actual_titles)

# Rolling prestigious titles during 1999–2025, seeded by pre-1999
update_player_titles <- function(df) {
  df %>%
    group_by(player_name) %>%
    arrange(tournament_start_dtm, .by_group = TRUE) %>%
    mutate(
      is_title_win = as.integer(stadie_id == "F" &
                                match_result == "win" &
                                tournament_category %in% prestigious_titles),
      player_prestigious_titles =
        coalesce(player_pre99_prestigious_titles, 0L) +
        lag(cumsum(is_title_win), default = 0L)
    ) %>%
    ungroup() %>%
    select(-is_title_win, -player_pre99_prestigious_titles)
}

update_opponent_titles <- function(df) {
  df %>%
    group_by(opponent_name) %>%
    arrange(tournament_start_dtm, .by_group = TRUE) %>%
    mutate(
      is_title_win = as.integer(stadie_id == "F" &
                                match_result == "loss" &
                                tournament_category %in% prestigious_titles),
      opponent_prestigious_titles =
        coalesce(opponent_pre99_prestigious_titles, 0L) +
        lag(cumsum(is_title_win), default = 0L)
    ) %>%
    ungroup() %>%
    select(-is_title_win, -opponent_pre99_prestigious_titles)
}

# Apply (player & opponent) with pre-99 seeds
t_players <- order_datasets(t_players)
t_data    <- order_datasets(t_data)

t_players <- t_players %>%
  left_join(pre99_prestigious_titles, by = c("player_name"   = "player")) %>%
  rename(player_pre99_prestigious_titles = pre99_prestigious_titles) %>%
  left_join(pre99_prestigious_titles, by = c("opponent_name" = "player")) %>%
  rename(opponent_pre99_prestigious_titles = pre99_prestigious_titles) %>%
  update_player_titles() %>%
  update_opponent_titles()

t_data <- t_data %>%
  left_join(pre99_prestigious_titles, by = c("player_name"   = "player")) %>%
  rename(player_pre99_prestigious_titles = pre99_prestigious_titles) %>%
  left_join(pre99_prestigious_titles, by = c("opponent_name" = "player")) %>%
  rename(opponent_pre99_prestigious_titles = pre99_prestigious_titles) %>%
  update_player_titles() %>%
  update_opponent_titles()

# -----------------------------
# Sanity check: counter increases after a prestigious title
# -----------------------------
jugador_con_titulo <- t_players %>%
  filter(
    stadie_id == "F",
    match_result == "win",
    tournament_category %in% prestigious_titles,
    tournament_start_dtm > as.Date("2020-01-01")
  ) %>%
  arrange(tournament_start_dtm) %>%
  slice(1)

if (nrow(jugador_con_titulo) > 0) {
  jugador      <- jugador_con_titulo$player_name[1]
  fecha_titulo <- jugador_con_titulo$tournament_start_dtm[1]

  cat("=== Check: Player prestigious-title increment ===\n")
  cat("Player:", jugador, "\n")
  cat("Title date:", as.character(fecha_titulo), "\n")

  siguiente_partido <- t_players %>%
    filter(player_name == jugador, tournament_start_dtm > fecha_titulo) %>%
    arrange(tournament_start_dtm) %>%
    slice(1)

  if (nrow(siguiente_partido) > 0) {
    cat("\nTitle match:\n")
    print(jugador_con_titulo %>%
            select(player_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, player_prestigious_titles))

    cat("\nNext match:\n")
    print(siguiente_partido %>%
            select(player_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, player_prestigious_titles))

    diff_title <- siguiente_partido$player_prestigious_titles -
                  jugador_con_titulo$player_prestigious_titles

    cat("\nDelta titles:", diff_title, "\n")
    if (isTRUE(diff_title == 1)) cat("✅ Counter increased correctly!\n")
    else                         cat("❌ Counter did NOT increase as expected.\n")
  } else {
    cat("No next match found for", jugador, "\n")
  }
} else {
  cat("No prestigious-title winners found in the selected period (player perspective)\n")
}

# Opponent perspective: their counter should increase when the row’s player loses the final
oponente_con_titulo <- t_players %>%
  filter(
    stadie_id == "F",
    match_result == "loss",
    tournament_category %in% prestigious_titles,
    tournament_start_dtm > as.Date("2020-01-01")
  ) %>%
  arrange(tournament_start_dtm) %>%
  slice(1)

if (nrow(oponente_con_titulo) > 0) {
  oponente       <- oponente_con_titulo$opponent_name[1]
  fecha_titulo_op <- oponente_con_titulo$tournament_start_dtm[1]

  cat("\n=== Check: Opponent prestigious-title increment ===\n")
  cat("Opponent:", oponente, "\n")
  cat("Title date:", as.character(fecha_titulo_op), "\n")

  siguiente_partido_op <- t_players %>%
    filter((player_name == oponente | opponent_name == oponente),
           tournament_start_dtm > fecha_titulo_op) %>%
    arrange(tournament_start_dtm) %>%
    slice(1)

  if (nrow(siguiente_partido_op) > 0) {
    cat("\nTitle match (opponent view):\n")
    print(oponente_con_titulo %>%
            select(opponent_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, opponent_prestigious_titles))

    cat("\nOpponent next match:\n")
    print(siguiente_partido_op %>%
            select(player_name, opponent_name, tournament_start_dtm, stadie_id,
                   match_result, player_prestigious_titles, opponent_prestigious_titles))

    titulo_siguiente <- ifelse(
      siguiente_partido_op$player_name == oponente,
      siguiente_partido_op$player_prestigious_titles,
      siguiente_partido_op$opponent_prestigious_titles
    )

    diff_op <- titulo_siguiente - oponente_con_titulo$opponent_prestigious_titles

    cat("\nDelta titles:", diff_op, "\n")
    if (isTRUE(diff_op == 1)) cat("✅ Opponent counter increased correctly!\n")
    else                      cat("❌ Opponent counter did NOT increase as expected.\n")
  } else {
    cat("No next match found for", oponente, "\n")
  }
} else {
  cat("No prestigious-title winners found (opponent perspective) in the selected period\n")
}

# -----------------------------
# 6) Grand Slam titles (only "gs")
# -----------------------------
grand_slam_category <- "gs"
all_players <- unique(t_players$player_name)

# Pre-seed GS titles pre-1999 for players in cohort
pre99_gs_titles <- data.frame(player = all_players, pre99_gs_titles = 0L, stringsAsFactors = FALSE)

gs_wins_pre99 <- matches_pre99 %>%
  filter(
    stadie_id == "F",
    tournament_category == grand_slam_category,
    winner_name %in% all_players
  ) %>%
  group_by(winner_name) %>%
  summarise(gs_titles = n(), .groups = "drop")

pre99_gs_titles <- pre99_gs_titles %>%
  left_join(gs_wins_pre99, by = c("player" = "winner_name")) %>%
  mutate(pre99_gs_titles = ifelse(!is.na(gs_titles), gs_titles, pre99_gs_titles)) %>%
  select(-gs_titles)

update_gs_titles <- function(df, pre99_df) {
  # Attach pre-seed
  df <- df %>%
    left_join(pre99_df, by = c("player_name"   = "player")) %>%
    rename(player_pre99_gs_titles   = pre99_gs_titles) %>%
    left_join(pre99_df, by = c("opponent_name" = "player")) %>%
    rename(opponent_pre99_gs_titles = pre99_gs_titles)

  # Accumulate per timeline
  df %>%
    group_by(player_name) %>%
    arrange(tournament_start_dtm, .by_group = TRUE) %>%
    mutate(
      is_gs_title_win = as.integer(stadie_id == "F" &
                                   match_result == "win" &
                                   tournament_category == grand_slam_category),
      player_gs_titles =
        coalesce(player_pre99_gs_titles, 0L) +
        lag(cumsum(is_gs_title_win), default = 0L)
    ) %>%
    group_by(opponent_name) %>%
    arrange(tournament_start_dtm, .by_group = TRUE) %>%
    mutate(
      is_gs_title_win_opp = as.integer(stadie_id == "F" &
                                       match_result == "loss" &
                                       tournament_category == grand_slam_category),
      opponent_gs_titles =
        coalesce(opponent_pre99_gs_titles, 0L) +
        lag(cumsum(is_gs_title_win_opp), default = 0L)
    ) %>%
    ungroup() %>%
    select(-is_gs_title_win, -is_gs_title_win_opp,
           -player_pre99_gs_titles, -opponent_pre99_gs_titles)
}

t_players <- order_datasets(t_players)
t_data    <- order_datasets(t_data)

t_players <- update_gs_titles(t_players, pre99_gs_titles)
t_data    <- update_gs_titles(t_data,    pre99_gs_titles)

# -----------------------------
# Sanity check: GS increment right after a GS title
# -----------------------------
jugador_con_gs <- t_players %>%
  filter(
    stadie_id == "F",
    match_result == "win",
    tournament_category == "gs",
    # Fix the date literal to ISO; original used "99-01-01" which parses to year 0099.
    tournament_start_dtm > as.Date("1999-01-01")
  ) %>%
  arrange(tournament_start_dtm) %>%
  slice(1)

if (nrow(jugador_con_gs) > 0) {
  jugador   <- jugador_con_gs$player_name[1]
  fecha_gs  <- jugador_con_gs$tournament_start_dtm[1]

  cat("=== Check: Player GS-title increment ===\n")
  cat("Player:", jugador, "\n")
  cat("GS date:", as.character(fecha_gs), "\n")

  siguiente_partido_gs <- t_players %>%
    filter(player_name == jugador, tournament_start_dtm > fecha_gs) %>%
    arrange(tournament_start_dtm) %>%
    slice(1)

  if (nrow(siguiente_partido_gs) > 0) {
    cat("\nGS title match:\n")
    print(jugador_con_gs %>%
            select(player_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, player_gs_titles))

    cat("\nNext match:\n")
    print(siguiente_partido_gs %>%
            select(player_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, player_gs_titles))

    diff_gs <- siguiente_partido_gs$player_gs_titles - jugador_con_gs$player_gs_titles

    cat("\nDelta GS:", diff_gs, "\n")
    if (isTRUE(diff_gs == 1)) cat("✅ GS counter increased correctly!\n")
    else                      cat("❌ GS counter did NOT increase as expected.\n")
  } else {
    cat("No next match found for", jugador, "\n")
  }
} else {
  cat("No GS winners found (player perspective) in the selected period\n")
}

oponente_con_gs <- t_players %>%
  filter(
    stadie_id == "F",
    match_result == "loss",
    tournament_category == "gs",
    tournament_start_dtm > as.Date("1999-01-01")
  ) %>%
  arrange(tournament_start_dtm) %>%
  slice(1)

if (nrow(oponente_con_gs) > 0) {
  oponente    <- oponente_con_gs$opponent_name[1]
  fecha_gs_op <- oponente_con_gs$tournament_start_dtm[1]

  cat("\n=== Check: Opponent GS-title increment ===\n")
  cat("Opponent:", oponente, "\n")
  cat("GS date:", as.character(fecha_gs_op), "\n")

  siguiente_partido_gs_op <- t_players %>%
    filter((opponent_name == oponente), tournament_start_dtm > fecha_gs_op) %>%
    arrange(tournament_start_dtm) %>%
    slice(1)

  if (nrow(siguiente_partido_gs_op) > 0) {
    cat("\nGS title match (opponent view):\n")
    print(oponente_con_gs %>%
            select(opponent_name, tournament_start_dtm, stadie_id,
                   match_result, tournament_category, opponent_gs_titles))

    cat("\nOpponent next match:\n")
    print(siguiente_partido_gs_op %>%
            select(player_name, opponent_name, tournament_start_dtm, stadie_id,
                   match_result, player_gs_titles, opponent_gs_titles))

    gs_next <- ifelse(
      siguiente_partido_gs_op$player_name == oponente,
      siguiente_partido_gs_op$player_gs_titles,
      siguiente_partido_gs_op$opponent_gs_titles
    )

    diff_gs_op <- gs_next - oponente_con_gs$opponent_gs_titles

    cat("\nDelta GS:", diff_gs_op, "\n")
    if (isTRUE(diff_gs_op == 1)) cat("✅ Opponent GS counter increased correctly!\n")
    else                         cat("❌ Opponent GS counter did NOT increase as expected.\n")
  } else {
    cat("No next match found for", oponente, "\n")
  }
} else {
  cat("No GS winners found (opponent perspective) in the selected period\n")
}

# -----------------------------
# Persist enriched datasets
# -----------------------------
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
write.csv(t_data,    "data_jugadores_99-25.csv", row.names = FALSE)

# Quick health signals
cat("\nNA rate for player_win_rate:", mean(is.na(t_players$player_win_rate)), "\n")
cat("Distinct tournament categories in t_players:\n")
print(unique(t_players$tournament_category))
