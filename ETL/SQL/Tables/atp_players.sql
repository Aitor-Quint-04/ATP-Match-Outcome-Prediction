CREATE TABLE atp_players (
  code         VARCHAR2(4)    NOT NULL,
  delta_hash   NUMBER         NOT NULL,
  batch_id     NUMBER(12)     NOT NULL,
  url          VARCHAR2(128),
  first_name   VARCHAR2(128),
  last_name    VARCHAR2(128),
  slug         VARCHAR2(128),
  birth_date   DATE,
  birthplace   VARCHAR2(128),
  turned_pro   NUMBER(4),
  weight       NUMBER(4),
  height       NUMBER(4),
  residence    VARCHAR2(128),
  handedness   VARCHAR2(128),
  backhand     VARCHAR2(128),
  citizenship  VARCHAR2(3)
);

-- Claves y restricciones
ALTER TABLE atp_players
  ADD CONSTRAINT pk_atp_players
  PRIMARY KEY (code);

ALTER TABLE atp_players
  ADD CONSTRAINT unq_atp_players$url
  UNIQUE (url);

ALTER TABLE atp_players
  ADD CONSTRAINT unq_atp_players$main
  UNIQUE (first_name, last_name, birth_date);

ALTER TABLE atp_players
  ADD CONSTRAINT fk_atp_players$citizenship
  FOREIGN KEY (citizenship)
  REFERENCES countries (code);

-- Comentarios de columnas
COMMENT ON COLUMN atp_players.weight IS 'kg';
COMMENT ON COLUMN atp_players.height IS 'sm';
