create or replace procedure sp_process_atp_matches
is
  cv_module_name constant varchar2(200) := 'process atp matches';
  vn_qty         number;
  vn_batch_id    logger.batches.id%type;
begin
  pkg_log.sp_start_batch(pv_module => cv_module_name, pv_server => pkg_log.sf_get_server_name, pn_batch_id => vn_batch_id);
  --
  -- adding new players
  -- winners
  insert into atp_players(url, code, delta_hash, batch_id)
  select url, code,
         sf_atp_players_delta_hash(
           pv_code => code,
           pv_url =>  url) as delta_hash,
         vn_batch_id
  from (select distinct s.winner_url as url, s.winner_code as code
        from stg_matches s
        where s.winner_code not in (select p.code from atp_players p));
  --
  vn_qty := sql%rowcount;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'add new players (winners)', pn_qty => vn_qty);
  -- losers
  insert into atp_players(url, code, delta_hash, batch_id)
  select url, code,
         sf_atp_players_delta_hash(
           pv_code => code,
           pv_url =>  url) as delta_hash,
         vn_batch_id
  from (select distinct s.loser_url as url, s.loser_code as code
        from stg_matches s
        where s.loser_code not in (select p.code from atp_players p));
  --
  vn_qty := sql%rowcount;
  pkg_log.sp_log_message(pn_batch_id => vn_batch_id, pv_text => 'add new players (losers)', pn_qty => vn_qty);
  --
  merge into atp_matches d
  using(select i.id,
               i.tournament_id,
               nvl(i.stats_url, m.stats_url) as stats_url,
               i.stadie_id,
               i.match_order,
               i.winner_code,
               i.loser_code,
               i.winner_seed,
               i.loser_seed,
               case
                 when nvl(length(i.score), 0) > nvl(length(m.score), 0) then i.score
                 else m.score
               end as score,
               i.winner_sets_won,
               i.loser_sets_won,
               i.winner_games_won,
               i.loser_games_won,
               i.winner_tiebreaks_won,
               i.loser_tiebreaks_won,
               i.match_ret,
               nvl(i.match_duration, m.match_duration) as match_duration,
               sf_atp_matches_delta_hash(
                 pv_id                         => i.id,
                 pv_tournament_id              => i.tournament_id,
                 pv_stadie_id                  => i.stadie_id,
                 pn_match_order                => i.match_order,
                 pv_match_ret                  => i.match_ret,
                 pv_winner_code                => i.winner_code,
                 pv_loser_code                 => i.loser_code,
                 pv_winner_seed                => i.winner_seed,
                 pv_loser_seed                 => i.loser_seed,
                 pv_score                      => case
                                                    when nvl(length(i.score), 0) > nvl(length(m.score), 0) then i.score
                                                    else m.score
                                                  end,
                 pn_winner_sets_won            => i.winner_sets_won,
                 pn_loser_sets_won             => i.loser_sets_won,
                 pn_winner_games_won           => i.winner_games_won,
                 pn_loser_games_won            => i.loser_games_won,
                 pn_winner_tiebreaks_won       => i.winner_tiebreaks_won,
                 pn_loser_tiebreaks_won        => i.loser_tiebreaks_won,
                 pv_stats_url                  => nvl(i.stats_url, m.stats_url),
                 pn_match_duration             => nvl(i.match_duration, m.match_duration),
                 pn_win_aces                   => m.win_aces,
                 pn_win_double_faults          => m.win_double_faults,
                 pn_win_first_serves_in        => m.win_first_serves_in,
                 pn_win_first_serves_total     => m.win_first_serves_total,
                 pn_win_first_serve_points_won => m.win_first_serve_points_won,
                 pn_win_first_serve_points_tot => m.win_first_serve_points_total,
                 pn_win_second_serve_points_wo => m.win_second_serve_points_won,
                 pn_win_second_serve_points_to => m.win_second_serve_points_total,
                 pn_win_break_points_saved     => m.win_break_points_saved,
                 pn_win_break_points_serve_tot => m.win_break_points_serve_total,
                 pn_win_service_points_won     => m.win_service_points_won,
                 pn_win_service_points_total   => m.win_service_points_total,
                 pn_win_first_serve_return_won => m.win_first_serve_return_won,
                 pn_win_first_serve_return_tot => m.win_first_serve_return_total,
                 pn_win_second_serve_return_wo => m.win_second_serve_return_won,
                 pn_win_second_serve_return_to => m.win_second_serve_return_total,
                 pn_win_break_points_converted => m.win_break_points_converted,
                 pn_win_break_points_return_to => m.win_break_points_return_total,
                 pn_win_service_games_played   => m.win_service_games_played,
                 pn_win_return_games_played    => m.win_return_games_played,
                 pn_win_return_points_won      => m.win_return_points_won,
                 pn_win_return_points_total    => m.win_return_points_total,
                 pn_win_total_points_won       => m.win_total_points_won,
                 pn_win_total_points_total     => m.win_total_points_total,
                 pn_win_winners                => m.win_winners,
                 pn_win_forced_errors          => m.win_forced_errors,
                 pn_win_unforced_errors        => m.win_unforced_errors,
                 pn_win_net_points_won         => m.win_net_points_won,
                 pn_win_net_points_total       => m.win_net_points_total,
                 pn_win_fastest_first_serves_k => m.win_fastest_first_serves_kmh,
                 pn_win_average_first_serves_k => m.win_average_first_serves_kmh,
                 pn_win_fastest_second_serve_k => m.win_fastest_second_serve_kmh,
                 pn_win_average_second_serve_k => m.win_average_second_serve_kmh,
                 pn_los_aces                   => m.los_aces,
                 pn_los_double_faults          => m.los_double_faults,
                 pn_los_first_serves_in        => m.los_first_serves_in,
                 pn_los_first_serves_total     => m.los_first_serves_total,
                 pn_los_first_serve_points_won => m.los_first_serve_points_won,
                 pn_los_first_serve_points_tot => m.los_first_serve_points_total,
                 pn_los_second_serve_points_wo => m.los_second_serve_points_won,
                 pn_los_second_serve_points_to => m.los_second_serve_points_total,
                 pn_los_break_points_saved     => m.los_break_points_saved,
                 pn_los_break_points_serve_tot => m.los_break_points_serve_total,
                 pn_los_service_points_won     => m.los_service_points_won,
                 pn_los_service_points_total   => m.los_service_points_total,
                 pn_los_first_serve_return_won => m.los_first_serve_return_won,
                 pn_los_first_serve_return_tot => m.los_first_serve_return_total,
                 pn_los_second_serve_return_wo => m.los_second_serve_return_won,
                 pn_los_second_serve_return_to => m.los_second_serve_return_total,
                 pn_los_break_points_converted => m.los_break_points_converted,
                 pn_los_break_points_return_to => m.los_break_points_return_total,
                 pn_los_service_games_played   => m.los_service_games_played,
                 pn_los_return_games_played    => m.los_return_games_played,
                 pn_los_return_points_won      => m.los_return_points_won,
                 pn_los_return_points_total    => m.los_return_points_total,
                 pn_los_total_points_won       => m.los_total_points_won,
                 pn_los_total_points_total     => m.los_total_points_total,
                 pn_los_winners                => m.los_winners,
                 pn_los_forced_errors          => m.los_forced_errors,
                 pn_los_unforced_errors        => m.los_unforced_errors,
                 pn_los_net_points_won         => m.los_net_points_won,
                 pn_los_net_points_total       => m.los_net_points_total,
                 pn_los_fastest_first_serves_k => m.los_fastest_first_serves_kmh,
                 pn_los_average_first_serves_k => m.los_average_first_serves_kmh,
                 pn_los_fastest_second_serve_k => m.los_fastest_second_serve_kmh,
                 pn_los_average_second_serve_k => m.los_average_second_serve_kmh) as delta_hash
        from (select sm.id,
                     sm.tournament_id,
                     case
                       when sm.match_ret is null then sm.stats_url
                       else null
                     end as stats_url,
                     sm.stadie_id,
                     sm.match_order,
                     sm.winner_code,
                     sm.loser_code,
                     sm.winner_seed,
                     sm.loser_seed,
                     sm.score,
                     sm.winner_sets_won,
                     sm.loser_sets_won,
                     sm.winner_games_won,
                     sm.loser_games_won,
                     sm.winner_tiebreaks_won,
                     sm.loser_tiebreaks_won,
                     sm.match_ret,
                     sm.match_duration,
                     row_number() over (partition by sm.id order by sm.match_order) rn
              from stg_matches sm) i,
             atp_matches m
        where m.id(+) = i.id
          and i.rn = 1) s
  on (s.id = d.id)
  when not matched then
    insert (d.id, d.delta_hash, d.batch_id,  d.tournament_id, d.stadie_id, d.match_order, d.match_ret, d.winner_code, d.loser_code, d.winner_seed, d.loser_seed, d.score, d.winner_sets_won, d.loser_sets_won, d.winner_games_won, d.loser_games_won, d.winner_tiebreaks_won, d.loser_tiebreaks_won, d.stats_url, d.match_duration)
    values (s.id, s.delta_hash, vn_batch_id, s.tournament_id, s.stadie_id, s.match_order, s.match_ret, s.winner_code, s.loser_code, s.winner_seed, s.loser_seed, s.score, s.winner_sets_won, s.loser_sets_won, s.winner_games_won, s.loser_games_won, s.winner_tiebreaks_won, s.loser_tiebreaks_won, s.stats_url, s.match_duration)
  when matched then
    update set
      d.delta_hash           = s.delta_hash,
      d.batch_id             = vn_batch_id,
      d.tournament_id        = s.tournament_id,
      d.stadie_id            = s.stadie_id,
      d.match_order          = s.match_order,
      d.match_ret            = s.match_ret,
      d.winner_code          = s.winner_code,
      d.loser_code           = s.loser_code,
      d.winner_seed          = s.winner_seed,
      d.loser_seed           = s.loser_seed,
      d.score          = s.score,
      d.winner_sets_won      = s.winner_sets_won,
      d.loser_sets_won       = s.loser_sets_won,
      d.winner_games_won     = s.winner_games_won,
      d.loser_games_won      = s.loser_games_won,
      d.winner_tiebreaks_won = s.winner_tiebreaks_won,
      d.loser_tiebreaks_won  = s.loser_tiebreaks_won,
      d.match_duration       = s.match_duration,
      d.stats_url            = nvl(s.stats_url, d.stats_url)
    where d.delta_hash != s.delta_hash;
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
end sp_process_atp_matches;
/
