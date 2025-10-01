CREATE TABLE points_rulebook (
  points_rule_id  VARCHAR2(16)  NOT NULL,
  stadie_id       VARCHAR2(4)   NOT NULL,
  result          VARCHAR2(1)   NOT NULL,
  points          NUMBER(4)     NOT NULL
);

-- Clave primaria compuesta
ALTER TABLE points_rulebook
  ADD CONSTRAINT pk_points_rulebook
  PRIMARY KEY (points_rule_id, stadie_id, result);

-- Foráneas
ALTER TABLE points_rulebook
  ADD CONSTRAINT fk_prb$points_rule
  FOREIGN KEY (points_rule_id)
  REFERENCES points_rules (id);

ALTER TABLE points_rulebook
  ADD CONSTRAINT fk_prb$stadies
  FOREIGN KEY (stadie_id)
  REFERENCES stadies (id);

-- Check constraint
ALTER TABLE points_rulebook
  ADD CONSTRAINT chk_pr$result
  CHECK (result IN ('W','L'));
