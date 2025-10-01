create or replace procedure sp_merge_atp_players(pv_player_code_to atp_players.code%type,
                                                 pv_player_code_from atp_players.code%type)
is
  cv_module_name constant varchar2(200) := 'merge atp players';
  vn_qty         number;
  vr_player_from atp_players%rowtype;
  vn_batch_id    logger.batches.id%type;
begin
  pkg_log.sp_start_batch(pv_module => cv_module_name, pv_server => pkg_log.sf_get_server_name, pn_batch_id => vn_batch_id);
  -- merge pv_player_code_from -> pv_player_code_to
  if pv_player_code_to is null then
    raise_application_error(-20003, 'Input paramenter pv_player_code_to is empty');
  end if;
  if pv_player_code_from is null then
    raise_application_error(-20003, 'Input paramenter pv_player_code_from is empty');
  end if;
  -- load
  select *
  into vr_player_from
  from atp_players
  where code = pv_player_code_from;
  --
  -- 1. update PLAYERS
  update atp_players p
    set
      batch_id =    vn_batch_id,
      first_name =  nvl(p.first_name,  vr_player_from.first_name),
      last_name =   nvl(p.last_name,   vr_player_from.last_name),
      birth_date =  nvl(p.birth_date,  vr_player_from.birth_date),
      birthplace =  nvl(p.birthplace,  vr_player_from.birthplace),
      turned_pro =  nvl(p.turned_pro,  vr_player_from.turned_pro),
      weight =      nvl(p.weight,      vr_player_from.weight),
      height =      nvl(p.height,      vr_player_from.height),
      residence =   nvl(p.residence,   vr_player_from.residence),
      handedness =  nvl(p.handedness,  vr_player_from.handedness),
      backhand =    nvl(p.backhand,    vr_player_from.backhand),
      citizenship = nvl(p.citizenship, vr_player_from.citizenship)
  where code = pv_player_code_to;
  --
  sp_upd_atp_players_delta_hash(pv_player_code_to);
  -- 2. update MATCHES
  -- 2.1 winners
  update atp_matches
    set
      id          = replace(id, pv_player_code_from, pv_player_code_to),
      batch_id    = vn_batch_id,
      winner_code = pv_player_code_to
  where winner_code = pv_player_code_from;
  vn_qty := sql%rowcount;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'updated winner matches', pn_qty => vn_qty);
  -- 2.2 loser
  update atp_matches
    set
      id         = replace(id, pv_player_code_from, pv_player_code_to),
      batch_id   = vn_batch_id,
      loser_code = pv_player_code_to
  where loser_code = pv_player_code_from;
  vn_qty := sql%rowcount;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'updated loser matches', pn_qty => vn_qty);
  --
  for rec in (select id from atp_matches where batch_id = vn_batch_id)
  loop
    sp_upd_atp_matches_delta_hash(rec.id);
  end loop;
  -- 3. update ATP_MATCHES_ENRICHED
  update atp_matches_enriched
    set
      id          = replace(id, pv_player_code_from, pv_player_code_to),
      batch_id    = vn_batch_id
  where id in (select i.id
               from atp_matches i
               where i.winner_code = pv_player_code_to or i.loser_code = pv_player_code_to);
  vn_qty := sql%rowcount;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'updated atp_matches_enriched', pn_qty => vn_qty);

  -- 4. player_points
  update player_points pp
     set delta_hash = sf_player_points_delta_hash(pv_tournament_id => pp.tournament_id,
                                                  pv_player_code   => pv_player_code_to,
                                                  pn_points        => pp.points),
         batch_id = vn_batch_id,
         player_code = pv_player_code_to
   where player_code = pv_player_code_from;
  -- 5. dc_players
  update dc_players
    set
      atp_code = pv_player_code_to
  where atp_code = pv_player_code_from;
  -- 6. delete PLAYERS
  delete atp_players
  where code = pv_player_code_from;
  --
  commit;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'rows processed', pn_qty => vn_qty);
  pkg_log.sp_finish_batch_successfully(pn_batch_id => vn_batch_id);
exception
  when others then
    rollback;
    pkg_log.sp_log_message(pv_text => 'errors stack', pv_clob_text => dbms_utility.format_error_stack || pkg_utils.CRLF || dbms_utility.format_error_backtrace, pv_type => 'E', pn_batch_id => vn_batch_id);
    pkg_log.sp_finish_batch_with_errors(pn_batch_id => vn_batch_id);
    raise;
end sp_merge_atp_players;
/
