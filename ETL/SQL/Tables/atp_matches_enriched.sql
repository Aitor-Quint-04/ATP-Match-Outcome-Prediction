CREATE TABLE atp_matches_enriched (
  -- Identificador y control
  id                              VARCHAR2(64)   NOT NULL,
  delta_hash                      NUMBER         NOT NULL,
  batch_id                        NUMBER(12)     NOT NULL,

  -- Head-to-head y tiebreaks (3 años, global y por superficie)
  win_h2h_qty_3y                  NUMBER,
  los_h2h_qty_3y                  NUMBER,
  win_win_qty_3y                  NUMBER,
  win_los_qty_3y                  NUMBER,
  los_win_qty_3y                  NUMBER,
  los_los_qty_3y                  NUMBER,
  win_avg_tiebreaks_pml_3y        NUMBER,
  los_avg_tiebreaks_pml_3y        NUMBER,

  win_h2h_qty_3y_surface          NUMBER,
  los_h2h_qty_3y_surface          NUMBER,
  win_win_qty_3y_surface          NUMBER,
  win_los_qty_3y_surface          NUMBER,
  los_win_qty_3y_surface          NUMBER,
  los_los_qty_3y_surface          NUMBER,
  win_avg_tiebreaks_pml_3y_sur    NUMBER,
  los_avg_tiebreaks_pml_3y_sur    NUMBER,

  -- Métricas PML 3 años (ganador)
  win_ace_pml_3y                  NUMBER,
  win_df_pml_3y                   NUMBER,
  win_1st_pml_3y                  NUMBER,
  win_1st_won_pml_3y              NUMBER,
  win_2nd_won_pml_3y              NUMBER,
  win_bp_saved_pml_3y             NUMBER,
  win_srv_won_pml_3y              NUMBER,
  win_1st_return_won_pml_3y       NUMBER,
  win_2nd_return_won_pml_3y       NUMBER,
  win_bp_won_pml_3y               NUMBER,
  win_return_won_pml_3y           NUMBER,
  win_total_won_pml_3y            NUMBER,

  -- Métricas PML 3 años por superficie (ganador)
  win_ace_pml_3y_surface          NUMBER,
  win_df_pml_3y_surface           NUMBER,
  win_1st_pml_3y_surface          NUMBER,
  win_1st_won_pml_3y_surface      NUMBER,
  win_2nd_won_pml_3y_surface      NUMBER,
  win_bp_saved_pml_3y_surface     NUMBER,
  win_srv_won_pml_3y_surface      NUMBER,
  win_1st_return_won_pml_3y_sur   NUMBER,
  win_2nd_return_won_pml_3y_sur   NUMBER,
  win_bp_won_pml_3y_surface       NUMBER,
  win_return_won_pml_3y_surface   NUMBER,
  win_total_won_pml_3y_surface    NUMBER,

  -- Métricas PML 3 años (perdedor)
  los_ace_pml_3y                  NUMBER,
  los_df_pml_3y                   NUMBER,
  los_1st_pml_3y                  NUMBER,
  los_1st_won_pml_3y              NUMBER,
  los_2nd_won_pml_3y              NUMBER,
  los_bp_saved_pml_3y             NUMBER,
  los_srv_won_pml_3y              NUMBER,
  los_1st_return_won_pml_3y       NUMBER,
  los_2nd_return_won_pml_3y       NUMBER,
  los_bp_won_pml_3y               NUMBER,
  los_return_won_pml_3y           NUMBER,
  los_total_won_pml_3y            NUMBER,

  -- Métricas PML 3 años por superficie (perdedor)
  los_ace_pml_3y_surface          NUMBER,
  los_df_pml_3y_surface           NUMBER,
  los_1st_pml_3y_surface          NUMBER,
  los_1st_won_pml_3y_surface      NUMBER,
  los_2nd_won_pml_3y_surface      NUMBER,
  los_bp_saved_pml_3y_surface     NUMBER,
  los_srv_won_pml_3y_surface      NUMBER,
  los_1st_return_won_pml_3y_sur   NUMBER,
  los_2nd_return_won_pml_3y_sur   NUMBER,
  los_bp_won_pml_3y_surface       NUMBER,
  los_return_won_pml_3y_surface   NUMBER,
  los_total_won_pml_3y_surface    NUMBER,

  -- Puntos (rating acumulado)
  winner_3y_points                NUMBER,
  winner_1y_points                NUMBER,
  loser_3y_points                 NUMBER,
  loser_1y_points                 NUMBER,
  winner_3y_points_surface        NUMBER,
  winner_1y_points_surface        NUMBER,
  loser_3y_points_surface         NUMBER,
  loser_1y_points_surface         NUMBER
);

-- Claves y relaciones
ALTER TABLE atp_matches_enriched
  ADD CONSTRAINT pk_atp_matches_enriched
  PRIMARY KEY (id);

ALTER TABLE atp_matches_enriched
  ADD CONSTRAINT fk_atp_matches_enriched$id
  FOREIGN KEY (id)
  REFERENCES atp_matches (id);

-- Índices útiles (opcionales, según consultas)
-- CREATE INDEX ix_atp_me_winner_points ON atp_matches_enriched (winner_3y_points, winner_1y_points);
-- CREATE INDEX ix_atp_me_loser_points  ON atp_matches_enriched (loser_3y_points,  loser_1y_points);
