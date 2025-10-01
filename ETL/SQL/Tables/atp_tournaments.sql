CREATE TABLE atp_tournaments (
  id                  VARCHAR2(64)   NOT NULL,
  delta_hash          NUMBER         NOT NULL,
  batch_id            NUMBER(12),
  name                VARCHAR2(128)  NOT NULL,
  year                NUMBER(4)      NOT NULL,
  code                VARCHAR2(48)   NOT NULL,
  url                 VARCHAR2(256)  NOT NULL,
  slug                VARCHAR2(128),
  location            VARCHAR2(128)  NOT NULL,
  sgl_draw_url        VARCHAR2(256),
  sgl_pdf_url         VARCHAR2(256),
  indoor_outdoor      VARCHAR2(8)    NOT NULL,
  surface             VARCHAR2(8)    NOT NULL,
  series_category_id  VARCHAR2(8)    NOT NULL,
  start_dtm           DATE,
  finish_dtm          DATE,
  sgl_draw_qty        NUMBER(4),
  dbl_draw_qty        NUMBER(4),
  prize_money         NUMBER(10),
  prize_currency      VARCHAR2(16),
  country_code        VARCHAR2(3)    NOT NULL,
  points_rule_id      VARCHAR2(16),
  draw_template_id    VARCHAR2(16)
);

-- Claves y restricciones
ALTER TABLE atp_tournaments
  ADD CONSTRAINT pk_atp_tournaments
  PRIMARY KEY (id);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT unq_atp_tourn$code$year
  UNIQUE (code, year);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$series_category
  FOREIGN KEY (series_category_id)
  REFERENCES series_category (id);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$country_code
  FOREIGN KEY (country_code)
  REFERENCES countries (code);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$indoor_outdoor
  FOREIGN KEY (indoor_outdoor)
  REFERENCES indoor_outdoor (indoor_outdoor);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$surface
  FOREIGN KEY (surface)
  REFERENCES surfaces (surface);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$points_rule
  FOREIGN KEY (points_rule_id)
  REFERENCES points_rules (id);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT fk_atp_tourn$draw_template_id
  FOREIGN KEY (draw_template_id)
  REFERENCES draw_templates (id);

ALTER TABLE atp_tournaments
  ADD CONSTRAINT chk_atp_tourn$series_cat_id
  CHECK (series_category_id IN ('laverCup','atpFinal','atpCup','nextGen','chFinal','gs','1000','atp250','atp500','og','fu15','fu25','ch100','ch50','teamCup','gsCup'));
