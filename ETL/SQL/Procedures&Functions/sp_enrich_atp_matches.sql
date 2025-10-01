create or replace procedure sp_enrich_atp_matches(p_match_ids t_list_of_varchar)
is
  cv_module_name constant varchar2(200) := 'enrich atp matches';
  cv_3_years     constant number(4) := 365 * 3;
  cv_52_weeks    constant number(4) := 52 * 7 - 1;
  vn_qty         number;
  vn_batch_id    logger.batches.id%type;
begin
  pkg_log.sp_start_batch(pv_module => cv_module_name, pv_server => pkg_log.sf_get_server_name, pn_batch_id => vn_batch_id);
  --
  merge into atp_matches_enriched d
  using(select i.*,
               sf_atp_matches_enriched_dh(pv_id =>                          i.id,
                                          pn_win_h2h_qty_3y =>              i.win_h2h_qty_3y,
                                          pn_los_h2h_qty_3y =>              i.los_h2h_qty_3y,
                                          pn_win_win_qty_3y =>              i.win_win_qty_3y,
                                          pn_win_los_qty_3y =>              i.win_los_qty_3y,
                                          pn_los_win_qty_3y =>              i.los_win_qty_3y,
                                          pn_los_los_qty_3y =>              i.los_los_qty_3y,
                                          pn_win_avg_tiebreaks_pml_3y =>    i.win_avg_tiebreaks_pml_3y,
                                          pn_los_avg_tiebreaks_pml_3y =>    i.los_avg_tiebreaks_pml_3y,
                                          pn_win_h2h_qty_3y_surface =>      i.win_h2h_qty_3y_surface,
                                          pn_los_h2h_qty_3y_surface =>      i.los_h2h_qty_3y_surface,
                                          pn_win_win_qty_3y_surface =>      i.win_win_qty_3y_surface,
                                          pn_win_los_qty_3y_surface =>      i.win_los_qty_3y_surface,
                                          pn_los_win_qty_3y_surface =>      i.los_win_qty_3y_surface,
                                          pn_los_los_qty_3y_surface =>      i.los_los_qty_3y_surface,
                                          pn_win_avg_tiebreaks_pml_3y_s =>  i.win_avg_tiebreaks_pml_3y_sur,
                                          pn_los_avg_tiebreaks_pml_3y_s =>  i.los_avg_tiebreaks_pml_3y_sur,
                                          pn_win_ace_pml_3y =>              i.win_ace_pml_3y,
                                          pn_win_df_pml_3y =>               i.win_df_pml_3y,
                                          pn_win_1st_pml_3y =>              i.win_1st_pml_3y,
                                          pn_win_1st_won_pml_3y =>          i.win_1st_won_pml_3y,
                                          pn_win_2nd_won_pml_3y =>          i.win_2nd_won_pml_3y,
                                          pn_win_bp_saved_pml_3y =>         i.win_bp_saved_pml_3y,
                                          pn_win_srv_won_pml_3y =>          i.win_srv_won_pml_3y,
                                          pn_win_1st_return_won_pml_3y =>   i.win_1st_return_won_pml_3y,
                                          pn_win_2nd_return_won_pml_3y =>   i.win_2nd_return_won_pml_3y,
                                          pn_win_bp_won_pml_3y =>           i.win_bp_won_pml_3y,
                                          pn_win_return_won_pml_3y =>       i.win_return_won_pml_3y,
                                          pn_win_total_won_pml_3y =>        i.win_total_won_pml_3y,
                                          pn_win_ace_pml_3y_surface =>      i.win_ace_pml_3y_surface,
                                          pn_win_df_pml_3y_surface =>       i.win_df_pml_3y_surface,
                                          pn_win_1st_pml_3y_surface =>      i.win_1st_pml_3y_surface,
                                          pn_win_1st_won_pml_3y_surface =>  i.win_1st_won_pml_3y_surface,
                                          pn_win_2nd_won_pml_3y_surface =>  i.win_2nd_won_pml_3y_surface,
                                          pn_win_bp_saved_pml_3y_surface => i.win_bp_saved_pml_3y_surface,
                                          pn_win_srv_won_pml_3y_surface =>  i.win_srv_won_pml_3y_surface,
                                          pn_win_1st_return_won_pml_3y_s => i.win_1st_return_won_pml_3y_sur,
                                          pn_win_2nd_return_won_pml_3y_s => i.win_2nd_return_won_pml_3y_sur,
                                          pn_win_bp_won_pml_3y_surface =>   i.win_bp_won_pml_3y_surface,
                                          pn_win_return_won_pml_3y_sur =>   i.win_return_won_pml_3y_surface,
                                          pn_win_total_won_pml_3y_sur =>    i.win_total_won_pml_3y_surface,
                                          pn_los_ace_pml_3y =>              i.los_ace_pml_3y,
                                          pn_los_df_pml_3y =>               i.los_df_pml_3y,
                                          pn_los_1st_pml_3y =>              i.los_1st_pml_3y,
                                          pn_los_1st_won_pml_3y =>          i.los_1st_won_pml_3y,
                                          pn_los_2nd_won_pml_3y =>          i.los_2nd_won_pml_3y,
                                          pn_los_bp_saved_pml_3y =>         i.los_bp_saved_pml_3y,
                                          pn_los_srv_won_pml_3y =>          i.los_srv_won_pml_3y,
                                          pn_los_1st_return_won_pml_3y =>   i.los_1st_return_won_pml_3y,
                                          pn_los_2nd_return_won_pml_3y =>   i.los_2nd_return_won_pml_3y,
                                          pn_los_bp_won_pml_3y =>           i.los_bp_won_pml_3y,
                                          pn_los_return_won_pml_3y =>       i.los_return_won_pml_3y,
                                          pn_los_total_won_pml_3y =>        i.los_total_won_pml_3y,
                                          pn_los_ace_pml_3y_surface =>      i.los_ace_pml_3y_surface,
                                          pn_los_df_pml_3y_surface =>       i.los_df_pml_3y_surface,
                                          pn_los_1st_pml_3y_surface =>      i.los_1st_pml_3y_surface,
                                          pn_los_1st_won_pml_3y_surface =>  i.los_1st_won_pml_3y_surface,
                                          pn_los_2nd_won_pml_3y_surface =>  i.los_2nd_won_pml_3y_surface,
                                          pn_los_bp_saved_pml_3y_surface => i.los_bp_saved_pml_3y_surface,
                                          pn_los_srv_won_pml_3y_surface =>  i.los_srv_won_pml_3y_surface,
                                          pn_los_1st_return_won_pml_3y_s => i.los_1st_return_won_pml_3y_sur,
                                          pn_los_2nd_return_won_pml_3y_s => i.los_2nd_return_won_pml_3y_sur,
                                          pn_los_bp_won_pml_3y_surface =>   i.los_bp_won_pml_3y_surface,
                                          pn_los_return_won_pml_3y_sur =>   i.los_return_won_pml_3y_surface,
                                          pn_los_total_won_pml_3y_sur =>    i.los_total_won_pml_3y_surface,
                                          pn_winner_3y_points =>            i.winner_3y_points,
                                          pn_winner_1y_points =>            i.winner_1y_points,
                                          pn_loser_3y_points =>             i.loser_3y_points,
                                          pn_loser_1y_points =>             i.loser_1y_points,
                                          pn_winner_3y_points_surface =>    i.winner_3y_points_surface,
                                          pn_winner_1y_points_surface =>    i.winner_1y_points_surface,
                                          pn_loser_3y_points_surface =>     i.loser_3y_points_surface,
                                          pn_loser_1y_points_surface =>     i.loser_1y_points_surface) as delta_hash
        from ( select vw.id,
                      vn_batch_id as batch_id,
                      -- 3 years
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.winner_code = vw.winner_code
                         and vi.loser_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_h2h_qty_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.winner_code = vw.loser_code
                         and vi.loser_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_h2h_qty_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.winner_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_win_qty_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.loser_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_los_qty_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.winner_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_win_qty_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.loser_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_los_qty_3y,
                      (select 1000 * trunc(avg((psi.player_tiebreaks_won + psi.player_tiebreaks_los) / (psi.player_sets_won + psi.player_sets_los)), 3) as qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_avg_tiebreaks_pml_3y,
                      (select 1000 * trunc(avg((psi.player_tiebreaks_won + psi.player_tiebreaks_los) / (psi.player_sets_won + psi.player_sets_los)), 3) as qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_avg_tiebreaks_pml_3y,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.winner_code = vw.winner_code
                         and vi.loser_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_h2h_qty_3y_surface,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.winner_code = vw.loser_code
                         and vi.loser_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_h2h_qty_3y_surface,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.winner_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_win_qty_3y_surface,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.loser_code = vw.winner_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_los_qty_3y_surface,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.winner_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_win_qty_3y_surface,
                      (select count(*) as qty
                       from vw_matches vi
                       where vi.tournament_surface = vw.tournament_surface
                         and vi.loser_code = vw.loser_code
                         and vi.match_ret is null
                         and vi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and vi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_los_qty_3y_surface,
                      (select 1000 * trunc(avg((psi.player_tiebreaks_won + psi.player_tiebreaks_los) / (psi.player_sets_won + psi.player_sets_los)), 3) as qty
                       from vw_player_stats psi
                       where psi.tournament_surface = vw.tournament_surface
                         and psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as win_avg_tiebreaks_pml_3y_sur,
                      (select 1000 * trunc(avg((psi.player_tiebreaks_won + psi.player_tiebreaks_los) / (psi.player_sets_won + psi.player_sets_los)), 3) as qty
                       from vw_player_stats psi
                       where psi.tournament_surface = vw.tournament_surface
                         and psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) as los_avg_tiebreaks_pml_3y_sur,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(aces) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_ace_pml_3y,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(double_faults) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_df_pml_3y,
                      (select case
                                when nvl(sum(first_serves_total), 0) > 0 then 1000 * trunc(sum(first_serves_in) / sum(first_serves_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_pml_3y,
                      (select case
                                when nvl(sum(first_serves_in), 0) > 0 then 1000 * trunc(sum(first_serve_points_won) / sum(first_serves_in), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_won_pml_3y,
                      (select case
                                when nvl(sum(second_serve_points_total), 0) > 0 then 1000 * trunc(sum(second_serve_points_won) / sum(second_serve_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_2nd_won_pml_3y,
                      (select case
                                when nvl(sum(break_points_serve_total), 0) > 0 then 1000 * trunc(sum(break_points_saved) / sum(break_points_serve_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_bp_saved_pml_3y,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(service_points_won) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_srv_won_pml_3y,
                      (select case
                                when nvl(sum(first_serve_return_total), 0) > 0 then 1000 * trunc(sum(first_serve_return_won) / sum(first_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_return_won_pml_3y,
                      (select case
                                when nvl(sum(second_serve_return_total), 0) > 0 then 1000 * trunc(sum(second_serve_return_won) / sum(second_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_2nd_return_won_pml_3y,
                      (select case
                                when nvl(sum(break_points_return_total), 0) > 0 then 1000 * trunc(nvl(sum(break_points_converted), 0) / nvl(sum(break_points_return_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_bp_won_pml_3y,
                      (select case
                                when nvl(sum(return_points_total), 0) > 0 then 1000 * trunc(nvl(sum(return_points_won), 0) / nvl(sum(return_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_return_won_pml_3y,
                      (select case
                                when nvl(sum(total_points_total), 0) > 0 then 1000 * trunc(nvl(sum(total_points_won), 0) / nvl(sum(total_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_total_won_pml_3y,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(aces) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_ace_pml_3y_surface,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(double_faults) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_df_pml_3y_surface,
                      (select case
                                when nvl(sum(first_serves_total), 0) > 0 then 1000 * trunc(sum(first_serves_in) / sum(first_serves_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_pml_3y_surface,
                      (select case
                                when nvl(sum(first_serves_in), 0) > 0 then 1000 * trunc(sum(first_serve_points_won) / sum(first_serves_in), 3)
                                else null
                              end win_1st_won_pml_3y
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_won_pml_3y_surface,
                      (select case
                                when nvl(sum(second_serve_points_total), 0) > 0 then 1000 * trunc(sum(second_serve_points_won) / sum(second_serve_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_2nd_won_pml_3y_surface,
                      (select case
                                when nvl(sum(break_points_serve_total), 0) > 0 then 1000 * trunc(sum(break_points_saved) / sum(break_points_serve_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_bp_saved_pml_3y_surface,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(service_points_won) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_srv_won_pml_3y_surface,
                      (select case
                                when nvl(sum(first_serve_return_total), 0) > 0 then 1000 * trunc(sum(first_serve_return_won) / sum(first_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_1st_return_won_pml_3y_sur,
                      (select case
                                when nvl(sum(second_serve_return_total), 0) > 0 then 1000 * trunc(sum(second_serve_return_won) / sum(second_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_2nd_return_won_pml_3y_sur,
                      (select case
                                when nvl(sum(break_points_return_total), 0) > 0 then 1000 * trunc(nvl(sum(break_points_converted), 0) / nvl(sum(break_points_return_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_bp_won_pml_3y_surface,
                      (select case
                                when nvl(sum(return_points_total), 0) > 0 then 1000 * trunc(nvl(sum(return_points_won), 0) / nvl(sum(return_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_return_won_pml_3y_surface,
                      (select case
                                when nvl(sum(total_points_total), 0) > 0 then 1000 * trunc(nvl(sum(total_points_won), 0) / nvl(sum(total_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.winner_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) win_total_won_pml_3y_surface,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(aces) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_ace_pml_3y,
                      (select case
                                when sum(service_points_total) > 0 then 1000 * trunc(sum(double_faults) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_df_pml_3y,
                      (select case
                                when sum(first_serves_total) > 0 then 1000 * trunc(sum(first_serves_in) / sum(first_serves_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_pml_3y,
                      (select case
                                when sum(first_serves_in) > 0 then 1000 * trunc(sum(first_serve_points_won) / sum(first_serves_in), 3)
                                else null
                              end qry
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_won_pml_3y,
                      (select case
                                when sum(second_serve_points_total) > 0 then 1000 * trunc(sum(second_serve_points_won) / sum(second_serve_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_2nd_won_pml_3y,
                      (select case
                                when sum(break_points_serve_total) > 0 then 1000 * trunc(sum(break_points_saved) / sum(break_points_serve_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_bp_saved_pml_3y,
                      (select case
                                when sum(service_points_total) > 0 then 1000 * trunc(sum(service_points_won) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_srv_won_pml_3y,
                      (select case
                                when sum(first_serve_return_total) > 0 then 1000 * trunc(sum(first_serve_return_won) / sum(first_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_return_won_pml_3y,
                      (select case
                                when sum(second_serve_return_total) > 0 then 1000 * trunc(sum(second_serve_return_won) / sum(second_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_2nd_return_won_pml_3y,
                      (select case
                                when nvl(sum(break_points_return_total), 0) > 0 then 1000 * trunc(nvl(sum(break_points_converted), 0) / nvl(sum(break_points_return_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_bp_won_pml_3y,
                      (select case
                                when nvl(sum(return_points_total), 0) > 0 then 1000 * trunc(nvl(sum(return_points_won), 0) / nvl(sum(return_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_return_won_pml_3y,
                      (select case
                                when nvl(sum(total_points_total), 0) > 0 then 1000 * trunc(nvl(sum(total_points_won), 0) / nvl(sum(total_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_total_won_pml_3y,
                      (select case
                                when nvl(sum(service_points_total), 0) > 0 then 1000 * trunc(sum(aces) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_ace_pml_3y_surface,
                      (select case
                                when sum(service_points_total) > 0 then 1000 * trunc(sum(double_faults) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_df_pml_3y_surface,
                      (select case
                                when sum(first_serves_total) > 0 then 1000 * trunc(sum(first_serves_in) / sum(first_serves_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_pml_3y_surface,
                      (select case
                                when sum(first_serves_in) > 0 then 1000 * trunc(sum(first_serve_points_won) / sum(first_serves_in), 3)
                                else null
                              end win_1st_won_pml_3y
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_won_pml_3y_surface,
                      (select case
                                when sum(second_serve_points_total) > 0 then 1000 * trunc(sum(second_serve_points_won) / sum(second_serve_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_2nd_won_pml_3y_surface,
                      (select case
                                when sum(break_points_serve_total) > 0 then 1000 * trunc(sum(break_points_saved) / sum(break_points_serve_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_bp_saved_pml_3y_surface,
                      (select case
                                when sum(service_points_total) > 0 then 1000 * trunc(sum(service_points_won) / sum(service_points_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_srv_won_pml_3y_surface,
                      (select case
                                when sum(first_serve_return_total) > 0 then 1000 * trunc(sum(first_serve_return_won) / sum(first_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_1st_return_won_pml_3y_sur,
                      (select case
                                when sum(second_serve_return_total) > 0 then 1000 * trunc(sum(second_serve_return_won) / sum(second_serve_return_total), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_2nd_return_won_pml_3y_sur,
                      (select case
                                when nvl(sum(break_points_return_total), 0) > 0 then 1000 * trunc(nvl(sum(break_points_converted), 0) / nvl(sum(break_points_return_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_bp_won_pml_3y_surface,
                      (select case
                                when nvl(sum(return_points_total), 0) > 0 then 1000 * trunc(nvl(sum(return_points_won), 0) / nvl(sum(return_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_return_won_pml_3y_surface,
                      (select case
                                when nvl(sum(total_points_total), 0) > 0 then 1000 * trunc(nvl(sum(total_points_won), 0) / nvl(sum(total_points_total), 0), 3)
                                else null
                              end qty
                       from vw_player_stats psi
                       where psi.match_ret is null
                         and psi.tournament_surface = vw.tournament_surface
                         and psi.player_code = vw.loser_code
                         and psi.tournament_ord_start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and psi.tournament_ord_start_dtm <  vw.tournament_ord_start_dtm
                      ) los_total_won_pml_3y_surface,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.id = pp.tournament_id
                         and pp.player_code = vw.winner_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) winner_3y_points,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.id = pp.tournament_id
                         and pp.player_code = vw.winner_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_52_weeks
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) winner_1y_points,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.id = pp.tournament_id
                         and pp.player_code = vw.loser_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) loser_3y_points,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.id = pp.tournament_id
                         and pp.player_code = vw.loser_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_52_weeks
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) loser_1y_points,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.surface = vw.tournament_surface
                         and t.id = pp.tournament_id
                         and pp.player_code = vw.winner_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) winner_3y_points_surface,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.surface = vw.tournament_surface
                         and t.id = pp.tournament_id
                         and pp.player_code = vw.winner_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_52_weeks
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) winner_1y_points_surface,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.surface = vw.tournament_surface
                         and t.id = pp.tournament_id
                         and pp.player_code = vw.loser_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_3_years
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) loser_3y_points_surface,
                      (select sum(pp.points) qty
                       from atp_tournaments t, player_points pp
                       where t.surface = vw.tournament_surface
                         and t.id = pp.tournament_id
                         and pp.player_code = vw.loser_code
                         and t.start_dtm >= vw.tournament_start_dtm - cv_52_weeks
                         and t.start_dtm <  vw.tournament_start_dtm
                      ) loser_1y_points_surface
              from vw_matches vw, (select c.column_value as id from table(p_match_ids) c) m
              where vw.id = m.id) i) s
  on (s.id = d.id)
  when not matched then
    insert (d.id, d.delta_hash, d.batch_id, d.win_h2h_qty_3y, d.los_h2h_qty_3y, d.win_win_qty_3y, d.win_los_qty_3y, d.los_win_qty_3y, d.los_los_qty_3y, d.win_avg_tiebreaks_pml_3y, d.los_avg_tiebreaks_pml_3y, d.win_h2h_qty_3y_surface, d.los_h2h_qty_3y_surface, d.win_win_qty_3y_surface, d.win_los_qty_3y_surface, d.los_win_qty_3y_surface, d.los_los_qty_3y_surface, d.win_avg_tiebreaks_pml_3y_sur, d.los_avg_tiebreaks_pml_3y_sur, d.win_ace_pml_3y, d.win_df_pml_3y, d.win_1st_pml_3y, d.win_1st_won_pml_3y, d.win_2nd_won_pml_3y, d.win_bp_saved_pml_3y, d.win_srv_won_pml_3y, d.win_1st_return_won_pml_3y, d.win_2nd_return_won_pml_3y, d.win_bp_won_pml_3y, d.win_return_won_pml_3y, d.win_total_won_pml_3y, d.win_ace_pml_3y_surface, d.win_df_pml_3y_surface, d.win_1st_pml_3y_surface, d.win_1st_won_pml_3y_surface, d.win_2nd_won_pml_3y_surface, d.win_bp_saved_pml_3y_surface, d.win_srv_won_pml_3y_surface, d.win_1st_return_won_pml_3y_sur, d.win_2nd_return_won_pml_3y_sur, d.win_bp_won_pml_3y_surface, d.win_return_won_pml_3y_surface, d.win_total_won_pml_3y_surface, d.los_ace_pml_3y, d.los_df_pml_3y, d.los_1st_pml_3y, d.los_1st_won_pml_3y, d.los_2nd_won_pml_3y, d.los_bp_saved_pml_3y, d.los_srv_won_pml_3y, d.los_1st_return_won_pml_3y, d.los_2nd_return_won_pml_3y, d.los_bp_won_pml_3y, d.los_return_won_pml_3y, d.los_total_won_pml_3y, d.los_ace_pml_3y_surface, d.los_df_pml_3y_surface, d.los_1st_pml_3y_surface, d.los_1st_won_pml_3y_surface, d.los_2nd_won_pml_3y_surface, d.los_bp_saved_pml_3y_surface, d.los_srv_won_pml_3y_surface, d.los_1st_return_won_pml_3y_sur, d.los_2nd_return_won_pml_3y_sur, d.los_bp_won_pml_3y_surface, d.los_return_won_pml_3y_surface, d.los_total_won_pml_3y_surface, d.winner_3y_points, d.winner_1y_points, d.loser_3y_points, d.loser_1y_points, d.winner_3y_points_surface, d.winner_1y_points_surface, d.loser_3y_points_surface, d.loser_1y_points_surface)
    values (s.id, s.delta_hash, s.batch_id, s.win_h2h_qty_3y, s.los_h2h_qty_3y, s.win_win_qty_3y, s.win_los_qty_3y, s.los_win_qty_3y, s.los_los_qty_3y, s.win_avg_tiebreaks_pml_3y, s.los_avg_tiebreaks_pml_3y, s.win_h2h_qty_3y_surface, s.los_h2h_qty_3y_surface, s.win_win_qty_3y_surface, s.win_los_qty_3y_surface, s.los_win_qty_3y_surface, s.los_los_qty_3y_surface, s.win_avg_tiebreaks_pml_3y_sur, s.los_avg_tiebreaks_pml_3y_sur, s.win_ace_pml_3y, s.win_df_pml_3y, s.win_1st_pml_3y, s.win_1st_won_pml_3y, s.win_2nd_won_pml_3y, s.win_bp_saved_pml_3y, s.win_srv_won_pml_3y, s.win_1st_return_won_pml_3y, s.win_2nd_return_won_pml_3y, s.win_bp_won_pml_3y, s.win_return_won_pml_3y, s.win_total_won_pml_3y, s.win_ace_pml_3y_surface, s.win_df_pml_3y_surface, s.win_1st_pml_3y_surface, s.win_1st_won_pml_3y_surface, s.win_2nd_won_pml_3y_surface, s.win_bp_saved_pml_3y_surface, s.win_srv_won_pml_3y_surface, s.win_1st_return_won_pml_3y_sur, s.win_2nd_return_won_pml_3y_sur, s.win_bp_won_pml_3y_surface, s.win_return_won_pml_3y_surface, s.win_total_won_pml_3y_surface, s.los_ace_pml_3y, s.los_df_pml_3y, s.los_1st_pml_3y, s.los_1st_won_pml_3y, s.los_2nd_won_pml_3y, s.los_bp_saved_pml_3y, s.los_srv_won_pml_3y, s.los_1st_return_won_pml_3y, s.los_2nd_return_won_pml_3y, s.los_bp_won_pml_3y, s.los_return_won_pml_3y, s.los_total_won_pml_3y, s.los_ace_pml_3y_surface, s.los_df_pml_3y_surface, s.los_1st_pml_3y_surface, s.los_1st_won_pml_3y_surface, s.los_2nd_won_pml_3y_surface, s.los_bp_saved_pml_3y_surface, s.los_srv_won_pml_3y_surface, s.los_1st_return_won_pml_3y_sur, s.los_2nd_return_won_pml_3y_sur, s.los_bp_won_pml_3y_surface, s.los_return_won_pml_3y_surface, s.los_total_won_pml_3y_surface, s.winner_3y_points, s.winner_1y_points, s.loser_3y_points, s.loser_1y_points, s.winner_3y_points_surface, s.winner_1y_points_surface, s.loser_3y_points_surface, s.loser_1y_points_surface)
  when matched then
    update set
      d.delta_hash                    = s.delta_hash,
      d.batch_id                      = s.batch_id,
      d.win_h2h_qty_3y                = s.win_h2h_qty_3y,
      d.los_h2h_qty_3y                = s.los_h2h_qty_3y,
      d.win_win_qty_3y                = s.win_win_qty_3y,
      d.win_los_qty_3y                = s.win_los_qty_3y,
      d.los_win_qty_3y                = s.los_win_qty_3y,
      d.los_los_qty_3y                = s.los_los_qty_3y,
      d.win_avg_tiebreaks_pml_3y      = s.win_avg_tiebreaks_pml_3y,
      d.los_avg_tiebreaks_pml_3y      = s.los_avg_tiebreaks_pml_3y,
      d.win_h2h_qty_3y_surface        = s.win_h2h_qty_3y_surface,
      d.los_h2h_qty_3y_surface        = s.los_h2h_qty_3y_surface,
      d.win_win_qty_3y_surface        = s.win_win_qty_3y_surface,
      d.win_los_qty_3y_surface        = s.win_los_qty_3y_surface,
      d.los_win_qty_3y_surface        = s.los_win_qty_3y_surface,
      d.los_los_qty_3y_surface        = s.los_los_qty_3y_surface,
      d.win_avg_tiebreaks_pml_3y_sur  = s.win_avg_tiebreaks_pml_3y_sur,
      d.los_avg_tiebreaks_pml_3y_sur  = s.los_avg_tiebreaks_pml_3y_sur,
      d.win_ace_pml_3y                = s.win_ace_pml_3y,
      d.win_df_pml_3y                 = s.win_df_pml_3y,
      d.win_1st_pml_3y                = s.win_1st_pml_3y,
      d.win_1st_won_pml_3y            = s.win_1st_won_pml_3y,
      d.win_2nd_won_pml_3y            = s.win_2nd_won_pml_3y,
      d.win_bp_saved_pml_3y           = s.win_bp_saved_pml_3y,
      d.win_srv_won_pml_3y            = s.win_srv_won_pml_3y,
      d.win_1st_return_won_pml_3y     = s.win_1st_return_won_pml_3y,
      d.win_2nd_return_won_pml_3y     = s.win_2nd_return_won_pml_3y,
      d.win_bp_won_pml_3y             = s.win_bp_won_pml_3y,
      d.win_return_won_pml_3y         = s.win_return_won_pml_3y,
      d.win_total_won_pml_3y          = s.win_total_won_pml_3y,
      d.win_ace_pml_3y_surface        = s.win_ace_pml_3y_surface,
      d.win_df_pml_3y_surface         = s.win_df_pml_3y_surface,
      d.win_1st_pml_3y_surface        = s.win_1st_pml_3y_surface,
      d.win_1st_won_pml_3y_surface    = s.win_1st_won_pml_3y_surface,
      d.win_2nd_won_pml_3y_surface    = s.win_2nd_won_pml_3y_surface,
      d.win_bp_saved_pml_3y_surface   = s.win_bp_saved_pml_3y_surface,
      d.win_srv_won_pml_3y_surface    = s.win_srv_won_pml_3y_surface,
      d.win_1st_return_won_pml_3y_sur = s.win_1st_return_won_pml_3y_sur,
      d.win_2nd_return_won_pml_3y_sur = s.win_2nd_return_won_pml_3y_sur,
      d.win_bp_won_pml_3y_surface     = s.win_bp_won_pml_3y_surface,
      d.win_return_won_pml_3y_surface = s.win_return_won_pml_3y_surface,
      d.win_total_won_pml_3y_surface  = s.win_total_won_pml_3y_surface,
      d.los_ace_pml_3y                = s.los_ace_pml_3y,
      d.los_df_pml_3y                 = s.los_df_pml_3y,
      d.los_1st_pml_3y                = s.los_1st_pml_3y,
      d.los_1st_won_pml_3y            = s.los_1st_won_pml_3y,
      d.los_2nd_won_pml_3y            = s.los_2nd_won_pml_3y,
      d.los_bp_saved_pml_3y           = s.los_bp_saved_pml_3y,
      d.los_srv_won_pml_3y            = s.los_srv_won_pml_3y,
      d.los_1st_return_won_pml_3y     = s.los_1st_return_won_pml_3y,
      d.los_2nd_return_won_pml_3y     = s.los_2nd_return_won_pml_3y,
      d.los_bp_won_pml_3y             = s.los_bp_won_pml_3y,
      d.los_return_won_pml_3y         = s.los_return_won_pml_3y,
      d.los_total_won_pml_3y          = s.los_total_won_pml_3y,
      d.los_ace_pml_3y_surface        = s.los_ace_pml_3y_surface,
      d.los_df_pml_3y_surface         = s.los_df_pml_3y_surface,
      d.los_1st_pml_3y_surface        = s.los_1st_pml_3y_surface,
      d.los_1st_won_pml_3y_surface    = s.los_1st_won_pml_3y_surface,
      d.los_2nd_won_pml_3y_surface    = s.los_2nd_won_pml_3y_surface,
      d.los_bp_saved_pml_3y_surface   = s.los_bp_saved_pml_3y_surface,
      d.los_srv_won_pml_3y_surface    = s.los_srv_won_pml_3y_surface,
      d.los_1st_return_won_pml_3y_sur = s.los_1st_return_won_pml_3y_sur,
      d.los_2nd_return_won_pml_3y_sur = s.los_2nd_return_won_pml_3y_sur,
      d.los_bp_won_pml_3y_surface     = s.los_bp_won_pml_3y_surface,
      d.los_return_won_pml_3y_surface = s.los_return_won_pml_3y_surface,
      d.los_total_won_pml_3y_surface  = s.los_total_won_pml_3y_surface,
      d.winner_3y_points              = s.winner_3y_points,
      d.winner_1y_points              = s.winner_1y_points,
      d.loser_3y_points               = s.loser_3y_points,
      d.loser_1y_points               = s.loser_1y_points,
      d.winner_3y_points_surface      = s.winner_3y_points_surface,
      d.winner_1y_points_surface      = s.winner_1y_points_surface,
      d.loser_3y_points_surface       = s.loser_3y_points_surface,
      d.loser_1y_points_surface       = s.loser_1y_points_surface
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
end sp_enrich_atp_matches;
/
