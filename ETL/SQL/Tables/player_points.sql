CREATE TABLE player_points (
  tournament_id  VARCHAR2(64)  NOT NULL,
  delta_hash     NUMBER        NOT NULL,
  batch_id       NUMBER(12)    NOT NULL,
  player_code    VARCHAR2(12)  NOT NULL,
  points         NUMBER(4)     NOT NULL
);

-- Clave primaria compuesta
ALTER TABLE player_points
  ADD CONSTRAINT pk_player_points
  PRIMARY KEY (tournament_id, player_code);

-- Foráneas
ALTER TABLE player_points
  ADD CONSTRAINT fk_player_points$player_code
  FOREIGN KEY (player_code)
  REFERENCES atp_players (code);

ALTER TABLE player_points
  ADD CONSTRAINT fk_player_points$tournament_id
  FOREIGN KEY (tournament_id)
  REFERENCES atp_tournaments (id);
