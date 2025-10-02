# =============================================================================
# Enrich player-centric match datasets with player metadata from `players.csv`
# - Reads:
#     - pred_jugadores_99-25.csv (player-centric for modeling)
#     - data_jugadores_99-25.csv (player-centric, full columns)
#     - players.csv (master player attributes: handedness, backhand, etc.)
# - Adds player & opponent attributes (handedness, backhand, turned_pro, height, weight)
# - Audits missing `turned_pro` to identify likely debut/unknown records
# - Exports updated CSVs and a list of player codes with missing `turned_pro`
#   for targeted backfilling via scraping.
# NOTE: Logic preserved; refactored for readability and commented for clarity.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(data.table)
})

# -- I/O setup ---------------------------------------------------------------
setwd("")
options(max.print = 1e6)

# Base inputs
t_data    <- fread("data_jugadores_99-25.csv")    # player-centric, full columns
t_players <- fread("pred_jugadores_99-25.csv")    # player-centric for prediction
players   <- fread("players.csv")                 # player master data

# Quick peek (interactive): available columns in player master
colnames(players)

# Ensure uniqueness by player code to avoid accidental row-multiplication on joins
players <- players %>% distinct(code, .keep_all = TRUE)

# -- Helper: attach player & opponent metadata -------------------------------
attach_player_meta <- function(df, players_df) {
  df %>%
    # Join player attributes and rename with 'player_' prefix
    left_join(
      players_df %>% select(code, handedness, backhand, turned_pro, height, weight),
      by = c("player_code" = "code")
    ) %>%
    rename(
      player_handedness = handedness,
      player_backhand   = backhand,
      player_turned_pro = turned_pro,
      player_height     = height,
      player_weight     = weight
    ) %>%
    # Join opponent attributes and rename with 'opponent_' prefix
    left_join(
      players_df %>% select(code, handedness, backhand, turned_pro, height, weight),
      by = c("opponent_code" = "code")
    ) %>%
    rename(
      opponent_handedness = handedness,
      opponent_backhand   = backhand,
      opponent_turned_pro = turned_pro,
      opponent_height     = height,
      opponent_weight     = weight
    )
}

# -- Enrich datasets ---------------------------------------------------------
t_players <- attach_player_meta(t_players, players)
t_data    <- attach_player_meta(t_data,    players)

# -- Quick audit: % of missing turned_pro on the player side -----------------
mean(is.na(t_players$player_turned_pro)) * 100

# -- Collect player codes with missing 'turned_pro' for scraping backfill ----
jugadores_na <- t_players %>%
  filter(is.na(player_turned_pro)) %>%
  distinct(player_code) %>%
  rename(code = player_code)

oponentes_na <- t_players %>%
  filter(is.na(opponent_turned_pro)) %>%
  distinct(opponent_code) %>%
  rename(code = opponent_code)

jugadores <- bind_rows(jugadores_na, oponentes_na) %>%
  distinct(code) %>%
  arrange(code)

# -- Persist artifacts --------------------------------------------------------
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
write.csv(t_data,    "data_jugadores_99-25.csv", row.names = FALSE)

# (Interactive) Inspect distinct player names present post-enrichment
unique(t_players$player_name)
