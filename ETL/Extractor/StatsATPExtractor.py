from typing import List, Tuple, Optional
import os
import re
from lxml import html

from base_extractor import baseExtractor  
from constants import DURATION_IN_DAYS


class StatsATPExtractor(baseExtractor):
    """
    Extract per-match statistics from atptour.com 'match-stats' pages and stage them
    into `stg_matches`.

    Workflow:
      1) Build the list of stat pages to visit (rolling window or by year).
      2) For each URL, detect winner/loser side and parse all stat blocks.
      3) Normalize values into the INSERT column order and append to `self.data`.
      4) Use baseExtractor.extract() to load into DB and run post-processing procs.

    Notes:
      - Pages may vary slightly in structure; XPaths are kept tolerant.
      - Only matches with missing stats are selected to avoid reprocessing.
    """

    def __init__(self, year: Optional[int]):
        super().__init__()
        self.year: Optional[int] = year
        self.url: str = ""
        self._stats_tpl_list: List[Tuple[str, str, str, str]] = []  # (winner_code, loser_code, stats_url, original_stats_url)

    # --------------------------------------------------------------------- #
    # Init / metadata                                                       #
    # --------------------------------------------------------------------- #

    def _init(self) -> None:
        """Configure logging, staging table, INSERT template, and stored procedures."""
        script = os.path.splitext(os.path.basename(__file__))[0]
        self.LOGFILE_NAME = f"./logs/{script}.log"
        self.CSVFILE_NAME = ""
        self.TABLE_NAME = "stg_matches"
        self.MODULE_NAME = "extract atp stats"

        # Order of placeholders MUST match the row we build in _parse_stats()
        self.INSERT_STR = (
            "INSERT INTO stg_matches("
            "stats_url, "
            "win_aces, win_double_faults, win_first_serves_in, win_first_serves_total, "
            "win_first_serve_points_won, win_first_serve_points_total, "
            "win_second_serve_points_won, win_second_serve_points_total, "
            "win_break_points_saved, win_break_points_serve_total, "
            "win_service_points_won, win_service_points_total, "
            "win_first_serve_return_won, win_first_serve_return_total, "
            "win_second_serve_return_won, win_second_serve_return_total, "
            "win_break_points_converted, win_break_points_return_total, "
            "win_service_games_played, win_return_games_played, "
            "win_return_points_won, win_return_points_total, "
            "win_total_points_won, win_total_points_total, "
            "los_aces, los_double_faults, los_first_serves_in, los_first_serves_total, "
            "los_first_serve_points_won, los_first_serve_points_total, "
            "los_second_serve_points_won, los_second_serve_points_total, "
            "los_break_points_saved, los_break_points_serve_total, "
            "los_service_points_won, los_service_points_total, "
            "los_first_serve_return_won, los_first_serve_return_total, "
            "los_second_serve_return_won, los_second_serve_return_total, "
            "los_break_points_converted, los_break_points_return_total, "
            "los_service_games_played, los_return_games_played, "
            "los_return_points_won, los_return_points_total, "
            "los_total_points_won, los_total_points_total"
            ") VALUES ("
            ":1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, "
            ":14, :15, :16, :17, :18, :19, :20, :21, :22, :23, :24, :25, "
            ":26, :27, :28, :29, :30, :31, :32, :33, :34, :35, :36, :37, "
            ":38, :39, :40, :41, :42, :43, :44, :45, :46, :47, :48, :49"
            ")"
        )

        self.PROCESS_PROC_NAMES = ["sp_process_atp_stats"]
        super()._init()

    # --------------------------------------------------------------------- #
    # Discovery                                                             #
    # --------------------------------------------------------------------- #

    def _build_stats_tpl_list(self) -> None:
        """
        Populate `self._stats_tpl_list` with tuples containing:
        (winner_code, loser_code, normalized_stats_url, original_stats_url)
        """
        cur = None
        try:
            cur = self.con.cursor()
            if self.year is None:
                # Rolling window for recent events
                sql = """
                    SELECT winner_code,
                           loser_code,
                           REPLACE(stats_url, 'stats-centre', 'match-stats') AS stats_url,
                           stats_url AS original_stats_url
                    FROM vw_atp_matches
                    WHERE stats_url IS NOT NULL
                      AND series_id != 'dc'
                      AND (win_aces IS NULL OR los_aces IS NULL)
                      AND tournament_start_dtm > SYSDATE - :duration
                    ORDER BY tournament_start_dtm DESC
                """
                self._stats_tpl_list = cur.execute(sql, {"duration": DURATION_IN_DAYS}).fetchall()
                self.logger.info(f"Parse stats for last {DURATION_IN_DAYS} days...")
            else:
                # Historical year scope (limited rows per run)
                sql = """
                    SELECT winner_code,
                           loser_code,
                           REPLACE(stats_url, 'stats-centre', 'match-stats') AS stats_url,
                           stats_url AS original_stats_url
                    FROM vw_matches
                    WHERE stats_url IS NOT NULL
                      AND series_id != 'dc'
                      AND (win_aces IS NULL OR los_aces IS NULL)
                      AND ROWNUM < :row_limit + 1
                      AND tournament_year = :year
                """
                self._stats_tpl_list = cur.execute(sql, {"year": self.year, "row_limit": 50}).fetchall()
                self.logger.info(f"Parse stats for year {self.year} ...")
        finally:
            if cur:
                cur.close()

        self.logger.info(f"Loading {len(self._stats_tpl_list)} row(s).")

    # --------------------------------------------------------------------- #
    # Parse orchestration                                                   #
    # --------------------------------------------------------------------- #

    def _parse(self) -> None:
        """Main parse loop over collected stat URLs."""
        self._build_stats_tpl_list()
        for stats_tpl in self._stats_tpl_list:
            self._parse_stats(stats_tpl)
            # Optional throttle if needed:
            # time.sleep(0.5)

    # --------------------------------------------------------------------- #
    # Single stats page parsing                                             #
    # --------------------------------------------------------------------- #

    def _parse_stats(self, url_tpl: Tuple[str, str, str, str]) -> None:
        """
        Parse a single match-stats page and append the row to `self.data`.

        Args:
            url_tpl: (winner_code, loser_code, normalized_stats_url, original_stats_url)
        """
        try:
            url = url_tpl[2]                 # normalized 'match-stats' URL
            original_stats_url = url_tpl[3]  # original reference URL (stored in DB)

            self.url = url
            html_str = self._request_url_by_chrome(self.url)
            if not html_str:
                self.logger.warning(f"Empty HTML for stats page: {url}")
                return

            tree = html.fromstring(html_str)

            # --- Detect left/right player blocks and the winner side ---
            left_is_winner = bool(tree.xpath("//div[@class='stats-item'][1]//div[contains(@class,'winner')]"))
            right_is_winner = bool(tree.xpath("//div[@class='stats-item'][2]//div[contains(@class,'winner')]"))

            if left_is_winner == right_is_winner:
                self.logger.warning("Cannot determine winner side unambiguously; skipping page.")
                return

            winner_is_left = left_is_winner

            # --- Collect value nodes (player/opponent views) ---
            player_stats_nodes = tree.xpath("//div[@class='player-stats-item']/div[@class='value']")
            opponent_stats_nodes = tree.xpath("//div[@class='opponent-stats-item']/div[@class='value']")
            if not player_stats_nodes or not opponent_stats_nodes:
                self.logger.warning("No stats value nodes found; skipping.")
                return

            # Parsers ----------------------------------------------------------------

            def parse_stat(raw_text: str) -> Tuple[Optional[int], Optional[int]]:
                """
                Parse a value string that can be either:
                  - a single integer like '12'           → (12, None)
                  - a ratio like '35% (12 / 20)'         → (12, 20)
                We remove '%' and keep only integers; returns (x, y).
                """
                s = (raw_text or "").strip().replace("%", "")
                m = re.search(r"\((\d+)\s*/\s*(\d+)\)", s)
                if m:
                    return int(m.group(1)), int(m.group(2))
                try:
                    return int(s), None
                except Exception:
                    return None, None

            def extract_all(nodes) -> List[Tuple[Optional[int], Optional[int]]]:
                out: List[Tuple[Optional[int], Optional[int]]] = []
                for el in nodes:
                    text = el.text_content().strip()
                    out.append(parse_stat(text))
                return out

            # Extract list of (value, total) pairs in on-page order
            player_stats = extract_all(player_stats_nodes)
            opponent_stats = extract_all(opponent_stats_nodes)

            # Winner/loser stat lists
            winner_stats = player_stats if winner_is_left else opponent_stats
            loser_stats = opponent_stats if winner_is_left else player_stats

            def get_pair(stats_list: List[Tuple[Optional[int], Optional[int]]],
                         idx: int,
                         default: Tuple[Optional[int], Optional[int]] = (None, None)
                         ) -> Tuple[Optional[int], Optional[int]]:
                return stats_list[idx] if 0 <= idx < len(stats_list) else default

            # Build INSERT row in the exact expected order -----------------------------

            row: List[Optional[int]] = [
                original_stats_url,                      # stats_url
                get_pair(winner_stats, 1)[0],           # win_aces
                get_pair(winner_stats, 2)[0],           # win_double_faults
                *get_pair(winner_stats, 3),             # win_first_serves_in, win_first_serves_total
                *get_pair(winner_stats, 4),             # win_first_serve_points_won, win_first_serve_points_total
                *get_pair(winner_stats, 5),             # win_second_serve_points_won, win_second_serve_points_total
                *get_pair(winner_stats, 6),             # win_break_points_saved, win_break_points_serve_total
                *get_pair(winner_stats, 10),            # win_service_points_won, win_service_points_total
                *get_pair(winner_stats, 7),             # win_first_serve_return_won, win_first_serve_return_total
                *get_pair(winner_stats, 8),             # win_second_serve_return_won, win_second_serve_return_total
                *get_pair(winner_stats, 9),             # win_break_points_converted, win_break_points_return_total
                get_pair(winner_stats, 11)[0],          # win_service_games_played
                get_pair(winner_stats, 12)[0],          # win_return_games_played
                *get_pair(winner_stats, 13),            # win_return_points_won, win_return_points_total
                *get_pair(winner_stats, 14),            # win_total_points_won, win_total_points_total

                get_pair(loser_stats, 1)[0],            # los_aces
                get_pair(loser_stats, 2)[0],            # los_double_faults
                *get_pair(loser_stats, 3),              # los_first_serves_in, los_first_serves_total
                *get_pair(loser_stats, 4),              # los_first_serve_points_won, los_first_serve_points_total
                *get_pair(loser_stats, 5),              # los_second_serve_points_won, los_second_serve_points_total
                *get_pair(loser_stats, 6),              # los_break_points_saved, los_break_points_serve_total
                *get_pair(loser_stats, 10),             # los_service_points_won, los_service_points_total
                *get_pair(loser_stats, 7),              # los_first_serve_return_won, los_first_serve_return_total
                *get_pair(loser_stats, 8),              # los_second_serve_return_won, los_second_serve_return_total
                *get_pair(loser_stats, 9),              # los_break_points_converted, los_break_points_return_total
                get_pair(loser_stats, 11)[0],           # los_service_games_played
                get_pair(loser_stats, 12)[0],           # los_return_games_played
                *get_pair(loser_stats, 13),             # los_return_points_won, los_return_points_total
                *get_pair(loser_stats, 14),             # los_total_points_won, los_total_points_total
            ]

            self.data.append(row)

        except Exception as e:
            self.logger.error(f"_parse_stats error for {url_tpl[2]}: {e}")

    # --------------------------------------------------------------------- #
    # DB load override (validation included)                                #
    # --------------------------------------------------------------------- #

    def _load_to_stg(self) -> None:
        """
        Override to validate row length vs. number of INSERT placeholders and
        log problematic rows instead of failing the whole batch.
        """
        cur = None
        try:
            self._connect_to_db()
            cur = self.con.cursor()

            if not (self.INSERT_STR and self.INSERT_STR.strip()):
                self.logger.warning("INSERT_STR is empty; skipping DB load.")
                return

            # Count placeholders robustly (':1', ':2', ...) rather than any colon
            expected_params = len(re.findall(r":\d+", self.INSERT_STR))
            valid_rows: List[List[Optional[int]]] = []

            for idx, row in enumerate(self.data):
                if len(row) != expected_params:
                    self.logger.error(
                        f"[Row {idx}] Wrong length: got {len(row)}, expected {expected_params} placeholders."
                    )
                    self.logger.info(f"Problematic row: {row}")
                    continue
                valid_rows.append(row)

            if valid_rows:
                cur.executemany(self.INSERT_STR, valid_rows)
                self.con.commit()
                self.logger.info(f"{len(valid_rows)} row(s) inserted.")
            else:
                self.logger.warning("No valid rows to insert.")
        finally:
            if cur:
                cur.close()
