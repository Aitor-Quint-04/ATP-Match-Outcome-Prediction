-- Opcional: elimina primero si existe
-- DROP TABLE atp_matches CASCADE CONSTRAINTS;

CREATE TABLE atp_matches (
  id                             VARCHAR2(64)   NOT NULL,
  delta_hash                     NUMBER         NOT NULL,
  batch_id                       NUMBER(12)     NOT NULL,
  tournament_id                  VARCHAR2(64)   NOT NULL,
  stadie_id                      VARCHAR2(4)    NOT NULL,
  match_order                    NUMBER(4),
  match_ret                      VARCHAR2(10),
  winner_code                    VARCHAR2(4)    NOT NULL,
  loser_code                     VARCHAR2(4)    NOT NULL,
  winner_seed                    VARCHAR2(8),
  loser_seed                     VARCHAR2(8),
  score                          VARCHAR2(32),
  winner_sets_won                NUMBER(4),
  loser_sets_won                 NUMBER(4),
  winner_games_won               NUMBER(4),
  loser_games_won                NUMBER(4),
  winner_tiebreaks_won           NUMBER(4),
  loser_tiebreaks_won            NUMBER(4),
  stats_url                      VARCHAR2(256),
  match_duration                 NUMBER(4),

  win_aces                       NUMBER(4),
  win_double_faults              NUMBER(4),
  win_first_serves_in            NUMBER(4),
  win_first_serves_total         NUMBER(4),
  win_first_serve_points_won     NUMBER(4),
  win_first_serve_points_total   NUMBER(4),
  win_second_serve_points_won    NUMBER(4),
  win_second_serve_points_total  NUMBER(4),
  win_break_points_saved         NUMBER(4),
  win_break_points_serve_total   NUMBER(4),
  win_service_points_won         NUMBER(4),
  win_service_points_total       NUMBER(4),
  win_first_serve_return_won     NUMBER(4),
  win_first_serve_return_total   NUMBER(4),
  win_second_serve_return_won    NUMBER(4),
  win_second_serve_return_total  NUMBER(4),
  win_break_points_converted     NUMBER(4),
  win_break_points_return_total  NUMBER(4),
  win_service_games_played       NUMBER(4),
  win_return_games_played        NUMBER(4),
  win_return_points_won          NUMBER(4),
  win_return_points_total        NUMBER(4),
  win_total_points_won           NUMBER(4),
  win_total_points_total         NUMBER(4),

  win_winners                    NUMBER(4),
  win_forced_errors              NUMBER(4),
  win_unforced_errors            NUMBER(4),
  win_net_points_won             NUMBER(4),
  win_net_points_total           NUMBER(4),
  win_fastest_first_serves_kmh   NUMBER(4),
  win_average_first_serves_kmh   NUMBER(4),
  win_fastest_second_serve_kmh   NUMBER(4),
  win_average_second_serve_kmh   NUMBER(4),

  los_aces                       NUMBER(4),
  los_double_faults              NUMBER(4),
  los_first_serves_in            NUMBER(4),
  los_first_serves_total         NUMBER(4),
  los_first_serve_points_won     NUMBER(4),
  los_first_serve_points_total   NUMBER(4),
  los_second_serve_points_won    NUMBER(4),
  los_second_serve_points_total  NUMBER(4),
  los_break_points_saved         NUMBER(4),
  los_break_points_serve_total   NUMBER(4),
  los_service_points_won         NUMBER(4),
  los_service_points_total       NUMBER(4),
  los_first_serve_return_won     NUMBER(4),
  los_first_serve_return_total   NUMBER(4),
  los_second_serve_return_won    NUMBER(4),
  los_second_serve_return_total  NUMBER(4),
  los_break_points_converted     NUMBER(4),
  los_break_points_return_total  NUMBER(4),
  los_service_games_played       NUMBER(4),
  los_return_games_played        NUMBER(4),
  los_return_points_won          NUMBER(4),
  los_return_points_total        NUMBER(4),
  los_total_points_won           NUMBER(4),
  los_total_points_total         NUMBER(4),

  los_winners                    NUMBER(4),
  los_forced_errors              NUMBER(4),
  los_unforced_errors            NUMBER(4),
  los_net_points_won             NUMBER(4),
  los_net_points_total           NUMBER(4),
  los_fastest_first_serves_kmh   NUMBER(4),
  los_average_first_serves_kmh   NUMBER(4),
  los_fastest_second_serve_kmh   NUMBER(4),
  los_average_second_serve_kmh   NUMBER(4),

  winner_age                     NUMBER,
  loser_age                      NUMBER,

  win_h2h_qty_3y                 NUMBER,
  los_h2h_qty_3y                 NUMBER,
  win_win_qty_3y                 NUMBER,
  win_los_qty_3y                 NUMBER,
  los_win_qty_3y                 NUMBER,
  los_los_qty_3y                 NUMBER,
  win_avg_tiebreaks_3y           NUMBER,
  los_avg_tiebreaks_3y           NUMBER,

  win_h2h_qty_3y_current         NUMBER,
  los_h2h_qty_3y_current         NUMBER,
  win_win_qty_3y_current         NUMBER,
  win_los_qty_3y_current         NUMBER,
  los_win_qty_3y_current         NUMBER,
  los_los_qty_3y_current         NUMBER,
  win_avg_tiebreaks_3y_current   NUMBER,
  los_avg_tiebreaks_3y_current   NUMBER,

  win_ace_pct_3y                 NUMBER,
  win_df_pct_3y                  NUMBER,
  win_1st_pct_3y                 NUMBER,
  win_1st_won_pct_3y             NUMBER,
  win_2nd_won_pct_3y             NUMBER,
  win_bp_saved_pct_3y            NUMBER,
  win_srv_won_pct_3y             NUMBER,
  win_1st_return_won_pct_3y      NUMBER,
  win_2nd_return_won_pct_3y      NUMBER,
  win_bp_won_pct_3y              NUMBER,
  win_return_won_pct_3y          NUMBER,
  win_total_won_pct_3y           NUMBER,

  win_ace_pct_3y_current         NUMBER,
  win_df_pct_3y_current          NUMBER,
  win_1st_pct_3y_current         NUMBER,
  win_1st_won_pct_3y_current     NUMBER,
  win_2nd_won_pct_3y_current     NUMBER,
  win_bp_saved_pct_3y_current    NUMBER,
  win_srv_won_pct_3y_current     NUMBER,
  win_1st_return_won_pct_3y_cur  NUMBER,
  win_2nd_return_won_pct_3y_cur  NUMBER,
  win_bp_won_pct_3y_current      NUMBER,
  win_return_won_pct_3y_current  NUMBER,
  win_total_won_pct_3y_current   NUMBER,

  los_ace_pct_3y                 NUMBER,
  los_df_pct_3y                  NUMBER,
  los_1st_pct_3y                 NUMBER,
  los_1st_won_pct_3y             NUMBER,
  los_2nd_won_pct_3y             NUMBER,
  los_bp_saved_pct_3y            NUMBER,
  los_srv_won_pct_3y             NUMBER,
  los_1st_return_won_pct_3y      NUMBER,
  los_2nd_return_won_pct_3y      NUMBER,
  los_bp_won_pct_3y              NUMBER,
  los_return_won_pct_3y          NUMBER,
  los_total_won_pct_3y           NUMBER,

  los_ace_pct_3y_current         NUMBER,
  los_df_pct_3y_current          NUMBER,
  los_1st_pct_3y_current         NUMBER,
  los_1st_won_pct_3y_current     NUMBER,
  los_2nd_won_pct_3y_current     NUMBER,
  los_bp_saved_pct_3y_current    NUMBER,
  los_srv_won_pct_3y_current     NUMBER,
  los_1st_return_won_pct_3y_cur  NUMBER,
  los_2nd_return_won_pct_3y_cur  NUMBER,
  los_bp_won_pct_3y_current      NUMBER,
  los_return_won_pct_3y_current  NUMBER,
  los_total_won_pct_3y_current   NUMBER
);

-- Claves y restricciones
ALTER TABLE atp_matches
  ADD CONSTRAINT pk_atp_matches
  PRIMARY KEY (id);

ALTER TABLE atp_matches
  ADD CONSTRAINT unq_atp_matches
  UNIQUE (tournament_id, winner_code, loser_code, stadie_id);

ALTER TABLE atp_matches
  ADD CONSTRAINT unq_atp_matches$stats_url
  UNIQUE (stats_url);

ALTER TABLE atp_matches
  ADD CONSTRAINT fk_atp_matches$tournament_id
  FOREIGN KEY (tournament_id)
  REFERENCES atp_tournaments (id);

ALTER TABLE atp_matches
  ADD CONSTRAINT fk_atp_matches$stadie_id
  FOREIGN KEY (stadie_id)
  REFERENCES stadies (id);

ALTER TABLE atp_matches
  ADD CONSTRAINT fk_atp_matches$winner_code
  FOREIGN KEY (winner_code)
  REFERENCES atp_players (code);

ALTER TABLE atp_matches
  ADD CONSTRAINT fk_atp_matches$loser_code
  FOREIGN KEY (loser_code)
  REFERENCES atp_players (code);

-- Índices
CREATE INDEX ind_atp_matches$winner_code
  ON atp_matches (winner_code);

CREATE INDEX ind_atp_matches$loser_code
  ON atp_matches (loser_code);

CREATE INDEX ind_atp_matches$tournament_id
  ON atp_matches (tournament_id);
