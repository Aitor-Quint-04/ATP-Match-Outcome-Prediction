create or replace function sf_atp_players_delta_hash(
  pv_code        atp_players.code%type,
  pv_url         atp_players.url%type,
  pv_first_name  atp_players.first_name%type  default null,
  pv_last_name   atp_players.last_name%type   default null,
  pv_slug        atp_players.slug%type        default null,
  pd_birth_date  atp_players.birth_date%type  default null,
  pv_birthplace  atp_players.birthplace%type  default null,
  pn_turned_pro  atp_players.turned_pro%type  default null,
  pn_weight      atp_players.weight%type      default null,
  pn_height      atp_players.height%type      default null,
  pv_residence   atp_players.residence%type   default null,
  pv_handedness  atp_players.handedness%type  default null,
  pv_backhand    atp_players.backhand%type    default null,
  pv_citizenship atp_players.citizenship%type default null
)
  return atp_players.delta_hash%type
is
  vn_delta_hash atp_players.delta_hash%type;
begin
  select ora_hash(pv_code || '|' || pv_url || '|' || pv_first_name || '|' || pv_last_name || '|' || pv_slug || '|' || to_char(pd_birth_date, 'yyyymmdd') || '|' || pv_birthplace || '|' || pn_turned_pro || '|' || pn_weight || '|' || pn_height || '|' || pv_residence || '|' || pv_handedness || '|' || pv_backhand || '|' || pv_citizenship)
  into vn_delta_hash
  from dual;
  return (vn_delta_hash);
end sf_atp_players_delta_hash;
/
