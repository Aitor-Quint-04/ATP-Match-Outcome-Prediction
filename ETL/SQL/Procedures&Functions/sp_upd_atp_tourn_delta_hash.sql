create or replace procedure sp_upd_atp_tourn_delta_hash(
  pv_id atp_tournaments.id%type)
is
begin
  update atp_tournaments t
    set delta_hash = sf_atp_tournaments_delta_hash(
          pv_id                 => t.id,
          pv_name               => t.name,
          pn_year               => t.year,
          pv_code               => t.code,
          pv_url                => t.url,
          pv_slug               => t.slug,
          pv_location           => t.location,
          pv_sgl_draw_url       => t.sgl_draw_url,
          pv_sgl_pdf_url        => t.sgl_pdf_url,
          pv_indoor_outdoor     => t.indoor_outdoor,
          pv_surface            => t.surface,
          pv_series_category_id => t.series_category_id,
          pd_start_dtm          => t.start_dtm,
          pd_finish_dtm         => t.finish_dtm,
          pn_sgl_draw_qty       => t.sgl_draw_qty,
          pn_dbl_draw_qty       => t.dbl_draw_qty,
          pn_prize_money        => t.prize_money,
          pv_prize_currency     => t.prize_currency,
          pv_country_code       => t.country_code,
          pn_points_rule_id     => t.points_rule_id,
          pv_draw_template_id   => t.draw_template_id)
  where t.id = pv_id;
end sp_upd_atp_tourn_delta_hash;
/
