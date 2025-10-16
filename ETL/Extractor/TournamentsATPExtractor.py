from typing import List, Optional, Tuple
from urllib.parse import urljoin
from lxml import html
import os

from base_extractor import BaseExtractor  
from constants import ATP_URL_PREFIX, ATP_TOURNAMENT_SERIES


class TournamentsATPExtractor(BaseExtractor):
    """
    Extract ATP tournament metadata for a given year from atptour.com.

    Workflow per series (ATP / Challenger / etc.):
      1) Build archive URL for the given year and series.
      2) Fetch and parse list entries (title, overview URL, dates, banner).
      3) For each tournament, open its overview page to get draw sizes, surface,
         location and prize details.
      4) Normalize fields (dates, country names) and append a row to `self.data`.

    Results are prepared to be inserted into `stg_tournaments` using `INSERT_STR`.
    """

    def __init__(self, year: int):
        super().__init__()
        self.year: int = year
        self.url: str = ""  # Not used directly; we fetch per-series inside _parse()

    # ------------------------------- Setup -----------------------------------

    def _init(self) -> None:
        """Initialize logging, staging targets and DB (via base _init)."""
        script = os.path.splitext(os.path.basename(__file__))[0]
        self.LOGFILE_NAME = f"./logs/{script}.log"
        self.CSVFILE_NAME = ""  # optional CSV export disabled by default
        self.MODULE_NAME = "extract atp tournaments"

        self.TABLE_NAME = "stg_tournaments"
        self.INSERT_STR = (
            "INSERT INTO stg_tournaments("
            "id, name, year, code, url, slug, location, sgl_draw_url, sgl_pdf_url, "
            "indoor_outdoor, surface, series, start_dtm, finish_dtm, sgl_draw_qty, "
            "dbl_draw_qty, prize_money, prize_currency, country_name"
            ") VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, "
            ":11, :12, :13, :14, :15, :16, :17, :18, :19)"
        )
        self.PROCESS_PROC_NAMES = [
            "sp_process_atp_tournaments",
            "sp_apply_points_rules",
            "sp_populate_atp_draws",
        ]
        super()._init()

    # ------------------------------- Parsing ---------------------------------

    def _parse(self) -> None:
        """Parse all configured series for the given year and populate `self.data`."""
        self.data = []
        for series in ATP_TOURNAMENT_SERIES:
            self._parse_series(series)

    def _parse_series(self, tournament_series: str) -> None:
        """
        Parse one tournament series (e.g., 'atp', 'ch', 'gs' depending on your constants).

        Args:
            tournament_series: Series key used by the ATP archive querystring.
        """
        archive_url = (
            f"{ATP_URL_PREFIX}/en/scores/results-archive"
            f"?year={self.year}&tournamentType={tournament_series}"
        )
        archive_html = self._request_url_by_chrome(archive_url)
        if not archive_html:
            self.logger.warning(f"Empty archive page for {archive_url}")
            return

        tree = html.fromstring(archive_html)

        # Lists extracted from archive page
        tournament_titles: List[str] = tree.xpath("//div[@class='top']/span[@class='name']/text()")
        overview_urls: List[str] = tree.xpath("//a[contains(@class,'tournament__profile')]/@href")
        date_labels: List[str] = tree.xpath("//div[@class='bottom']//span[contains(@class,'Date')]/text()")
        banners: List[str] = tree.xpath("//div[contains(@class,'event-badge_container')]//img[contains(@class,'events_banner')]/@src")

        n_items = min(len(overview_urls), len(tournament_titles), len(date_labels))
        if n_items == 0:
            self.logger.warning(f"No tournaments found in archive: {archive_url}")
            return

        for i in range(n_items):
            try:
                tournament_name = (tournament_titles[i] or "").strip()
                raw_dates = (date_labels[i] or "").strip()
                start_dtm, finish_dtm = self.parse_tournament_dates(raw_dates)

                overview_rel = (overview_urls[i] or "").strip()
                if not overview_rel:
                    # No overview link → skip this item
                    continue

                overview_url = urljoin(ATP_URL_PREFIX, overview_rel)

                # Attempt to extract slug and numeric code from the overview URL path
                # Expected pattern: /en/tournaments/<slug>/<code>/overview
                parts = overview_rel.strip("/").split("/")
                # '/en/tournaments/doha/451/overview' → ['en','tournaments','doha','451','overview']
                slug = parts[2] if len(parts) >= 3 else ""
                code = parts[3] if len(parts) >= 4 else ""
                if not slug or not code:
                    # Fallback: skip if malformed
                    self.logger.warning(f"Malformed overview URL (slug/code missing): {overview_rel}")
                    continue

                # Build scores archive URLs
                results_url = f"{ATP_URL_PREFIX}/en/scores/archive/{slug}/{code}/{self.year}/results"
                draws_url = results_url[:-7] + "draws" if results_url.endswith("results") else results_url

                # PDF draw (singles main draw)
                sgl_pdf_url = f"https://www.protennislive.com/posting/{self.year}/{code}/mds.pdf"

                tournament_id = f"{self.year}-{code}"

                # Fetch overview page to get left/right columns info
                overview_html = self._request_url_by_chrome(overview_url)
                if not overview_html:
                    self.logger.warning(f"Empty overview page for {overview_url}")
                    continue

                o = html.fromstring(overview_html)

                # Draw sizes (e.g., "32/16")
                draw_texts: List[str] = o.xpath("//div[@class='td_content']/ul[@class='td_left']/li[2]/span[2]/text()")
                draw_str = (draw_texts[0] or "").strip() if draw_texts else ""
                sgl_draw_qty, dbl_draw_qty = self._split_draw(draw_str)

                # Surface
                surface_texts: List[str] = o.xpath("//div[@class='td_content']/ul[@class='td_left']/li[3]/span[2]/text()")
                surface = (surface_texts[0] or "").strip() if surface_texts else ""
                surface = self.remap_surface_name(surface) or surface  # normalize if mapping exists

                # Prize money / currency
                prize_texts: List[str] = o.xpath("//div[@class='td_content']/ul[@class='td_left']/li[4]/span[2]/text()")
                prize_money, prize_currency = self._parse_prize(prize_texts[0] if prize_texts else "")

                # Location (e.g., "Doha, Qatar")
                loc_texts: List[str] = o.xpath("//div[@class='td_content']/ul[@class='td_right']/li[1]/span[2]/text()")
                location = (loc_texts[0] or "").strip() if loc_texts else ""
                city, country_name = self._split_location(location)
                country_name = self.remap_country_name(country_name)
                country_name = self.remap_country_name_by_location(city, country_name)

                # Indoor/Outdoor: not visible in the used blocks reliably in all pages → leave blank for now
                indoor_outdoor = ""

                # Series category heuristic (uses banner on archive row if available)
                banner = banners[i] if i < len(banners) else ""
                series_category = self._infer_series_category(tournament_series, banner, prize_money)

                # Skip doubles-only code if needed
                if code != "602":
                    self.data.append([
                        tournament_id, tournament_name, self.year, code, results_url, slug,
                        city, draws_url, sgl_pdf_url, indoor_outdoor,
                        surface, series_category, start_dtm, finish_dtm, sgl_draw_qty,
                        dbl_draw_qty, prize_money, prize_currency, country_name
                    ])

            except Exception as e:
                self.logger.warning(f"Row parse error: {e}")
                # Useful breadcrumbs for debugging
                try:
                    self.logger.warning(f"  overview_rel={overview_rel}")
                except Exception:
                    pass
                try:
                    self.logger.warning(f"  tournament_name={tournament_name}")
                except Exception:
                    pass
                try:
                    self.logger.warning(f"  raw_dates={raw_dates}")
                except Exception:
                    pass
                continue

    # ------------------------------- Helpers ---------------------------------

    @staticmethod
    def _split_draw(draw_str: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Split a draw string like '32/16' into singles/doubles entries.
        """
        if not draw_str or "/" not in draw_str:
            return None, None
        left, right = [x.strip() for x in draw_str.split("/", 1)]
        return left or None, right or None

    def _parse_prize(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Parse prize text like '€2,345,000' or 'A$1,234,567' into (money, currency).

        Returns:
            (prize_money_numeric_string, currency_code) or (None, None) if empty.
        """
        s = (text or "").strip()
        if not s:
            return None, None

        # The original logic uses first one/two chars as currency (A$ case)
        # Keep backward-compat behavior:
        if s.startswith("A$"):
            currency = "A$"
            money = s[2:]
        else:
            currency = s[0]
            money = s[1:]

        money = money.replace(",", "").replace(".", "")
        return (money or None), currency

    @staticmethod
    def _split_location(loc: str) -> Tuple[str, str]:
        """
        Split 'City, Country' into (city, country). If no comma, return ('', loc).
        """
        if not loc:
            return "", ""
        parts = [x.strip() for x in loc.split(",")]
        if len(parts) == 1:
            return "", parts[0]
        return parts[0], parts[-1]

    def _infer_series_category(self, series_key: str, banner_src: str, prize_money: Optional[str]) -> str:
        """
        Infer tournament series category based on archive banner and/or prize.

        Args:
            series_key: 'atp', 'ch', etc. from querystring.
            banner_src: img src extracted from the archive row.
            prize_money: numeric-string (no separators), if available.

        Returns:
            A normalized series label (e.g., 'atp500', '1000', 'atpFinal', 'ch100', 'ch50', etc.).
        """
        if series_key == "atp":
            b = banner_src or ""
            # Use 'contains' checks to avoid tight coupling to exact paths
            if "categorystamps_500" in b:
                return "atp500"
            if "categorystamps_finals" in b:
                return "atpFinal"
            if "categorystamps_atpcup" in b:
                return "atpCup"
            if "categorystamps_lvr" in b:
                return "laverCup"
            if "categorystamps_nextgen" in b:
                return "nextGen"
            if "categorystamps_1000" in b:
                return "1000"
            return "atp250"

        if series_key == "ch":
            try:
                # keep your original threshold logic
                if prize_money is not None and int(prize_money) >= 75000:
                    return "ch100"
            except Exception:
                pass
            return "ch50"

        # Fallback: return the provided series key
        return series_key
