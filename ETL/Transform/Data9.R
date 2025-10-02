############################################################################################
# Full-Pipeline H2H Features (Global and Surface-Specific) with Pre-1999 Backfill
# ------------------------------------------------------------------------------------------
# Goal
#   Compute head-to-head (H2H) features for every match row in a player-centric ATP dataset
#   (1999–2025), leveraging pre-1999 (1968–1998) historical matches to seed prior encounters.
#   We produce:
#     • player_h2h_full_win_ratio / player_h2h_total_matches:
#         Cumulative H2H win ratio (and sample size) versus the current opponent, computed
#         *strictly before* the current match, using a chronologically ordered, deduplicated
#         sequence of prior meetings from both eras (pre-99 + 99–25).
#     • player_h2h_surface_win_ratio / player_h2h_surface_total_matches:
#         Same as above, but *restricted to the current match surface* (normalized to
#         {"Clay","Grass","Carpet","Hard"}).
#
# Design & Guardrails
#   • Two-perspective rows per match:
#       The working table (t_players) is player-centric (one row per player per match).
#   • Causality / no leakage:
#       We construct a chronological join key, event_key = as.integer(date)*100 + round_order,
#       so that multiple rounds on the same date (e.g., R16, QF) are ordered and prior H2H
#       stats reflect *only* meetings that happened strictly earlier (event_key < current).
#   • Pre-1999 backfill:
#       Pre-1999 matches (Sackmann) are cast into the same two-perspective shape and merged,
#       so H2H history includes the entire Open Era up to the current event.
#   • Robust deduplication:
#       We collapse per-pair meetings by (player1, player2, event_key[, surface]) so multiple
#       rows of the same match/event are not double-counted.
#   • Ordering:
#       A stable tournament ordering (date → tournament name → tournament id → round → match)
#       ensures deterministic results.
#
# Outputs
#   • Enriched t_players with H2H global and surface-specific ratios and counts.
#   • The script writes the result back to pred_jugadores_99-25.csv.
############################################################################################

library(data.table)
library(dplyr)

setwd("/home/aitor/Descargas/Project/Data/Msolonskyi")
# Cargar datasets
data_pre99 <- fread("/home/aitor/Descargas/Project/Data/JeffSackman/all_matches.csv")
data_pre99 <- data_pre99[year < 1999, ]  # Filtrar partidos antes de 1999
data_pre99[, date := as.Date(as.character(tourney_date), format = "%Y%m%d")]  # Convertir tourney_date a Date

t_players <- fread("pred_jugadores_99-25.csv")
t_players[, tournament_start_dtm := as.Date(tournament_start_dtm)]  # Convertir tournament_start_dtm a Date

orden_fases <- c("Q1", "Q2", "Q3", "BR", "RR", "R128", "R64", "R32", "R16", "QF", "SF", "F", "3P")
# --- NUEVO: orden con 'ER' para pre-99 y desempate intra-día ---
orden_fases_full <- c("Q1","Q2","Q3","BR","RR","ER","R128","R64","R32","R16","QF","SF","F","3P")

# Ordenar ambos datasets
order_datasets <- function(df) {
  df %>%
    mutate(stadie_id = factor(stadie_id, levels = orden_fases, ordered = TRUE)) %>%
    arrange(
      tournament_start_dtm,  # Orden cronológico principal
      tournament_name,                  # Desempate por nombre de torneo
      tournament_id,         # Agrupar por torneo completo
      stadie_id,              # Orden de fases dentro del torneo
      match_order
    )
}

t_players <- order_datasets(t_players)

# Transformar data_pre99 a la estructura de dos perspectivas por partido
data_pre99_long <- rbindlist(list(
  # Perspectiva del ganador
  data_pre99[, .(
    player_code = winner_code,
    opponent_code = loser_code,
    tournament_start_dtm = date,
    match_result = "win",
    round_stage = round
  )],
  # Perspectiva del perdedor
  data_pre99[, .(
    player_code = loser_code,
    opponent_code = winner_code,
    tournament_start_dtm = date,
    match_result = "loss",
    round_stage = round
  )]
), use.names = TRUE)

# Seleccionar las columnas necesarias de t_players
t_players_subset <- t_players[, .(player_code, opponent_code, tournament_start_dtm, match_result, stadie_id)]

# Renombrar stadie_id a round_stage para unificar con data_pre99
setnames(t_players_subset, "stadie_id", "round_stage")

# Combinar ambos datasets
combined_data <- rbindlist(list(data_pre99_long, t_players_subset), use.names = TRUE)

# Convertir round_stage a factor con los niveles de orden_fases_full (incluye ER)
combined_data[, round_stage := factor(round_stage, levels = orden_fases_full, ordered = TRUE)]
# --- NUEVO: claves intra-día por ronda ---
combined_data[, stadie_ord := as.integer(round_stage)]
combined_data[, event_key  := as.integer(tournament_start_dtm) * 100L + fifelse(is.na(stadie_ord), 0L, stadie_ord)]

# Función para ordenar los datasets
order_dataset <- function(df) {
  df %>%
    arrange(
      tournament_start_dtm,  # Orden cronológico principal
      round_stage            # Orden por fase del torneo
    )
}

# Ordenar el dataset combinado
combined_data <- order_dataset(combined_data)

# Filtrar filas sin NA y sin cadenas vacías en player_code y opponent_code
filtered_data <- combined_data[!is.na(player_code) & !is.na(opponent_code) &
                                 player_code != "" & opponent_code != ""]

# Crear una clave única para cada par ordenando los códigos alfabéticamente
filtered_data[, pair_key := paste(pmin(player_code, opponent_code), 
                                  pmax(player_code, opponent_code), sep = "_")]

filtered_data[, year := year(tournament_start_dtm)]

# Crear dataset de partidos únicos para calcular H2H
# --- CAMBIO: usar event_key (no solo fecha) para no colapsar partidos del mismo día en distintas rondas ---
unique_matches <- filtered_data[, .(
  player1 = pmin(player_code, opponent_code), 
  player2 = pmax(player_code, opponent_code),
  event_key,
  winner = ifelse(match_result == "win", player_code, opponent_code)
)][order(player1, player2, event_key)]

unique_matches <- unique(unique_matches, by = c("player1", "player2", "event_key"))

# Añadir indicador de victoria para player1
unique_matches[, player1_won := as.integer(winner == player1)]

# Calcular estadísticas acumulativas por par en orden temporal estricto
unique_matches[, `:=`(
  cum_matches = seq_len(.N),
  cum_wins_player1 = cumsum(player1_won)
), by = .(player1, player2)]

# En t_players, crear player1 and player2 para el join
t_players[, player1 := pmin(player_code, opponent_code)]
t_players[, player2 := pmax(player_code, opponent_code)]
# --- NUEVO: clave temporal actual usando su ronda real ---
t_players[, stadie_ord := as.integer(factor(stadie_id, levels = orden_fases_full, ordered = TRUE))]
t_players[, current_event_key := as.integer(tournament_start_dtm) * 100L + fifelse(is.na(stadie_ord), 0L, stadie_ord)]

# Establecer claves para el join no equi por event_key
setkey(unique_matches, player1, player2, event_key)
setkey(t_players,      player1, player2, current_event_key)

# Realizar join no equi: para cada partido en t_players, encontrar el último partido anterior (incluye rondas previas del mismo día)
t_players_with_h2h <- unique_matches[
  t_players, 
  on = .(player1, player2, event_key < current_event_key), 
  mult = "last"
]

# Reemplazar NA por 0 en las estadísticas acumulativas cuando no hay partidos anteriores
t_players_with_h2h[is.na(cum_matches), cum_matches := 0]
t_players_with_h2h[is.na(cum_wins_player1), cum_wins_player1 := 0]

# Calcular el ratio de victorias para el jugador actual
t_players_with_h2h[, is_player1 := player_code == player1]
t_players_with_h2h[, player_wins := ifelse(is_player1, cum_wins_player1, cum_matches - cum_wins_player1)]
t_players_with_h2h[, player_h2h_full_win_ratio := ifelse(cum_matches > 0, player_wins / cum_matches, NA)]
t_players_with_h2h[, player_h2h_total_matches := cum_matches]  # Esto será 0 cuando no hay partidos anteriores

# Eliminar columnas temporales
cols_to_remove <- c("player1", "player2", "winner", "player1_won", "cum_matches", "cum_wins_player1", "is_player1", "player_wins")
t_players_with_h2h[, (cols_to_remove) := NULL]

# Reemplazar t_players con el dataset enriquecido
t_players <- t_players_with_h2h

# (ya no se renombra match_date, no existe con event_key)
# Ordenar el dataset
t_players <- order_datasets(t_players)

# Verificar el resultado final
print(head(t_players[, .(player_code, opponent_code, player_h2h_full_win_ratio, player_h2h_total_matches)]))
print(paste("Porcentaje de NA en player_h2h_full_win_ratio:", mean(is.na(t_players$player_h2h_full_win_ratio)) * 100, "%"))

table(t_players$player_h2h_total_matches)

# Encontrar pares de jugadores que se han enfrentado más de 50 veces
frequent_opponents <- t_players[player_h2h_total_matches > 39, 
                                .(player_code, player_name, opponent_code, opponent_name, player_h2h_total_matches,player_h2h_full_win_ratio)]

# Crear una clave única para el par (ordenando los códigos)
frequent_opponents[, pair_key := paste(pmin(player_code, opponent_code), pmax(player_code, opponent_code), sep = "_")]

# Eliminar duplicados por la clave del par
frequent_opponents <- frequent_opponents[!duplicated(pair_key)]

# Eliminar la columna temporal pair_key
frequent_opponents[, pair_key := NULL]

# Ordenar por número de enfrentamientos descendente
setorder(frequent_opponents, -player_h2h_total_matches)

print("Pares de jugadores que se han enfrentado más de 50 veces:")
print(frequent_opponents)


# ==========================================================
# H2H POR SUPERFICIE
# ==========================================================
# Normalizar superficie en t_players y data_pre99_long
norm_surface <- function(s) {
  x <- tolower(trimws(as.character(s)))
  fifelse(grepl("clay", x), "Clay",
          fifelse(grepl("grass", x), "Grass",
                  fifelse(grepl("carpet", x), "Carpet",
                          fifelse(grepl("hard", x), "Hard", NA_character_)
                  )
          )
  )
}

# Transformar data_pre99 a la estructura de dos perspectivas por partido, incluyendo surface
data_pre99_long <- rbindlist(list(
  # Perspectiva del ganador
  data_pre99[, .(
    player_code = winner_code,
    opponent_code = loser_code,
    tournament_start_dtm = date,
    match_result = "win",
    round_stage = round,
    surface = norm_surface(surface)  # Normalizar superficie
  )],
  # Perspectiva del perdedor
  data_pre99[, .(
    player_code = loser_code,
    opponent_code = winner_code,
    tournament_start_dtm = date,
    match_result = "loss",
    round_stage = round,
    surface = norm_surface(surface)  # Normalizar superficie
  )]
), use.names = TRUE)

# También normalizar surface en t_players
t_players[, surface := norm_surface(surface)]

t_players <- order_datasets(t_players)

# Seleccionar las columnas necesarias de t_players, incluyendo surface
t_players_subset <- t_players[, .(player_code, opponent_code, tournament_start_dtm, match_result, stadie_id, surface)]

# Renombrar stadie_id a round_stage para unificar con data_pre99
setnames(t_players_subset, "stadie_id", "round_stage")

# Combinar ambos datasets
combined_data <- rbindlist(list(data_pre99_long, t_players_subset), use.names = TRUE)

# Convertir round_stage a factor con los niveles de orden_fases_full (incluye ER)
combined_data[, round_stage := factor(round_stage, levels = orden_fases_full, ordered = TRUE)]
# --- NUEVO: claves intra-día por ronda ---
combined_data[, stadie_ord := as.integer(round_stage)]
combined_data[, event_key  := as.integer(tournament_start_dtm) * 100L + fifelse(is.na(stadie_ord), 0L, stadie_ord)]

# Ordenar el dataset combinado
combined_data <- order_dataset(combined_data)

# Filtrar filas sin NA y sin cadenas vacías en player_code y opponent_code
filtered_data <- combined_data[!is.na(player_code) & !is.na(opponent_code) &
                                 player_code != "" & opponent_code != ""]

# Crear una clave única para cada par ordenando los códigos alfabéticamente
filtered_data[, pair_key := paste(pmin(player_code, opponent_code), 
                                  pmax(player_code, opponent_code), sep = "_")]

filtered_data[, year := year(tournament_start_dtm)]

# Calcular H2H en la superficie actual
# Crear dataset de partidos únicos para calcular H2H por superficie
surface_unique_matches <- filtered_data[, .(
  player1 = pmin(player_code, opponent_code), 
  player2 = pmax(player_code, opponent_code),
  surface,
  event_key,
  winner = ifelse(match_result == "win", player_code, opponent_code)
)][order(player1, player2, surface, event_key)]

surface_unique_matches <- unique(surface_unique_matches, by = c("player1", "player2", "surface", "event_key"))

# Añadir indicador de victoria para player1
surface_unique_matches[, player1_won := as.integer(winner == player1)]

# Calcular estadísticas acumulativas por par y superficie
surface_unique_matches[, `:=`(
  cum_matches_surface = seq_len(.N),
  cum_wins_player1_surface = cumsum(player1_won)
), by = .(player1, player2, surface)]

# En t_players, crear player1 and player2 para el join (si no se han creado ya)
t_players[, player1 := pmin(player_code, opponent_code)]
t_players[, player2 := pmax(player_code, opponent_code)]

# RECREAR current_event_key para el join no equi de superficie
t_players[, stadie_ord := as.integer(factor(stadie_id, levels = orden_fases, ordered = TRUE))]
t_players[, current_event_key := as.integer(tournament_start_dtm) * 100L + fifelse(is.na(stadie_ord), 0L, stadie_ord)]

t_players <- order_datasets(t_players)

# Establecer claves para el join no equi por superficie y event_key
setkey(surface_unique_matches, player1, player2, surface, event_key)
setkey(t_players, player1, player2, surface, current_event_key)

# Realizar join no equi para superficie (usa event_key)
t_players_with_surface_h2h <- surface_unique_matches[
  t_players, 
  on = .(player1, player2, surface, event_key < current_event_key), 
  mult = "last"
]

t_players_with_surface_h2h <- order_datasets(t_players_with_surface_h2h)

# Reemplazar NA por 0 en las estadísticas acumulativas cuando no hay partidos anteriores en la superficie
t_players_with_surface_h2h[is.na(cum_matches_surface), cum_matches_surface := 0]
t_players_with_surface_h2h[is.na(cum_wins_player1_surface), cum_wins_player1_surface := 0]

t_players_with_surface_h2h <- order_datasets(t_players_with_surface_h2h)

# Calcular el ratio de victorias en la superficie para el jugador actual
t_players_with_surface_h2h[, is_player1 := player_code == player1]
t_players_with_surface_h2h[, player_wins_surface := ifelse(is_player1, cum_wins_player1_surface, cum_matches_surface - cum_wins_player1_surface)]
t_players_with_surface_h2h[, player_h2h_surface_win_ratio := ifelse(cum_matches_surface > 0, player_wins_surface / cum_matches_surface, NA)]
t_players_with_surface_h2h[, player_h2h_surface_total_matches := cum_matches_surface]

t_players_with_surface_h2h <- order_datasets(t_players_with_surface_h2h)

# Enfoque alternativo: identificar y mantener todas las columnas excepto las temporales
all_cols <- names(t_players_with_surface_h2h)

cols_to_remove_surface <- c("winner", "player1_won", "cum_matches_surface", 
                            "cum_wins_player1_surface", "is_player1", 
                            "player_wins_surface", "player1", "player2")
cols_to_keep <- setdiff(all_cols, cols_to_remove_surface)

# Crear nuevo data.table con columnas a mantener
t_players_final <- t_players_with_surface_h2h[, ..cols_to_keep]

# Reemplazar t_players con el dataset final
t_players <- t_players_final

# Restaurar el nombre de la columna de fecha si es necesario (no aplicaría con event_key)
if ("match_date" %in% names(t_players)) {
  setnames(t_players, "match_date", "tournament_start_dtm")
}

write.csv(t_players,"pred_jugadores_99-25.csv",row.names=FALSE)
