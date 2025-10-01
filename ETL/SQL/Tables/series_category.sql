CREATE TABLE series_category (
  id         VARCHAR2(16) NOT NULL,
  name       VARCHAR2(64) NOT NULL,
  series_id  VARCHAR2(8)  NOT NULL
);

-- Claves y restricciones
ALTER TABLE series_category
  ADD CONSTRAINT pk_series_category
  PRIMARY KEY (id);

ALTER TABLE series_category
  ADD CONSTRAINT fk_series_category$series
  FOREIGN KEY (series_id)
  REFERENCES series (id);

ALTER TABLE series_category
  ADD CONSTRAINT unq_series_category
  UNIQUE (name);
