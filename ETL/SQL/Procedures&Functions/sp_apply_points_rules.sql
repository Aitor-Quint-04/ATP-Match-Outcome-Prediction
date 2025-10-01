create or replace procedure sp_apply_points_rules
is
  cv_module_name constant varchar2(200) := 'apply points rules';
  vn_qty         number;
  vn_batch_id    logger.batches.id%type;
begin
  pkg_log.sp_start_batch(pv_module => cv_module_name, pv_server => pkg_log.sf_get_server_name, pn_batch_id => vn_batch_id);
  --
  merge into atp_tournaments d
  using(select i.*,
               sf_atp_tournaments_delta_hash(
                 pv_id                 => i.id,
                 pv_name               => i.name,
                 pn_year               => i.year,
                 pv_code               => i.code,
                 pv_url                => i.url,
                 pv_slug               => i.slug,
                 pv_location           => i.location,
                 pv_sgl_draw_url       => i.sgl_draw_url,
                 pv_sgl_pdf_url        => i.sgl_pdf_url,
                 pv_indoor_outdoor     => i.indoor_outdoor,
                 pv_surface            => i.surface,
                 pv_series_category_id => i.series_category_id,
                 pd_start_dtm          => i.start_dtm,
                 pd_finish_dtm         => i.finish_dtm,
                 pn_sgl_draw_qty       => i.sgl_draw_qty,
                 pn_dbl_draw_qty       => i.dbl_draw_qty,
                 pn_prize_money        => i.prize_money,
                 pv_prize_currency     => i.prize_currency,
                 pv_country_code       => i.country_code,
                 pn_points_rule_id     => i.points_rule_id,
                 pv_draw_template_id   => i.draw_template_id) as delta_hash
        from (select t.id, t.name, t.year, t.code, t.url, t.slug, t.location, t.sgl_draw_url, t.sgl_pdf_url, t.indoor_outdoor, t.surface, t.series_category_id, t.start_dtm, t.finish_dtm, t.sgl_draw_qty, t.dbl_draw_qty, t.prize_money, t.prize_currency, t.country_code, r.id as points_rule_id, t.draw_template_id
              from (select m.tournament_id, min(m.stadie_ord) as stadie_ord
                    from vw_atp_matches m
                    where m.stadie_draw = 'M'
                     and m.series_category_id != 'dc'
                    group by m.tournament_id) ii,
                   stadies s,
                   atp_tournaments t,
                   points_rules r
              where s.ord = ii.stadie_ord
                and ii.tournament_id = t.id
                and r.series_category_id = t.series_category_id
                and r.first_stadie_id = s.id
              union all
              select t.id, t.name, t.year, t.code, t.url, t.slug, t.location, t.sgl_draw_url, t.sgl_pdf_url, t.indoor_outdoor, t.surface, t.series_category_id, t.start_dtm, t.finish_dtm, t.sgl_draw_qty, t.dbl_draw_qty, t.prize_money, t.prize_currency, t.country_code, r.id as points_rule_id, t.draw_template_id
              from (select m.tournament_id, min(m.stadie_ord) as stadie_ord
                    from vw_atp_matches m
                    where m.stadie_draw = 'M'
                     and m.series_category_id != 'dc'
                    group by m.tournament_id) ii,
                   stadies s,
                   atp_tournaments t,
                   points_rules r
              where s.ord = ii.stadie_ord
                and ii.tournament_id = t.id
                and r.series_category_id = t.series_category_id
                and r.first_stadie_id is null) i ) s
  on (s.id = d.id)
  when matched then
    update set
      d.delta_hash         = s.delta_hash,
      d.batch_id           = vn_batch_id,
      d.points_rule_id     = s.points_rule_id
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
end sp_apply_points_rules;
/
