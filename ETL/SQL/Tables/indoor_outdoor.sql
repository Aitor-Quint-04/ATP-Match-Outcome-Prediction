CREATE TABLE indoor_outdoor (
  indoor_outdoor  VARCHAR2(8) NOT NULL
);

ALTER TABLE indoor_outdoor
  ADD CONSTRAINT pk_indoor_outdoor
  PRIMARY KEY (indoor_outdoor);
