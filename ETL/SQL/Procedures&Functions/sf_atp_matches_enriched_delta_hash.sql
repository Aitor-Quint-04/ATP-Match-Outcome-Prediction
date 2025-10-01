create or replace function sf_atp_matches_enriched_dh(
  pv_id                          atp_matches_enriched.id%type,
  pn_win_h2h_qty_3y              atp_matches_enriched.win_h2h_qty_3y%type,
  pn_los_h2h_qty_3y              atp_matches_enriched.los_h2h_qty_3y%type,
  pn_win_win_qty_3y              atp_matches_enriched.win_win_qty_3y%type,
  pn_win_los_qty_3y              atp_matches_enriched.win_los_qty_3y%type,
  pn_los_win_qty_3y              atp_matches_enriched.los_win_qty_3y%type,
  pn_los_los_qty_3y              atp_matches_enriched.los_los_qty_3y%type,
  pn_win_avg_tiebreaks_pml_3y    atp_matches_enriched.win_avg_tiebreaks_pml_3y%type,
  pn_los_avg_tiebreaks_pml_3y    atp_matches_enriched.los_avg_tiebreaks_pml_3y%type,
  pn_win_h2h_qty_3y_surface      atp_matches_enriched.win_h2h_qty_3y_surface%type,
  pn_los_h2h_qty_3y_surface      atp_matches_enriched.los_h2h_qty_3y_surface%type,
  pn_win_win_qty_3y_surface      atp_matches_enriched.win_win_qty_3y_surface%type,
  pn_win_los_qty_3y_surface      atp_matches_enriched.win_los_qty_3y_surface%type,
  pn_los_win_qty_3y_surface      atp_matches_enriched.los_win_qty_3y_surface%type,
  pn_los_los_qty_3y_surface      atp_matches_enriched.los_los_qty_3y_surface%type,
  pn_win_avg_tiebreaks_pml_3y_s  atp_matches_enriched.win_avg_tiebreaks_pml_3y_sur%type,
  pn_los_avg_tiebreaks_pml_3y_s  atp_matches_enriched.los_avg_tiebreaks_pml_3y_sur%type,
  pn_win_ace_pml_3y              atp_matches_enriched.win_ace_pml_3y%type,
  pn_win_df_pml_3y               atp_matches_enriched.win_df_pml_3y%type,
  pn_win_1st_pml_3y              atp_matches_enriched.win_1st_pml_3y%type,
  pn_win_1st_won_pml_3y          atp_matches_enriched.win_1st_won_pml_3y%type,
  pn_win_2nd_won_pml_3y          atp_matches_enriched.win_2nd_won_pml_3y%type,
  pn_win_bp_saved_pml_3y         atp_matches_enriched.win_bp_saved_pml_3y%type,
  pn_win_srv_won_pml_3y          atp_matches_enriched.win_srv_won_pml_3y%type,
  pn_win_1st_return_won_pml_3y   atp_matches_enriched.win_1st_return_won_pml_3y%type,
  pn_win_2nd_return_won_pml_3y   atp_matches_enriched.win_2nd_return_won_pml_3y%type,
  pn_win_bp_won_pml_3y           atp_matches_enriched.win_bp_won_pml_3y%type,
  pn_win_return_won_pml_3y       atp_matches_enriched.win_return_won_pml_3y%type,
  pn_win_total_won_pml_3y        atp_matches_enriched.win_total_won_pml_3y%type,
  pn_win_ace_pml_3y_surface      atp_matches_enriched.win_ace_pml_3y_surface%type,
  pn_win_df_pml_3y_surface       atp_matches_enriched.win_df_pml_3y_surface%type,
  pn_win_1st_pml_3y_surface      atp_matches_enriched.win_1st_pml_3y_surface%type,
  pn_win_1st_won_pml_3y_surface  atp_matches_enriched.win_1st_won_pml_3y_surface%type,
  pn_win_2nd_won_pml_3y_surface  atp_matches_enriched.win_2nd_won_pml_3y_surface%type,
  pn_win_bp_saved_pml_3y_surface atp_matches_enriched.win_bp_saved_pml_3y_surface%type,
  pn_win_srv_won_pml_3y_surface  atp_matches_enriched.win_srv_won_pml_3y_surface%type,
  pn_win_1st_return_won_pml_3y_s atp_matches_enriched.win_1st_return_won_pml_3y_sur%type,
  pn_win_2nd_return_won_pml_3y_s atp_matches_enriched.win_2nd_return_won_pml_3y_sur%type,
  pn_win_bp_won_pml_3y_surface   atp_matches_enriched.win_bp_won_pml_3y_surface%type,
  pn_win_return_won_pml_3y_sur   atp_matches_enriched.win_return_won_pml_3y_surface%type,
  pn_win_total_won_pml_3y_sur    atp_matches_enriched.win_total_won_pml_3y_surface%type,
  pn_los_ace_pml_3y              atp_matches_enriched.los_ace_pml_3y%type,
  pn_los_df_pml_3y               atp_matches_enriched.los_df_pml_3y%type,
  pn_los_1st_pml_3y              atp_matches_enriched.los_1st_pml_3y%type,
  pn_los_1st_won_pml_3y          atp_matches_enriched.los_1st_won_pml_3y%type,
  pn_los_2nd_won_pml_3y          atp_matches_enriched.los_2nd_won_pml_3y%type,
  pn_los_bp_saved_pml_3y         atp_matches_enriched.los_bp_saved_pml_3y%type,
  pn_los_srv_won_pml_3y          atp_matches_enriched.los_srv_won_pml_3y%type,
  pn_los_1st_return_won_pml_3y   atp_matches_enriched.los_1st_return_won_pml_3y%type,
  pn_los_2nd_return_won_pml_3y   atp_matches_enriched.los_2nd_return_won_pml_3y%type,
  pn_los_bp_won_pml_3y           atp_matches_enriched.los_bp_won_pml_3y%type,
  pn_los_return_won_pml_3y       atp_matches_enriched.los_return_won_pml_3y%type,
  pn_los_total_won_pml_3y        atp_matches_enriched.los_total_won_pml_3y%type,
  pn_los_ace_pml_3y_surface      atp_matches_enriched.los_ace_pml_3y_surface%type,
  pn_los_df_pml_3y_surface       atp_matches_enriched.los_df_pml_3y_surface%type,
  pn_los_1st_pml_3y_surface      atp_matches_enriched.los_1st_pml_3y_surface%type,
  pn_los_1st_won_pml_3y_surface  atp_matches_enriched.los_1st_won_pml_3y_surface%type,
  pn_los_2nd_won_pml_3y_surface  atp_matches_enriched.los_2nd_won_pml_3y_surface%type,
  pn_los_bp_saved_pml_3y_surface atp_matches_enriched.los_bp_saved_pml_3y_surface%type,
  pn_los_srv_won_pml_3y_surface  atp_matches_enriched.los_srv_won_pml_3y_surface%type,
  pn_los_1st_return_won_pml_3y_s atp_matches_enriched.los_1st_return_won_pml_3y_sur%type,
  pn_los_2nd_return_won_pml_3y_s atp_matches_enriched.los_2nd_return_won_pml_3y_sur%type,
  pn_los_bp_won_pml_3y_surface   atp_matches_enriched.los_bp_won_pml_3y_surface%type,
  pn_los_return_won_pml_3y_sur   atp_matches_enriched.los_return_won_pml_3y_surface%type,
  pn_los_total_won_pml_3y_sur    atp_matches_enriched.los_total_won_pml_3y_surface%type,
  pn_winner_3y_points            atp_matches_enriched.winner_3y_points%type,
  pn_winner_1y_points            atp_matches_enriched.winner_1y_points%type,
  pn_loser_3y_points             atp_matches_enriched.loser_3y_points%type,
  pn_loser_1y_points             atp_matches_enriched.loser_1y_points%type,
  pn_winner_3y_points_surface    atp_matches_enriched.winner_3y_points_surface%type,
  pn_winner_1y_points_surface    atp_matches_enriched.winner_1y_points_surface%type,
  pn_loser_3y_points_surface     atp_matches_enriched.loser_3y_points_surface%type,
  pn_loser_1y_points_surface     atp_matches_enriched.loser_1y_points_surface%type
)
  return atp_matches.delta_hash%type
is
  vn_delta_hash atp_matches.delta_hash%type;
begin
  select ora_hash(pv_id || '|' || pn_win_h2h_qty_3y || '|' || pn_los_h2h_qty_3y || '|' || pn_win_win_qty_3y || '|' || pn_win_los_qty_3y || '|' || 
                  pn_los_win_qty_3y || '|' || pn_los_los_qty_3y || '|' || pn_win_avg_tiebreaks_pml_3y || '|' || pn_los_avg_tiebreaks_pml_3y || '|' || pn_win_h2h_qty_3y_surface || '|' || 
                  pn_los_h2h_qty_3y_surface || '|' || pn_win_win_qty_3y_surface || '|' || pn_win_los_qty_3y_surface || '|' || pn_los_win_qty_3y_surface || '|' || pn_los_los_qty_3y_surface || '|' || 
                  pn_win_avg_tiebreaks_pml_3y_s || '|' || pn_los_avg_tiebreaks_pml_3y_s || '|' || pn_win_ace_pml_3y || '|' || pn_win_df_pml_3y || '|' || pn_win_1st_pml_3y || '|' || 
                  pn_win_1st_won_pml_3y || '|' || pn_win_2nd_won_pml_3y || '|' || pn_win_bp_saved_pml_3y || '|' || pn_win_srv_won_pml_3y || '|' || pn_win_1st_return_won_pml_3y || '|' || 
                  pn_win_2nd_return_won_pml_3y || '|' || pn_win_bp_won_pml_3y || '|' || pn_win_return_won_pml_3y || '|' || pn_win_total_won_pml_3y || '|' || pn_win_ace_pml_3y_surface || '|' || 
                  pn_win_df_pml_3y_surface || '|' || pn_win_1st_pml_3y_surface || '|' || pn_win_1st_won_pml_3y_surface || '|' || pn_win_2nd_won_pml_3y_surface || '|' || pn_win_bp_saved_pml_3y_surface || '|' || 
                  pn_win_srv_won_pml_3y_surface || '|' || pn_win_1st_return_won_pml_3y_s || '|' || pn_win_2nd_return_won_pml_3y_s || '|' || pn_win_bp_won_pml_3y_surface || '|' || 
                  pn_win_return_won_pml_3y_sur || '|' || pn_win_total_won_pml_3y_sur || '|' || pn_los_ace_pml_3y || '|' || pn_los_df_pml_3y || '|' || pn_los_1st_pml_3y || '|' || 
                  pn_los_1st_won_pml_3y || '|' || pn_los_2nd_won_pml_3y || '|' || pn_los_bp_saved_pml_3y || '|' || pn_los_srv_won_pml_3y || '|' || pn_los_1st_return_won_pml_3y || '|' || 
                  pn_los_2nd_return_won_pml_3y || '|' || pn_los_bp_won_pml_3y || '|' || pn_los_return_won_pml_3y || '|' || pn_los_total_won_pml_3y || '|' || pn_los_ace_pml_3y_surface || '|' || 
                  pn_los_df_pml_3y_surface || '|' || pn_los_1st_pml_3y_surface || '|' || pn_los_1st_won_pml_3y_surface || '|' || pn_los_2nd_won_pml_3y_surface || '|' || pn_los_bp_saved_pml_3y_surface || '|' || 
                  pn_los_srv_won_pml_3y_surface || '|' || pn_los_1st_return_won_pml_3y_s || '|' || pn_los_2nd_return_won_pml_3y_s || '|' || pn_los_bp_won_pml_3y_surface || '|' || 
                  pn_los_return_won_pml_3y_sur || '|' || pn_los_total_won_pml_3y_sur || '|' || pn_winner_3y_points || '|' || pn_winner_1y_points || '|' || pn_loser_3y_points || '|' || 
                  pn_loser_1y_points || '|' || pn_winner_3y_points_surface || '|' || pn_winner_1y_points_surface || '|' || pn_loser_3y_points_surface || '|' || pn_loser_1y_points_surface)
  into vn_delta_hash
  from dual;
  return (vn_delta_hash);
end sf_atp_matches_enriched_dh;
/
