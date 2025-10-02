#!/usr/bin/env Rscript
##
## Export Oracle → CSV
## - all_matches_99-25.csv
## - tournaments.csv  (only table with a date: start_dtm)
## - players.csv
##
## Dependencies: DBI, odbc (or ROracle), optionally data.table / readr for fast CSV writes.
##

suppressPackageStartupMessages({
  library(DBI)
  # Prefer ODBC for portability; if you use ROracle, see the alternative connect() below.
  library(odbc)
})

# ------------------------------------------------------------------------------
# 1) Constants & setup
# ------------------------------------------------------------------------------

# constants.R is expected to define (either as variables or via a list `constants`):
#   ORACLE_DSN, ORACLE_USER, ORACLE_PASSWORD, OUTPUT_DIR
source("constants.R")

# Normalize constants whether they are variables or a list
if (exists("constants") && is.list(constants)) {
  ORACLE_DSN      <- constants$ORACLE_DSN
  ORACLE_USER     <- constants$ORACLE_USER
  ORACLE_PASSWORD <- constants$ORACLE_PASSWORD
  OUTPUT_DIR      <- constants$OUTPUT_DIR
}

stopifnot(
  nzchar(ORACLE_DSN),
  nzchar(ORACLE_USER),
  nzchar(ORACLE_PASSWORD),
  nzchar(OUTPUT_DIR)
)

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

YEAR_FROM <- 1999L
YEAR_TO   <- 2025L

OUT_MATCHES     <- file.path(OUTPUT_DIR, "all_matches_99-25.csv")
OUT_TOURNAMENTS <- file.path(OUTPUT_DIR, "tournaments.csv")
OUT_PLAYERS     <- file.path(OUTPUT_DIR, "players.csv")

# ------------------------------------------------------------------------------
# 2) Utilities: connection and CSV writers
# ------------------------------------------------------------------------------

# Establish an Oracle connection (ODBC DSN-based).
connect <- function() {
  # If you use a full connection string instead of DSN,
  # replace with: dbConnect(odbc::odbc(), .connection_string = ORACLE_DSN, UID=..., PWD=...)
  dbConnect(odbc::odbc(), dsn = ORACLE_DSN, UID = ORACLE_USER, PWD = ORACLE_PASSWORD, timeout = 30)
}

# Alternative using ROracle (uncomment if you prefer):
# connect <- function() {
#   library(ROracle)
#   drv <- ROracle::Oracle()
#   dbConnect(drv, username = ORACLE_USER, password = ORACLE_PASSWORD, dbname = ORACLE_DSN)
# }

# Only tournaments have a date column: start_dtm. Normalize it to ISO strings.
normalize_tournaments_dates <- function(df) {
  if ("start_dtm" %in% names(df)) {
    x <- df[["start_dtm"]]
    if (inherits(x, "POSIXt")) {
      df[["start_dtm"]] <- format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC")
    } else if (inherits(x, "Date")) {
      df[["start_dtm"]] <- format(x, "%Y-%m-%d")
    }
  }
  df
}

# Fast, safe CSV writer with automatic fallback if data.table/readr are not available.
write_csv <- local({
  have_dt    <- requireNamespace("data.table", quietly = TRUE)
  have_readr <- requireNamespace("readr", quietly = TRUE)

  function(df, path) {
    if (have_dt) {
      data.table::fwrite(df, path, bom = FALSE, na = "", sep = ",")
    } else if (have_readr) {
      readr::write_csv(df, path, na = "")
    } else {
      utils::write.table(df, file = path, sep = ",", row.names = FALSE, col.names = TRUE, na = "")
    }
  }
})

# Stream a large query to CSV in chunks to avoid high memory usage.
write_csv_streaming <- function(con, sql, out_path, chunk_n = 200000L) {
  message(sprintf("→ Executing streaming export:\n   SQL: %s\n   OUT: %s",
                  gsub("\\s+", " ", substr(sql, 1, 160)), out_path))
  if (file.exists(out_path)) file.remove(out_path)

  rs <- dbSendQuery(con, sql)
  on.exit(try(dbClearResult(rs), silent = TRUE), add = TRUE)

  have_dt    <- requireNamespace("data.table", quietly = TRUE)
  have_readr <- requireNamespace("readr", quietly = TRUE)

  total <- 0L
  repeat {
    chunk <- dbFetch(rs, n = chunk_n)
    if (!nrow(chunk)) break

    if (total == 0L) {
      # first chunk: create file with header
      if (have_dt) {
        data.table::fwrite(chunk, out_path, bom = FALSE, na = "", sep = ",")
      } else if (have_readr) {
        readr::write_csv(chunk, out_path, na = "")
      } else {
        utils::write.table(chunk, file = out_path, sep = ",", row.names = FALSE, col.names = TRUE, na = "")
      }
    } else {
      # subsequent chunks: append without header
      if (have_dt) {
        data.table::fwrite(chunk, out_path, bom = FALSE, na = "", sep = ",", append = TRUE)
      } else if (have_readr) {
        readr::write_csv(chunk, out_path, na = "", append = TRUE)
      } else {
        utils::write.table(chunk, file = out_path, sep = ",", row.names = FALSE, col.names = FALSE, na = "", append = TRUE)
      }
    }

    total <- total + nrow(chunk)
    message(sprintf("   … %s rows written (cumulative)", format(total, big.mark = ",")))
  }
  invisible(total)
}

# ------------------------------------------------------------------------------
# 3) SQL definitions
# ------------------------------------------------------------------------------

# Matches: order by tournament.year/start_dtm via join (matches table has no dates).
SQL_MATCHES <- sprintf("
  SELECT m.*
  FROM   atp_matches m
  JOIN   atp_tournaments t
    ON   t.id = m.tournament_id
  WHERE  t.year BETWEEN %d AND %d
  ORDER  BY t.year, t.start_dtm, m.tournament_id, m.stadie_id
", YEAR_FROM, YEAR_TO)

# Tournaments: the only table with a date column (start_dtm).
SQL_TOURNAMENTS <- sprintf("
  SELECT *
  FROM   atp_tournaments
  WHERE  year BETWEEN %d AND %d
  ORDER  BY year, start_dtm, code
", YEAR_FROM, YEAR_TO)

# Players: no date columns.
SQL_PLAYERS <- "
  SELECT *
  FROM   atp_players
  ORDER  BY last_name, first_name, code
"

# ------------------------------------------------------------------------------
# 4) Main: connect, export, disconnect
# ------------------------------------------------------------------------------

main <- function() {
  con <- connect()
  on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)

  # Optional: set session date format (harmless for non-date tables).
  try(DBI::dbExecute(con, "alter session set nls_date_format = 'YYYY-MM-DD'"), silent = TRUE)

  # --- Tournaments (normalize start_dtm only) ---------------------------------
  message("=== Exporting tournaments ===")
  tournaments <- DBI::dbGetQuery(con, SQL_TOURNAMENTS)
  tournaments <- normalize_tournaments_dates(tournaments)
  write_csv(tournaments, OUT_TOURNAMENTS)
  message(sprintf("✔ tournaments.csv written: %s rows", nrow(tournaments)))

  # --- Players (no date columns) ----------------------------------------------
  message("=== Exporting players ===")
  players <- DBI::dbGetQuery(con, SQL_PLAYERS)
  write_csv(players, OUT_PLAYERS)
  message(sprintf("✔ players.csv written: %s rows", nrow(players)))

  # --- Matches (no date columns; stream for large volumes) --------------------
  message("=== Exporting matches (1999–2025) ===")
  n <- write_csv_streaming(con, SQL_MATCHES, OUT_MATCHES, chunk_n = 200000L)
  message(sprintf("✔ all_matches_99-25.csv written: %s rows", format(n, big.mark=",")))

  message("✅ Done.")
}

if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("✖ Export failed: ", conditionMessage(e))
    quit(status = 1)
  })
}
