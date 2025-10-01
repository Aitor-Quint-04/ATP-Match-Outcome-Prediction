CREATE TABLE stadies (
  id    VARCHAR2(4)  NOT NULL,
  name  VARCHAR2(64) NOT NULL,
  ord   NUMBER(2)    NOT NULL,
  draw  VARCHAR2(1)  NOT NULL
);

-- Claves y restricciones
ALTER TABLE stadies
  ADD CONSTRAINT pk_stadies
  PRIMARY KEY (id);

ALTER TABLE stadies
  ADD CONSTRAINT unq_stadies
  UNIQUE (name);

ALTER TABLE stadies
  ADD CONSTRAINT chk_stadies$draw
  CHECK (draw IN ('Q','M'));
