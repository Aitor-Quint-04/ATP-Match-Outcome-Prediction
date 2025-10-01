CREATE TABLE countries (
  code  VARCHAR2(3)  NOT NULL,
  name  VARCHAR2(64) NOT NULL
);

-- Claves y restricciones
ALTER TABLE countries
  ADD CONSTRAINT pk_countries
  PRIMARY KEY (code);

ALTER TABLE countries
  ADD CONSTRAINT unq_countries
  UNIQUE (name);
