CREATE TABLE surfaces (
  surface  VARCHAR2(8) NOT NULL
);

ALTER TABLE surfaces
  ADD CONSTRAINT pk_surfaces
  PRIMARY KEY (surface);
