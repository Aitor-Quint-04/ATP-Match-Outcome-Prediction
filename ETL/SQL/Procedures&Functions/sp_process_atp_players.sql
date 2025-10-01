create or replace procedure sp_process_atp_players
is
  cv_module_name constant varchar2(200) := 'process atp players';
  vn_qty         number;
  vn_batch_id    logger.batches.id%type;
begin
  pkg_log.sp_start_batch(pv_module => cv_module_name, pv_server => pkg_log.sf_get_server_name, pn_batch_id => vn_batch_id);
  --
  merge into atp_players d
  using(select first_name, last_name, player_url as url, player_slug as slug, player_code as code, to_date(birthdate, 'yyyy.mm.dd') as birth_date, birthplace,
               turned_pro, weight_kg as weight, height_cm as height, residence, handedness, backhand, flag_code as citizenship, null as code_dc, null as url_dc,
               sf_atp_players_delta_hash(
                 pv_code =>        player_code,
                 pv_url =>         player_url,
                 pv_first_name =>  first_name,
                 pv_last_name =>   last_name,
                 pv_slug =>        player_slug,
                 pd_birth_date =>  to_date(birthdate, 'yyyy.mm.dd'),
                 pv_birthplace =>  birthplace,
                 pn_turned_pro =>  turned_pro,
                 pn_weight =>      weight_kg,
                 pn_height =>      height_cm,
                 pv_residence =>   residence,
                 pv_handedness =>  handedness,
                 pv_backhand =>    backhand,
                 pv_citizenship => flag_code) as delta_hash
        from stg_players sp) s
  on (s.code = d.code)
  when not matched then
    insert (d.code, d.delta_hash, d.batch_id,  d.url, d.first_name, d.last_name, d.slug, d.birth_date, d.birthplace, d.turned_pro, d.weight, d.height, d.residence, d.handedness, d.backhand, d.citizenship)
    values (s.code, s.delta_hash, vn_batch_id, s.url, s.first_name, s.last_name, s.slug, s.birth_date, s.birthplace, s.turned_pro, s.weight, s.height, s.residence, s.handedness, s.backhand, s.citizenship)
  when matched then
    update set
      d.delta_hash  = s.delta_hash,
      d.batch_id    = vn_batch_id,
      d.url         = nvl(s.url,         d.url),
      d.first_name  = nvl(s.first_name,  d.first_name),
      d.last_name   = nvl(s.last_name,   d.last_name),
      d.slug        = nvl(s.slug,        d.slug),
      d.birth_date  = nvl(s.birth_date,  d.birth_date),
      d.birthplace  = nvl(s.birthplace,  d.birthplace),
      d.turned_pro  = nvl(s.turned_pro,  d.turned_pro),
      d.weight      = nvl(s.weight,      d.turned_pro),
      d.height      = nvl(s.height,      d.height),
      d.residence   = nvl(s.residence,   d.residence),
      d.handedness  = nvl(s.handedness,  d.handedness),
      d.backhand    = nvl(s.backhand,    d.backhand),
      d.citizenship = nvl(s.citizenship, d.citizenship)
    where d.delta_hash != s.delta_hash;
  --
  vn_qty := sql%rowcount;
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
end sp_process_atp_players;
/
