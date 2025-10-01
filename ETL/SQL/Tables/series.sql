CREATE TABLE series (
  id    VARCHAR2(8)  NOT NULL,
  name  VARCHAR2(64) NOT NULL
);

-- Claves y restricciones
ALTER TABLE series
  ADD CONSTRAINT pk_series
  PRIMARY KEY (id);

ALTER TABLE series
  ADD CONSTRAINT unq_series
  UNIQUE (name);
