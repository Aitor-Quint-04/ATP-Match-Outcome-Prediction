CREATE TABLE stg_players (
  player_code   VARCHAR2(10),
  player_slug   VARCHAR2(40),
  first_name    VARCHAR2(40),
  last_name     VARCHAR2(40),
  player_url    VARCHAR2(200),
  flag_code     VARCHAR2(10),
  residence     VARCHAR2(60),
  birthplace    VARCHAR2(60),
  birthdate     VARCHAR2(32),
  turned_pro    NUMBER,
  weight_kg     NUMBER,
  height_cm     NUMBER,
  handedness    VARCHAR2(15),
  backhand      VARCHAR2(20),
  batch_id      NUMBER(12),
  player_dc_id  NUMBER(12)
);
