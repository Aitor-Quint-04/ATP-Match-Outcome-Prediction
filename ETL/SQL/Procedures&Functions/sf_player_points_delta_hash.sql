create or replace function sf_player_points_delta_hash(
  pv_tournament_id player_points.tournament_id%type,
  pv_player_code   player_points.player_code%type,
  pn_points        player_points.points%type
)
  return player_points.delta_hash%type
is
  vn_delta_hash player_points.delta_hash%type;
begin
  select ora_hash(pv_tournament_id || '|' || pv_player_code || '|' || pn_points)
  into vn_delta_hash
  from dual;
  return (vn_delta_hash);
end sf_player_points_delta_hash;
/
