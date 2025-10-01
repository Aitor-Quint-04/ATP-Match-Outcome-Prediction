create or replace procedure sp_upd_atp_players_delta_hash(
  pn_code atp_players.code%type)
is
begin
  update atp_players p
    set
      delta_hash = sf_atp_players_delta_hash(
             pv_code =>        pn_code,
             pv_url =>         p.url,
             pv_first_name =>  p.first_name,
             pv_last_name =>   p.last_name,
             pv_slug =>        p.slug,
             pd_birth_date =>  p.birth_date,
             pv_birthplace =>  p.birthplace,
             pn_turned_pro =>  p.turned_pro,
             pn_weight =>      p.weight,
             pn_height =>      p.height,
             pv_residence =>   p.residence,
             pv_handedness =>  p.handedness,
             pv_backhand =>    p.backhand,
             pv_citizenship => p.citizenship)
  where p.code = pn_code;
end sp_upd_atp_players_delta_hash;
/
