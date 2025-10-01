CREATE TABLE points_rules (
  id                  VARCHAR2(16)  NOT NULL,
  name                VARCHAR2(32)  NOT NULL,
  series_category_id  VARCHAR2(16)  NOT NULL,
  first_stadie_id     VARCHAR2(4)
);

-- Clave primaria
ALTER TABLE points_rules
  ADD CONSTRAINT pk_points_rules
  PRIMARY KEY (id);

-- Foráneas
ALTER TABLE points_rules
  ADD CONSTRAINT fk_pr$series_category
  FOREIGN KEY (series_category_id)
  REFERENCES series_category (id);

ALTER TABLE points_rules
  ADD CONSTRAINT fk_pr$first_stadies
  FOREIGN KEY (first_stadie_id)
  REFERENCES stadies (id);
