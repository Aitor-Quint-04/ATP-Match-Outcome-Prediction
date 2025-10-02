# =============================================================================
# Join tournament metadata (start date, category, prize, country, surface, name,
# indoor/outdoor) onto player-centric datasets, and order rows chronologically.
#
# Inputs:
#   - pred_jugadores_99-25.csv  (player-centric, modeling-friendly)
#   - data_jugadores_99-25.csv  (player-centric, full columns)
#   - tournaments.csv           (tournament master with `start_dtm`)
#
# Outputs (in-place overwrite):
#   - pred_jugadores_99-25.csv
#   - data_jugadores_99-25.csv
#
# Notes:
#   • `start_dtm` in tournaments may be stored as YYYYMMDD (numeric or string).
#     We parse it robustly to Date.
#   • We keep the original column name `surface` as-is to preserve downstream
#     compatibility (instead of renaming to `tournament_surface`).
#   • Ordering uses a factor for `stadie_id` so knockout phases sort correctly.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

setwd("")

# -----------------------------
# Load data
# -----------------------------
t_players <- read.csv("pred_jugadores_99-25.csv", check.names = FALSE)
t_data    <- read.csv("data_jugadores_99-25.csv", check.names = FALSE)
torneos   <- read.csv("tournaments.csv",            check.names = FALSE)

# -----------------------------
# Helpers
# -----------------------------

# Robust parser for tournament start dates:
# - Accepts numeric or character YYYYMMDD
# - Falls back to `as.Date()` if already ISO 'YYYY-MM-DD' or Date-like
parse_tournament_start <- function(x) {
  x_chr <- trimws(as.character(x))
  # First try strict YYYYMMDD
  yyyymmdd <- ifelse(nchar(x_chr) == 8 & grepl("^\\d{8}$", x_chr), x_chr, NA_character_)
  dt <- as.Date(yyyymmdd, format = "%Y%m%d")
  # Fallback: let as.Date try default formats (e.g., 'YYYY-MM-DD')
  idx <- is.na(dt) & nzchar(x_chr)
  if (any(idx)) {
    suppressWarnings(dt[idx] <- as.Date(x_chr[idx]))
  }
  dt
}

# Left-join tournament metadata and normalize columns
add_tournament_date <- function(df, tournaments_df) {
  tournaments_df %>%
    select(dplyr::any_of(c(
      "id", "start_dtm", "series_category_id", "prize_money",
      "country_code", "surface", "name", "indoor_outdoor"
    ))) %>%
    # Join by tournament id
    right_join(df, by = c("id" = "tournament_id")) %>%  # right_join to preserve all rows of df
    rename(
      tournament_id      = id,
      tournament_start_dtm = start_dtm,
      tournament_category  = series_category_id,
      tournament_prize     = prize_money,
      tournament_country   = country_code,
      # Keep `surface` name unchanged on purpose (downstream code expects it)
      tournament_name      = name,
      indoor_outdoor       = indoor_outdoor
    ) %>%
    mutate(
      tournament_start_dtm = parse_tournament_start(tournament_start_dtm)
    ) %>%
    # Reorder a few key columns to the front if they exist
    {
      front <- intersect(
        c("tournament_start_dtm", "tournament_name", "tournament_id",
          "tournament_category", "tournament_prize", "tournament_country",
          "surface", "indoor_outdoor"),
        names(.)
      )
      select(., dplyr::all_of(front), dplyr::everything())
    }
}

# Sorting helper: ensure bracket phases have a meaningful order
orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")

order_datasets <- function(df) {
  has_stadie <- "stadie_id" %in% names(df)
  df <- df %>%
    { if (has_stadie) mutate(., stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) else . } %>%
    arrange(
      dplyr::across(dplyr::any_of(c("tournament_start_dtm"))),
      dplyr::across(dplyr::any_of(c("tournament_name"))),
      dplyr::across(dplyr::any_of(c("tournament_id"))),
      dplyr::across(dplyr::any_of(c("stadie_id")))
    )
  df
}

# -----------------------------
# Enrich + order
# -----------------------------
t_players <- t_players %>% add_tournament_date(torneos) %>% order_datasets()
t_data    <- t_data    %>% add_tournament_date(torneos) %>% order_datasets()

# -----------------------------
# Persist
# -----------------------------
write.csv(t_players, "pred_jugadores_99-25.csv", row.names = FALSE)
write.csv(t_data,    "data_jugadores_99-25.csv", row.names = FALSE)
