####################################################################################################
# Rest/Travel/Load Proxies for Tennis ML (player_* & opponent_*) — with pre-99 seeding + QA
# --------------------------------------------------------------------------------------------------
# Purpose
#   Enrich a player-centric match table (t_players) with *tournament-level* rest/travel/load proxies
#   for both roles (player/opponent) without creating duplicates or target leakage. These proxies
#   help explain performance variability due to schedule density, travel, and contextual adaptation.
#
# What the script does
#   • Orders the dataset in a stable, chronological way before any lag/shift (critical for no-leakage).
#   • Builds one row per (code, tournament_id) and computes, for each role:
#       - Rest windows since the previous *observed* tournament:
#           days_since_prev_tournament, weeks_since_prev_tournament,
#           back_to_back_week (≤9d), two_weeks_gap (10–16d), long_rest (≥21d).
#       - Travel/adaptation deltas between consecutive tournaments:
#           country_changed, surface_changed, indoor_changed, continent_changed.
#       - Combined signals:
#           red_eye_risk = back_to_back_week & continent_changed,
#           travel_fatigue = 2*continent + 1*country + 1*surface + 0.5*indoor.
#       - Previous tournament load (from the prior event in time):
#           prev_tour_matches, prev_tour_max_round (aligned to main phase ladder).
#   • Seeds “previous tournament” signals for pre-1999 careers using Jeff Sackmann’s archive:
#       - If a player turned pro < 1999 and has no prior event in our 1999+ window, fill
#         prev_tour_* from that player’s *last* pre-99 tournament (matches and max round).
#       - Ensures the seeded date is strictly earlier than the current tournament (anti-future guard).
#   • Adds the new variables back to t_players via clean LEFT JOINs:
#       join keys are (player_code/opponent_code, tournament_id); only new prefixed columns are added.
#
# Inputs / Outputs
#   • Input files:
#       - pred_jugadores_99-25.csv  (player-centric match data, 1999+)
#       - JeffSackman/all_matches.csv (historical matches; used only for pre-99 seeding)
#   • Output:
#       - pred_jugadores_99-25.csv overwritten with the new, prefixed feature columns.
#
# Anti-leakage & Ordering
#   • All “previous” definitions come from strictly earlier tournaments for the same code.
#   • Ordering key: (tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order).
#   • Any pre-99 seeded date equal/after current start is discarded.
#
# Definitions & Conventions
#   • Phase alignment: maps “ER”→“R128” to unify pre-99 rounds with the post-99 ladder.
#   • turned_pro ≈ year - floor(years_experience) (best-effort; NAs propagated safely).
#   • Country→continent uses a static offline dictionary (deterministic, no network calls).
#
# QA / Validation
#   • Reports NA% of all newly created variables for both roles.
#   • Random trace validator reconstructs the “actual previous tournament” and checks:
#       days/weeks since previous, B2B/2-weeks/long-rest flags, prev_tour_matches/max_round.
#     Prints a compact accuracy summary per role.
#
# Design notes
#   • Idempotent merges (no duplicates), role-symmetric computation, data.table for speed.
#   • Thresholds (≤9, 10–16, ≥21 days) and fatigue weights kept simple and transparent.
#   • Minimal refactor of your logic; semantics preserved, readability and safeguards improved.
####################################################################################################

library(data.table)
library(dplyr)
library(lubridate)

# --------------------------------------------------------------------------------------------------
# Load
# --------------------------------------------------------------------------------------------------
setwd("")
t_players <- fread("pred_jugadores_99-25.csv")

# --------------------------------------------------------------------------------------------------
# Constants & ordering helpers
# --------------------------------------------------------------------------------------------------
orden_fases      <- c("Q1","Q2","Q3","BR","RR","R128","R64","R32","R16","QF","SF","F","3P")
orden_fases_full <- c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F","3P")

order_datasets <- function(df) {
  if ("tournament_start_dtm" %in% names(df) && !inherits(df$tournament_start_dtm, c("Date","POSIXt"))) {
    df$tournament_start_dtm <- as.Date(df$tournament_start_dtm)
  }
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(tournament_start_dtm, tournament_name, tournament_id, stadie_id, match_order)
}

order_datasets_dt <- function(DT) {
  if ("tournament_start_dtm" %in% names(DT) && !inherits(DT$tournament_start_dtm, c("Date","POSIXt"))) {
    DT[, tournament_start_dtm := as.Date(tournament_start_dtm)]
  }
  DT[, stadie_id := factor(stadie_id, levels = orden_fases, ordered = TRUE)]
  setorderv(DT, c("tournament_start_dtm","tournament_name","tournament_id","stadie_id","match_order"))
  invisible(DT)
}

t_players <- order_datasets(t_players)

# --------------------------------------------------------------------------------------------------
# Pre-99 seeding (Jeff Sackmann) — used to initialize prev_tour_* and prev_start when needed
# --------------------------------------------------------------------------------------------------
data_pre99 <- fread("/home/aitor/Descargas/Project/Data/JeffSackman/all_matches.csv",
                    select = c("tourney_date","tourney_id","round","winner_code","loser_code"))
data_pre99[, tourney_date := ymd(as.character(tourney_date))]
data_pre99 <- data_pre99[!is.na(tourney_date) & tourney_date < as.Date("1999-01-01")]

# Last seen date pre-99 by player
pre99_last_seen <- rbindlist(list(
  data_pre99[, .(player_code = winner_code, last_pre_date = tourney_date)],
  data_pre99[, .(player_code = loser_code,  last_pre_date = tourney_date)]
))[, .(last_pre_date = max(last_pre_date, na.rm = TRUE)), by = player_code]

# Aggregate last pre-99 tournament by player: matches and max round
pre_long <- rbindlist(list(
  data_pre99[, .(player_code = winner_code, tourney_id, tourney_date, round)],
  data_pre99[, .(player_code = loser_code,  tourney_id, tourney_date, round)]
), use.names = TRUE)
pre_long[, round_rank_full := as.integer(factor(round, levels = orden_fases_full, ordered = TRUE))]

pre_agg_tour <- pre_long[, .(
  seed_prev_tour_matches_full   = .N,
  seed_prev_tour_max_round_full = max(round_rank_full, na.rm = TRUE)
), by = .(player_code, tourney_id, tourney_date)]
setorder(pre_agg_tour, player_code, tourney_date, seed_prev_tour_matches_full, seed_prev_tour_max_round_full)
pre99_prev_tour_seed <- pre_agg_tour[, .SD[.N], by = player_code]  # last pre-99 tournament

# Map ER→R128 to align with main phases
map_full_to_main <- function(code_vec) { out <- code_vec; out[out == "ER"] <- "R128"; out }
code_full <- orden_fases_full[pre99_prev_tour_seed$seed_prev_tour_max_round_full]
code_main <- map_full_to_main(code_full)
pre99_prev_tour_seed[, seed_prev_tour_max_round :=
                       as.integer(factor(code_main, levels = orden_fases, ordered = TRUE))]
pre99_prev_tour_seed[, seed_prev_tour_matches := seed_prev_tour_matches_full]
pre99_prev_tour_seed <- pre99_prev_tour_seed[, .(player_code, seed_prev_tour_matches, seed_prev_tour_max_round)]

# --------------------------------------------------------------------------------------------------
# Country→continent (static offline dictionary)
# --------------------------------------------------------------------------------------------------
country_continent <- c(
  "AUS"="Oceania","QAT"="Asia","NZL"="Oceania","GER"="Europe","USA"="North America",
  "IND"="Asia","FRA"="Europe","URU"="South America","UAE"="Asia","RUS"="Europe",
  "NED"="Europe","VIE"="Asia","GBR"="Europe","DEN"="Europe","SGP"="Asia",
  "JPN"="Asia","ECU"="South America","MAR"="Africa","ITA"="Europe","POR"="Europe",
  "CHN"="Asia","ESP"="Europe","BER"="North America","MON"="Europe","CZE"="Europe",
  "SLO"="Europe","ISR"="Asia","AUT"="Europe","BUL"="Europe","CRO"="Europe",
  "SUI"="Europe","SWE"="Europe","CAN"="North America","BEL"="Europe","ARG"="South America",
  "FIN"="Europe","TUR"="Europe","BRA"="South America","POL"="Europe","SMR"="Europe",
  "UKR"="Europe","ROU"="Europe","HUN"="Europe","MKD"="Europe","UZB"="Asia",
  "EGY"="Africa","PER"="South America","CHI"="South America","AND"="Europe",
  "MEX"="North America","VEN"="South America","COL"="South America","SVK"="Europe",
  "KOR"="Asia","CRC"="North America","THA"="Asia","SRB"="Europe","TUN"="Africa",
  "BIH"="Europe","BOL"="South America","LUX"="Europe","IRI"="Asia","IRL"="Europe",
  "PAR"="South America","RSA"="Africa","KAZ"="Asia","TPE"="Asia","MAS"="Asia",
  "GRE"="Europe","CAL"="Oceania","GUD"="North America","PAN"="North America",
  "HKG"="Asia","DOM"="North America","PHI"="Asia","BRN"="Asia","LTU"="Europe",
  "PUR"="North America","KSA"="Asia","RWA"="Africa","GEO"="Europe","COD"="Africa",
  "CIV"="Africa","MDA"="Europe"
)

# --------------------------------------------------------------------------------------------------
# Core: compute proxies per role (player/opponent) — returns ONLY new prefixed columns
# --------------------------------------------------------------------------------------------------
.compute_role_proxies <- function(DT, role = c("player","opponent"),
                                  pre99_last_seen = NULL,
                                  pre99_prev_tour_seed = NULL) {
  role   <- match.arg(role)
  code_col <- if (role == "player") "player_code" else "opponent_code"
  yexp_col <- if (role == "player") "player_years_experience" else "opponent_years_experience"
  prefix   <- paste0(role, "_")

  # 1) Unique (code, tournament_id) row with tournament-level info for that role
  setorderv(DT, c(code_col,"tournament_start_dtm","tournament_name","tournament_id","stadie_id","match_order"))
  PT <- DT[, .SD[1L],
           by = c(code_col,"tournament_id"),
           .SDcols = c("tournament_start_dtm","tournament_name","tournament_country","surface","indoor_outdoor","year", yexp_col)]
  setnames(PT, old = c(code_col, yexp_col), new = c("code","years_exp"))

  # 2) turned_pro from (year – floor(years_exp)) if available
  PT[, turned_pro := suppressWarnings(as.integer(year - floor(years_exp)))]
  PT[!is.finite(turned_pro), turned_pro := NA_integer_]

  # 3) Temporal shifts within code
  setorder(PT, code, tournament_start_dtm, tournament_name, tournament_id)
  PT[, prev_start   := shift(tournament_start_dtm, 1L), by = code]
  PT[, prev_country := shift(tournament_country, 1L),   by = code]
  PT[, prev_surface := shift(surface, 1L),              by = code]
  PT[, prev_indoor  := shift(indoor_outdoor, 1L),       by = code]

  # 4) Continent (from dictionary) + lag
  PT[, continent      := country_continent[tournament_country]]
  PT[, prev_continent := shift(continent, 1L), by = code]

  # 5) Pre-99 "last seen" seeding into prev_start_final when needed (and strictly in the past)
  if (!is.null(pre99_last_seen)) {
    last_dt <- copy(pre99_last_seen)
    if ("player_code" %in% names(last_dt)) setnames(last_dt, "player_code", "code")
    PT <- last_dt[PT, on = "code"]
    PT[, prev_start_final := prev_start]
    PT[is.na(prev_start_final) & !is.na(last_pre_date) & !is.na(turned_pro) & turned_pro < 1999,
       prev_start_final := last_pre_date]
    PT[!is.na(prev_start_final) & prev_start_final >= tournament_start_dtm, prev_start_final := NA]
    PT[, last_pre_date := NULL]
  } else {
    PT[, prev_start_final := prev_start]
  }

  # 6) Rest windows from prev_start_final
  PT[, (paste0(prefix, "days_since_prev_tournament"))  := as.numeric(difftime(tournament_start_dtm, prev_start_final, units = "days"))]
  PT[, (paste0(prefix, "weeks_since_prev_tournament")) := get(paste0(prefix, "days_since_prev_tournament"))/7]
  PT[, (paste0(prefix, "back_to_back_week"))           := as.integer(!is.na(get(paste0(prefix, "days_since_prev_tournament"))) &
                                                                     get(paste0(prefix, "days_since_prev_tournament")) <= 9)]
  PT[, (paste0(prefix, "two_weeks_gap"))               := as.integer(!is.na(get(paste0(prefix, "days_since_prev_tournament"))) &
                                                                     get(paste0(prefix, "days_since_prev_tournament")) > 9 &
                                                                     get(paste0(prefix, "days_since_prev_tournament")) <= 16)]
  PT[, (paste0(prefix, "long_rest"))                   := as.integer(!is.na(get(paste0(prefix, "days_since_prev_tournament"))) &
                                                                     get(paste0(prefix, "days_since_prev_tournament")) >= 21)]

  # 7) Travel/adaptation deltas
  PT[, (paste0(prefix, "country_changed"))   := as.integer(!is.na(prev_country)   & tournament_country != prev_country)]
  PT[, (paste0(prefix, "surface_changed"))   := as.integer(!is.na(prev_surface)   & surface            != prev_surface)]
  PT[, (paste0(prefix, "indoor_changed"))    := as.integer(!is.na(prev_indoor)    & indoor_outdoor     != prev_indoor)]
  PT[, (paste0(prefix, "continent_changed")) := as.integer(!is.na(prev_continent) & continent          != prev_continent)]

  # 8) Combined signals: red-eye (= back-to-back + inter-continent), simple travel_fatigue score
  PT[, (paste0(prefix, "red_eye_risk")) :=
        as.integer(get(paste0(prefix, "back_to_back_week")) == 1 &
                   get(paste0(prefix, "continent_changed"))  == 1)]
  PT[, (paste0(prefix, "travel_fatigue")) :=
        2*get(paste0(prefix, "continent_changed")) +
        1*get(paste0(prefix, "country_changed"))   +
        1*get(paste0(prefix, "surface_changed"))   +
        0.5*get(paste0(prefix, "indoor_changed"))]

  # 9) Previous tournament load (matches, max round) with pre-99 seeding fallback
  AGG <- DT[, .(tour_matches = .N,
                tour_max_round = max(as.integer(stadie_id), na.rm = TRUE),
                tournament_start_dtm = tournament_start_dtm[1L]),
            by = c(code_col, "tournament_id")]
  setnames(AGG, code_col, "code")
  setorder(AGG, code, tournament_start_dtm, tournament_id)
  AGG[, prev_tour_matches   := shift(tour_matches, 1L), by = code]
  AGG[, prev_tour_max_round := shift(tour_max_round, 1L), by = code]

  if (!is.null(pre99_prev_tour_seed)) {
    seed_dt <- copy(pre99_prev_tour_seed)
    if ("player_code" %in% names(seed_dt)) setnames(seed_dt, "player_code", "code")
    tp_by_code <- unique(PT[, .(code, turned_pro)])
    AGG <- seed_dt[AGG, on = "code"]
    AGG <- tp_by_code[AGG, on = "code"]

    AGG[is.na(prev_tour_matches)   & !is.na(turned_pro) & turned_pro < 1999 & !is.na(seed_prev_tour_matches),
        prev_tour_matches := seed_prev_tour_matches]
    AGG[is.na(prev_tour_max_round) & !is.na(turned_pro) & turned_pro < 1999 & !is.na(seed_prev_tour_max_round),
        prev_tour_max_round := seed_prev_tour_max_round]

    AGG[, c("seed_prev_tour_matches","seed_prev_tour_max_round","turned_pro") := NULL]
  }

  # 10) Keep ONLY prefixed outputs for merging
  AGG_keep <- AGG[, .(code, tournament_id, prev_tour_matches, prev_tour_max_round)]
  setnames(AGG_keep,
           c("prev_tour_matches","prev_tour_max_round"),
           c(paste0(prefix, "prev_tour_matches"), paste0(prefix, "prev_tour_max_round")))

  proxy_cols <- c(paste0(prefix, c(
    "days_since_prev_tournament","weeks_since_prev_tournament",
    "back_to_back_week","two_weeks_gap","long_rest",
    "country_changed","surface_changed","indoor_changed","continent_changed",
    "red_eye_risk","travel_fatigue"
  )))
  PT_keep <- PT[, c("code","tournament_id", proxy_cols), with = FALSE]

  OUT <- merge(PT_keep, AGG_keep, by = c("code","tournament_id"), all.x = TRUE, sort = FALSE)
  setnames(OUT, "code", paste0(role, "_code"))
  OUT[]
}

# --------------------------------------------------------------------------------------------------
# Public function: add both roles’ proxies to t_players (no duplicates)
# --------------------------------------------------------------------------------------------------
add_rest_travel_proxies_both_roles <- function(DT,
                                               pre99_last_seen = NULL,
                                               pre99_prev_tour_seed = NULL) {
  stopifnot(is.data.table(DT))
  order_datasets_dt(DT)

  RES_p <- .compute_role_proxies(DT, "player",   pre99_last_seen, pre99_prev_tour_seed)
  RES_o <- .compute_role_proxies(DT, "opponent", pre99_last_seen, pre99_prev_tour_seed)

  DT <- merge(DT, RES_p, by = c("player_code","tournament_id"),  all.x = TRUE, sort = FALSE)
  DT <- merge(DT, RES_o, by = c("opponent_code","tournament_id"), all.x = TRUE, sort = FALSE)

  # Compact integer flags
  int_flags <- grep("_(back_to_back_week|two_weeks_gap|long_rest|country_changed|surface_changed|indoor_changed|continent_changed|red_eye_risk)$",
                    names(DT), value = TRUE)
  for (v in int_flags) DT[, (v) := as.integer(get(v))]

  order_datasets_dt(DT)
  DT
}

# --------------------------------------------------------------------------------------------------
# EXECUTION
# --------------------------------------------------------------------------------------------------
setDT(t_players)
t_players <- add_rest_travel_proxies_both_roles(
  t_players,
  pre99_last_seen      = pre99_last_seen,
  pre99_prev_tour_seed = pre99_prev_tour_seed
)

# --------------------------------------------------------------------------------------------------
# Quick QA: NA% + small distribution checks
# --------------------------------------------------------------------------------------------------
t_players <- order_datasets(t_players)
n <- nrow(t_players)

new_vars_player <- paste0("player_", c(
  "days_since_prev_tournament","weeks_since_prev_tournament",
  "back_to_back_week","two_weeks_gap","long_rest",
  "country_changed","surface_changed","indoor_changed","continent_changed",
  "red_eye_risk","travel_fatigue",
  "prev_tour_matches","prev_tour_max_round"
))
new_vars_opponent <- sub("^player_", "opponent_", new_vars_player)
new_vars <- intersect(c(new_vars_player, new_vars_opponent), names(t_players))

cat("=== NA% for newly added variables ===\n")
for (v in new_vars) {
  na_n   <- t_players[, sum(is.na(get(v)))]
  na_pct <- 100 * na_n / n
  cat(sprintf("%-36s: %7d / %-7d  (%.2f%% NA)\n", v, na_n, n, na_pct))
}

cat("\nplayer_prev_tour_max_round (labels are 1..", length(orden_fases), "):\n", sep = "")
print(table(t_players$player_prev_tour_max_round, useNA = "ifany"))
cat("\nopponent_prev_tour_max_round:\n")
print(table(t_players$opponent_prev_tour_max_round, useNA = "ifany"))

cat("\nplayer_red_eye_risk counts:\n")
print(table(t_players$player_red_eye_risk, useNA = "ifany"))

# --------------------------------------------------------------------------------------------------
# Validation by random sampling (trace back the actual previous tournament) — role-symmetric
# --------------------------------------------------------------------------------------------------
round_label <- function(x) {
  out <- rep(NA_character_, length(x))
  ok  <- !is.na(x) & x >= 1 & x <= length(orden_fases)
  out[ok] <- orden_fases[x[ok]]
  out
}

.build_ut <- function(DT, role=c("player","opponent")) {
  role <- match.arg(role)
  code_col   <- if (role=="player") "player_code" else "opponent_code"
  turned_col <- if (role=="player") "player_turned_pro" else "opponent_turned_pro"

  tmp <- copy(DT)
  setorderv(tmp, c(code_col,"tournament_start_dtm","tournament_name","tournament_id","stadie_id","match_order"))
  tmp[, code := get(code_col)]
  tmp[, turned_pro := suppressWarnings(as.integer(get(turned_col)))]

  # One stable row per (code, tournament_id)
  UT <- tmp[, .(
    tournament_start_dtm = tournament_start_dtm[1L],
    tournament_name      = tournament_name[1L],
    tournament_country   = tournament_country[1L],
    turned_pro           = turned_pro[1L]
  ), by = .(code, tournament_id)]

  UT[, continent := country_continent[tournament_country]]
  setorder(UT, code, tournament_start_dtm, tournament_name, tournament_id)
  UT[, prev_tournament_id := shift(tournament_id, 1L),        by = code]
  UT[, prev_start         := shift(tournament_start_dtm, 1L), by = code]
  UT[, prev_country       := shift(tournament_country, 1L),   by = code]
  UT[, prev_continent     := shift(continent, 1L),            by = code]

  # Pre-99 last-seen (if available in env)
  if (exists("pre99_last_seen")) {
    last_dt <- copy(pre99_last_seen)
    setnames(last_dt, "player_code", "code")
    UT <- last_dt[UT, on = "code"]
    UT[, prev_start_final := prev_start]
    UT[is.na(prev_start_final) & !is.na(last_pre_date) & !is.na(turned_pro) & turned_pro < 1999,
       prev_start_final := last_pre_date]
    UT[, last_pre_date := NULL]
  } else {
    UT[, prev_start_final := prev_start]
  }
  UT[]
}

.compute_prev_tour_stats <- function(DT, code, prev_tid, role=c("player","opponent")) {
  role <- match.arg(role)
  code_col <- if (role=="player") "player_code" else "opponent_code"
  if (is.na(prev_tid)) return(list(matches=NA_integer_, max_round=NA_integer_, rounds_played=NA_character_))
  sub <- DT[get(code_col)==code & tournament_id==prev_tid, .(stadie_id)]
  if (nrow(sub)==0) return(list(matches=0L, max_round=NA_integer_, rounds_played=NA_character_))
  sub[, r_idx := as.integer(factor(stadie_id, levels = orden_fases, ordered = TRUE))]
  mx <- suppressWarnings(max(sub$r_idx, na.rm = TRUE)); if (is.infinite(mx)) mx <- NA_integer_
  rounds_played <- paste(sort(unique(round_label(sub$r_idx))), collapse = ",")
  list(matches = nrow(sub), max_round = mx, rounds_played = rounds_played)
}

validate_random_trace <- function(DT, role=c("player","opponent"), n=20L, seed=42L) {
  role <- match.arg(role); set.seed(seed)
  UT <- .build_ut(DT, role)
  pool <- UT[!is.na(prev_start_final)]
  if (nrow(pool) == 0L) stop("No rows with prev_start_final for role: ", role)

  smp <- pool[sample(.N, min(n, .N))]
  smp[, days_exp := as.numeric(difftime(tournament_start_dtm, prev_start_final, units = "days"))]
  smp[, wks_exp  := days_exp/7]
  smp[, b2_exp   := as.integer(!is.na(days_exp) & days_exp <= 9)]
  smp[, two_exp  := as.integer(!is.na(days_exp) & days_exp > 9 & days_exp <= 16)]
  smp[, long_exp := as.integer(!is.na(days_exp) & days_exp >= 21)]

  real_cols <- c(
    paste0(role,"_days_since_prev_tournament"),
    paste0(role,"_weeks_since_prev_tournament"),
    paste0(role,"_back_to_back_week"),
    paste0(role,"_two_weeks_gap"),
    paste0(role,"_long_rest"),
    paste0(role,"_prev_tour_matches"),
    paste0(role,"_prev_tour_max_round")
  )
  real_tab <- unique(DT[, c(if (role=="player") "player_code" else "opponent_code",
                            "tournament_id", real_cols), with=FALSE])
  setnames(real_tab, names(real_tab)[1], "code")
  smp <- real_tab[smp, on = c("code","tournament_id")]

  res_list <- vector("list", nrow(smp))
  for (i in seq_len(nrow(smp))) {
    res_list[[i]] <- .compute_prev_tour_stats(DT, smp$code[i], smp$prev_tournament_id[i], role)
  }
  smp[, prev_matches_exp   := vapply(res_list, `[[`, integer(1),  "matches")]
  smp[, prev_max_round_exp := vapply(res_list, `[[`, integer(1),  "max_round")]
  smp[, prev_rounds_played := vapply(res_list, `[[`, character(1), "rounds_played")]

  tol <- 0.5
  smp[, chk_days  := ifelse(is.na(days_exp) & is.na(get(paste0(role,"_days_since_prev_tournament"))), TRUE,
                            !is.na(days_exp) & !is.na(get(paste0(role,"_days_since_prev_tournament"))) &
                              abs(days_exp - get(paste0(role,"_days_since_prev_tournament"))) <= tol)]
  smp[, chk_weeks := ifelse(is.na(wks_exp) & is.na(get(paste0(role,"_weeks_since_prev_tournament"))), TRUE,
                            !is.na(wks_exp) & !is.na(get(paste0(role,"_weeks_since_prev_tournament"))) &
                              abs(wks_exp - get(paste0(role,"_weeks_since_prev_tournament"))) <= 1e-6)]
  smp[, chk_b2    := (b2_exp   == get(paste0(role,"_back_to_back_week")))  | (is.na(b2_exp)   & is.na(get(paste0(role,"_back_to_back_week"))))]
  smp[, chk_two   := (two_exp  == get(paste0(role,"_two_weeks_gap")))      | (is.na(two_exp)  & is.na(get(paste0(role,"_two_weeks_gap"))))]
  smp[, chk_long  := (long_exp == get(paste0(role,"_long_rest")))          | (is.na(long_exp) & is.na(get(paste0(role,"_long_rest"))))]
  smp[, chk_prevM := (prev_matches_exp   == get(paste0(role,"_prev_tour_matches")))   |
        (is.na(prev_matches_exp)   & is.na(get(paste0(role,"_prev_tour_matches"))))]
  smp[, chk_prevR := (prev_max_round_exp == get(paste0(role,"_prev_tour_max_round"))) |
        (is.na(prev_max_round_exp) & is.na(get(paste0(role,"_prev_tour_max_round"))))]

  report <- smp[, .(
    role        = role,
    code,
    curr_tid    = tournament_id,
    curr_start  = tournament_start_dtm,
    prev_tid    = prev_tournament_id,
    prev_start  = prev_start_final,
    days_exp,
    days_real   = get(paste0(role,"_days_since_prev_tournament")),
    b2_exp,   b2_real   = get(paste0(role,"_back_to_back_week")),
    two_exp,  two_real  = get(paste0(role,"_two_weeks_gap")),
    long_exp, long_real = get(paste0(role,"_long_rest")),
    prev_matches_exp,
    prev_matches_real   = get(paste0(role,"_prev_tour_matches")),
    prev_max_round_exp,
    prev_max_round_real = get(paste0(role,"_prev_tour_max_round")),
    prev_rounds_played  = prev_rounds_played,
    label_prev_max_exp  = round_label(prev_max_round_exp),
    label_prev_max_real = round_label(get(paste0(role,"_prev_tour_max_round"))),
    OK_days  = chk_days,
    OK_flags = chk_b2 & chk_two & chk_long,
    OK_prevM = chk_prevM,
    OK_prevR = chk_prevR
  )]

  cat(sprintf("\n=== RANDOM TRACE %s ===\n", toupper(role))); print(report)
  cat("\nAccuracy summary:\n")
  cat(sprintf("days:   %d / %d\n", sum(report$OK_days,  na.rm=TRUE), nrow(report)))
  cat(sprintf("flags:  %d / %d\n", sum(report$OK_flags, na.rm=TRUE), nrow(report)))
  cat(sprintf("prevM:  %d / %d\n", sum(report$OK_prevM, na.rm=TRUE), nrow(report)))
  cat(sprintf("prevR:  %d / %d\n", sum(report$OK_prevR, na.rm=TRUE), nrow(report)))

  invisible(report[])
}

# Run validation samples (adjust N if needed)
rep_player   <- validate_random_trace(t_players, "player",   n = 20L, seed = 123)
rep_opponent <- validate_random_trace(t_players, "opponent", n = 20L, seed = 456)

# --------------------------------------------------------------------------------------------------
# Persist enriched table
# --------------------------------------------------------------------------------------------------
fwrite(t_players, "pred_jugadores_99-25.csv")
