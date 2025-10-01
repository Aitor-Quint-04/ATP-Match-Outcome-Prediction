CREATE TABLE match_scores_adjustments (
  match_id  VARCHAR2(64)   NOT NULL,
  set_score VARCHAR2(32),
  stats_url VARCHAR2(256),
  to_skip   VARCHAR2(1)
);

ALTER TABLE match_scores_adjustments
  ADD CONSTRAINT pk_match_scores_adjustments
  PRIMARY KEY (match_id);
