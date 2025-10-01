create or replace function sf_atp_matches_delta_hash(
  pv_id                         atp_matches.id%type,
  pv_tournament_id              atp_matches.tournament_id%type,
  pv_stadie_id                  atp_matches.stadie_id%type,
  pn_match_order                atp_matches.match_order%type,
  pv_match_ret                  atp_matches.match_ret%type,
  pv_winner_code                atp_matches.winner_code%type,
  pv_loser_code                 atp_matches.loser_code%type,
  pv_winner_seed                atp_matches.winner_seed%type,
  pv_loser_seed                 atp_matches.loser_seed%type,
  pv_score                      atp_matches.score%type,
  pn_winner_sets_won            atp_matches.winner_sets_won%type,
  pn_loser_sets_won             atp_matches.loser_sets_won%type,
  pn_winner_games_won           atp_matches.winner_games_won%type,
  pn_loser_games_won            atp_matches.loser_games_won%type,
  pn_winner_tiebreaks_won       atp_matches.winner_tiebreaks_won%type,
  pn_loser_tiebreaks_won        atp_matches.loser_tiebreaks_won%type,
  pv_stats_url                  atp_matches.stats_url%type,
  pn_match_duration             atp_matches.match_duration%type,
  pn_win_aces                   atp_matches.win_aces%type,
  pn_win_double_faults          atp_matches.win_double_faults%type,
  pn_win_first_serves_in        atp_matches.win_first_serves_in%type,
  pn_win_first_serves_total     atp_matches.win_first_serves_total%type,
  pn_win_first_serve_points_won atp_matches.win_first_serve_points_won%type,
  pn_win_first_serve_points_tot atp_matches.win_first_serve_points_total%type,
  pn_win_second_serve_points_wo atp_matches.win_second_serve_points_won%type,
  pn_win_second_serve_points_to atp_matches.win_second_serve_points_total%type,
  pn_win_break_points_saved     atp_matches.win_break_points_saved%type,
  pn_win_break_points_serve_tot atp_matches.win_break_points_serve_total%type,
  pn_win_service_points_won     atp_matches.win_service_points_won%type,
  pn_win_service_points_total   atp_matches.win_service_points_total%type,
  pn_win_first_serve_return_won atp_matches.win_first_serve_return_won%type,
  pn_win_first_serve_return_tot atp_matches.win_first_serve_return_total%type,
  pn_win_second_serve_return_wo atp_matches.win_second_serve_return_won%type,
  pn_win_second_serve_return_to atp_matches.win_second_serve_return_total%type,
  pn_win_break_points_converted atp_matches.win_break_points_converted%type,
  pn_win_break_points_return_to atp_matches.win_break_points_return_total%type,
  pn_win_service_games_played   atp_matches.win_service_games_played%type,
  pn_win_return_games_played    atp_matches.win_return_games_played%type,
  pn_win_return_points_won      atp_matches.win_return_points_won%type,
  pn_win_return_points_total    atp_matches.win_return_points_total%type,
  pn_win_total_points_won       atp_matches.win_total_points_won%type,
  pn_win_total_points_total     atp_matches.win_total_points_total%type,
  pn_win_winners                atp_matches.win_winners%type,
  pn_win_forced_errors          atp_matches.win_forced_errors%type,
  pn_win_unforced_errors        atp_matches.win_unforced_errors%type,
  pn_win_net_points_won         atp_matches.win_net_points_won%type,
  pn_win_net_points_total       atp_matches.win_net_points_total%type,
  pn_win_fastest_first_serves_k atp_matches.win_fastest_first_serves_kmh%type,
  pn_win_average_first_serves_k atp_matches.win_average_first_serves_kmh%type,
  pn_win_fastest_second_serve_k atp_matches.win_fastest_second_serve_kmh%type,
  pn_win_average_second_serve_k atp_matches.win_average_second_serve_kmh%type,
  pn_los_aces                   atp_matches.los_aces%type,
  pn_los_double_faults          atp_matches.los_double_faults%type,
  pn_los_first_serves_in        atp_matches.los_first_serves_in%type,
  pn_los_first_serves_total     atp_matches.los_first_serves_total%type,
  pn_los_first_serve_points_won atp_matches.los_first_serve_points_won%type,
  pn_los_first_serve_points_tot atp_matches.los_first_serve_points_total%type,
  pn_los_second_serve_points_wo atp_matches.los_second_serve_points_won%type,
  pn_los_second_serve_points_to atp_matches.los_second_serve_points_total%type,
  pn_los_break_points_saved     atp_matches.los_break_points_saved%type,
  pn_los_break_points_serve_tot atp_matches.los_break_points_serve_total%type,
  pn_los_service_points_won     atp_matches.los_service_points_won%type,
  pn_los_service_points_total   atp_matches.los_service_points_total%type,
  pn_los_first_serve_return_won atp_matches.los_first_serve_return_won%type,
  pn_los_first_serve_return_tot atp_matches.los_first_serve_return_total%type,
  pn_los_second_serve_return_wo atp_matches.los_second_serve_return_won%type,
  pn_los_second_serve_return_to atp_matches.los_second_serve_return_total%type,
  pn_los_break_points_converted atp_matches.los_break_points_converted%type,
  pn_los_break_points_return_to atp_matches.los_break_points_return_total%type,
  pn_los_service_games_played   atp_matches.los_service_games_played%type,
  pn_los_return_games_played    atp_matches.los_return_games_played%type,
  pn_los_return_points_won      atp_matches.los_return_points_won%type,
  pn_los_return_points_total    atp_matches.los_return_points_total%type,
  pn_los_total_points_won       atp_matches.los_total_points_won%type,
  pn_los_total_points_total     atp_matches.los_total_points_total%type,
  pn_los_winners                atp_matches.los_winners%type,
  pn_los_forced_errors          atp_matches.los_forced_errors%type,
  pn_los_unforced_errors        atp_matches.los_unforced_errors%type,
  pn_los_net_points_won         atp_matches.los_net_points_won%type,
  pn_los_net_points_total       atp_matches.los_net_points_total%type,
  pn_los_fastest_first_serves_k atp_matches.los_fastest_first_serves_kmh%type,
  pn_los_average_first_serves_k atp_matches.los_average_first_serves_kmh%type,
  pn_los_fastest_second_serve_k atp_matches.los_fastest_second_serve_kmh%type,
  pn_los_average_second_serve_k atp_matches.los_average_second_serve_kmh%type
)
  return atp_matches.delta_hash%type
is
  vn_delta_hash atp_matches.delta_hash%type;
begin
  select ora_hash(pv_id || '|' || pv_tournament_id || '|' || pv_stadie_id || '|' || pn_match_order || '|' || pv_match_ret || '|' || pv_winner_code || '|' || pv_loser_code || '|' ||
                  pv_winner_seed || '|' || pv_loser_seed || '|' || pv_score || '|' || pn_winner_sets_won || '|' || pn_loser_sets_won || '|' || pn_winner_games_won || '|' ||
                  pn_loser_games_won || '|' || pn_winner_tiebreaks_won || '|' || pn_loser_tiebreaks_won || '|' || pv_stats_url || '|' || pn_match_duration || '|' || pn_win_aces || '|' ||
                  pn_win_double_faults || '|' || pn_win_first_serves_in || '|' || pn_win_first_serves_total || '|' || pn_win_first_serve_points_won || '|' || pn_win_first_serve_points_tot || '|' ||
                  pn_win_second_serve_points_wo || '|' || pn_win_second_serve_points_to || '|' || pn_win_break_points_saved || '|' || pn_win_break_points_serve_tot || '|' ||
                  pn_win_service_points_won || '|' || pn_win_service_points_total || '|' || pn_win_first_serve_return_won || '|' || pn_win_first_serve_return_tot || '|' || pn_win_second_serve_return_wo || '|' ||
                  pn_win_second_serve_return_to || '|' || pn_win_break_points_converted || '|' || pn_win_break_points_return_to || '|' || pn_win_service_games_played || '|' || pn_win_return_games_played || '|' ||
                  pn_win_return_points_won || '|' || pn_win_return_points_total || '|' || pn_win_total_points_won || '|' || pn_win_total_points_total || '|' || pn_win_winners || '|' ||
                  pn_win_forced_errors || '|' || pn_win_unforced_errors || '|' || pn_win_net_points_won || '|' || pn_win_net_points_total || '|' || pn_win_fastest_first_serves_k || '|' ||
                  pn_win_average_first_serves_k || '|' || pn_win_fastest_second_serve_k || '|' || pn_win_average_second_serve_k || '|' || pn_los_aces || '|' || pn_los_double_faults || '|' || pn_los_first_serves_in || '|' ||
                  pn_los_first_serves_total || '|' || pn_los_first_serve_points_won || '|' || pn_los_first_serve_points_tot || '|' || pn_los_second_serve_points_wo || '|' || pn_los_second_serve_points_to || '|' ||
                  pn_los_break_points_saved || '|' || pn_los_break_points_serve_tot || '|' || pn_los_service_points_won || '|' || pn_los_service_points_total || '|' || pn_los_first_serve_return_won || '|' ||
                  pn_los_first_serve_return_tot || '|' || pn_los_second_serve_return_wo || '|' || pn_los_second_serve_return_to || '|' || pn_los_break_points_converted || '|' || pn_los_break_points_return_to || '|' ||
                  pn_los_service_games_played || '|' || pn_los_return_games_played || '|' || pn_los_return_points_won || '|' || pn_los_return_points_total || '|' || pn_los_total_points_won || '|' ||
                  pn_los_total_points_total || '|' || pn_los_winners || '|' || pn_los_forced_errors || '|' || pn_los_unforced_errors || '|' || pn_los_net_points_won || '|' || pn_los_net_points_total || '|' ||
                  pn_los_fastest_first_serves_k || '|' || pn_los_average_first_serves_k || '|' || pn_los_fastest_second_serve_k || '|' || pn_los_average_second_serve_k)
  into vn_delta_hash
  from dual;
  return (vn_delta_hash);
end sf_atp_matches_delta_hash;
/
