create or replace function sf_atp_tournaments_delta_hash(
  pv_id                 atp_tournaments.id%type,
  pv_name               atp_tournaments.name%type,
  pn_year               atp_tournaments.year%type,
  pv_code               atp_tournaments.code%type,
  pv_url                atp_tournaments.url%type,
  pv_slug               atp_tournaments.slug%type,
  pv_location           atp_tournaments.location%type,
  pv_sgl_draw_url       atp_tournaments.sgl_draw_url%type,
  pv_sgl_pdf_url        atp_tournaments.sgl_pdf_url%type,
  pv_indoor_outdoor     atp_tournaments.indoor_outdoor%type,
  pv_surface            atp_tournaments.surface%type,
  pv_series_category_id atp_tournaments.series_category_id%type,
  pd_start_dtm          atp_tournaments.start_dtm%type,
  pd_finish_dtm         atp_tournaments.finish_dtm%type,
  pn_sgl_draw_qty       atp_tournaments.sgl_draw_qty%type,
  pn_dbl_draw_qty       atp_tournaments.dbl_draw_qty%type,
  pn_prize_money        atp_tournaments.prize_money%type,
  pv_prize_currency     atp_tournaments.prize_currency%type,
  pv_country_code       atp_tournaments.country_code%type,
  pn_points_rule_id     atp_tournaments.points_rule_id%type,
  pv_draw_template_id   atp_tournaments.draw_template_id%type
)
  return atp_tournaments.delta_hash%type
is
  vn_delta_hash atp_tournaments.delta_hash%type;
begin
  select ora_hash(pv_id || '|' || pv_name || '|' || pn_year || '|' || pv_code || '|' || pv_url || '|' || pv_slug || '|' || pv_location || '|' || pv_sgl_draw_url || '|' || pv_sgl_pdf_url || '|' || pv_indoor_outdoor || '|' || pv_surface || '|' || pv_series_category_id || '|' || to_char(pd_start_dtm, 'yyyymmdd') || '|' || to_char(pd_finish_dtm, 'yyyymmdd') || '|' || pn_sgl_draw_qty || '|' || pn_dbl_draw_qty || '|' || pn_prize_money || '|' || pv_prize_currency || '|' || pv_country_code || '|' || pn_points_rule_id || '|' || pv_draw_template_id)
  into vn_delta_hash
  from dual;
  return (vn_delta_hash);
end sf_atp_tournaments_delta_hash;
/
