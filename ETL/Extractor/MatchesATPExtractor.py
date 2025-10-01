from typing import List, Tuple, Optional
import os
from lxml import html

from matches_base_extractor import MatchesBaseExtractor  
from constants import ATP_URL_PREFIX, DURATION_IN_DAYS


class MatchesATPExtractor(MatchesBaseExtractor):
    """
    Extract ATP match-level data for a given year (or a rolling recent window) from atptour.com.

    Workflow:
      1) Build tournament URL list (by year or 'last N days').
      2) For each tournament results page, parse all match nodes.
      3) Resolve players, seeds, score (including tiebreaks / special cases), stats URL, duration.
      4) Normalize and aggregate set-level info via `parse_score()` from base class.
      5) Append rows to `self.data` in the order that matches `INSERT_STR`.

    Notes:
      - Relies on DB metadata for tournaments (URLs & years) to discover pages to parse.
      - Special cases for NextGen/Laver Cup and walkovers/retirements are handled upstream in `parse_score()`.
    """

    def __init__(self, year: Optional[int]):
        super().__init__()
        self.year: Optional[int] = year
        self.url: str = ""
        self._tournaments_list: List[Tuple[str, int]] = []

    # --------------------------------------------------------------------- #
    # Init / metadata                                                       #
    # --------------------------------------------------------------------- #

    def _init(self) -> None:
        """Configure logging, target table, SQL template, and stored procedures."""
        script = os.path.splitext(os.path.basename(__file__))[0]
        self.LOGFILE_NAME = f"./logs/{script}.log"
        self.CSVFILE_NAME = ""  # opcional: "matches.csv"
        self.MODULE_NAME = "extract atp matches"

        self.TABLE_NAME = "stg_matches"
        self.INSERT_STR = (
            "INSERT INTO stg_matches ("
            "id, tournament_id, stadie_id, match_order, winner_code, winner_url, loser_code, loser_url, "
            "winner_seed, loser_seed, score, stats_url, match_ret, winner_sets_won, loser_sets_won, "
            "winner_games_won, loser_games_won, winner_tiebreaks_won, loser_tiebreaks_won, match_duration"
            ") VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18, :19, :20)"
        )
        self.PROCESS_PROC_NAMES = [
            "sp_process_atp_matches",
            "sp_apply_points_rules",
            "sp_calculate_player_points",
            "sp_evolve_atp_draws",
            "sp_enrich_atp_draws",
        ]
        super()._init()

    # --------------------------------------------------------------------- #
    # Discovery                                                             #
    # --------------------------------------------------------------------- #

    def _build_tournaments_list(self) -> None:
        """
        Populate `self._tournaments_list` with (results_url, year) tuples.

        If `self.year` is None:
            - Load tournaments in a rolling window: [sysdate - DURATION_IN_DAYS, sysdate + 5].
        Else:
            - Load tournaments for the specific year.
        """
        cur = None
        try:
            cur = self.con.cursor()
            if self.year is None:
                sql = (
                    "SELECT url, year "
                    "FROM atp_tournaments "
                    "WHERE start_dtm BETWEEN sysdate - :duration AND sysdate + 5"
                )
                self._tournaments_list = cur.execute(sql, {"duration": DURATION_IN_DAYS}).fetchall()
                self.logger.info(f"Loading matches for the last {DURATION_IN_DAYS} days")
            else:
                sql = "SELECT url, year FROM atp_tournaments WHERE year = :year"
                self._tournaments_list = cur.execute(sql, {"year": self.year}).fetchall()
                self.logger.info(f"Loading matches for year {self.year}")
        finally:
            if cur:
                cur.close()

    # --------------------------------------------------------------------- #
    # Parse orchestration                                                   #
    # --------------------------------------------------------------------- #

    def _parse(self) -> None:
        """
        Main parse routine:
          - Build tournaments list.
          - Load adjustment dictionaries.
          - Parse each tournament page and append rows to `self.data`.
        """
        self._build_tournaments_list()
        self._fill_dic_match_scores_adj()
        self._fill_dic_match_scores_stats_url_adj()
        self._fill_dic_match_scores_skip_adj()

        for tournament_tpl in self._tournaments_list:
            self._parse_tournament(tournament_tpl)

    # --------------------------------------------------------------------- #
    # Helpers                                                               #
    # --------------------------------------------------------------------- #

    def _compose_score_from_score_item_arrays(
        self,
        winner_score_array: List[str],
        loser_score_array: List[str],
        tiebreak_array: List[str],
    ) -> str:
        """
        Compose a compact match score string from per-set arrays.

        Examples:
            winner=[6,7], loser=[4,6], tb=['', '5'] -> '64 76(5)'
        """
        if len(winner_score_array) != len(loser_score_array):
            self.logger.warning(
                f"winner_score_array({len(winner_score_array)}) != loser_score_array({len(loser_score_array)})"
            )

        parts: List[str] = []
        for i in range(min(len(winner_score_array), len(loser_score_array))):
            w = (winner_score_array[i] or "").strip()
            l = (loser_score_array[i] or "").strip()
            tb = (tiebreak_array[i] or "").strip() if i < len(tiebreak_array) else ""

            if tb:
                parts.append(f"{w}{l}({tb})")
            else:
                parts.append(f"{w}{l}")

        return " ".join(p for p in parts if p).strip()

    # --------------------------------------------------------------------- #
    # Per-tournament parsing                                                #
    # --------------------------------------------------------------------- #

    def _parse_tournament(self, tournament_tpl: Tuple[str, int]) -> None:
        """
        Parse all matches for a single tournament results page.

        Args:
            tournament_tpl: (results_url, year) tuple; when `self.year` is not None,
                            the second item is ignored in favor of `self.year`.
        """
        url, row_year = tournament_tpl[0], str(tournament_tpl[1])
        try:
            self.url = url
            self.response_str = self._request_url_by_chrome(url) or ""
            if not self.response_str:
                self.logger.warning(f"Empty HTML for tournament page: {url}")
                return

            # Extract tournament code from URL:
            # expected: .../en/scores/archive/<slug>/<code>/<year>/results
            code = ""
            try:
                parts = url.split("/")
                code = parts[7] if len(parts) > 7 else ""
            except Exception:
                pass

            tournament_year = str(self.year) if self.year is not None else row_year
            tournament_id = f"{tournament_year}-{code}" if code else tournament_year

            # Limit to the content block that contains group matches (legacy pages); fallback full HTML
            pos_begin = self.response_str.find('<div class="content content--group">')
            pos_end = self.response_str.find('<input type="hidden" id="primaryView"')
            snippet = (
                self.response_str[pos_begin : max(pos_begin, pos_end) - 30]
                if (pos_begin != -1 and pos_end != -1)
                else self.response_str
            )
            tree = html.fromstring(snippet)

            # Find all match containers
            match_nodes = tree.findall("./div/div/div/div/div/div/div[@class='match']")
            if not match_nodes:
                # fallback: broader XPath
                match_nodes = tree.xpath("//div[contains(@class,'match') and contains(@class,'match')]")

            for match_node in match_nodes:
                # --- Stadie/Round ---
                raw_stadie = match_node.xpath("./div[@class='match-header']/span/strong/text()")
                stadie_name = (raw_stadie[0] if raw_stadie else "").split("-")[0]
                # strip day suffixes commonly present
                for t in ("Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6"):
                    stadie_name = stadie_name.replace(t, "")
                stadie_name = stadie_name.strip()

                # Skip non-ATP draws occasionally mixed in
                if any(x in stadie_name for x in ("Wheelchair", "Champions Tour", "International Jr Event")):
                    continue

                stadie_id = self.remap_stadie_code(stadie_name) or ""

                # --- Player info blocks (two players) ---
                player_info_nodes = match_node.xpath(
                    "./div[@class='match-content']/div[@class='match-stats']/div[@class='stats-item']/div[@class='player-info']"
                )
                if len(player_info_nodes) != 2:
                    self.logger.warning(f"Unexpected player-info blocks: {len(player_info_nodes)}")
                    continue

                p1, p2 = player_info_nodes[0], player_info_nodes[1]

                # Player 1 URL/Name/Seed
                p1_url_rel = (p1.xpath("./div[@class='name']/a/@href") or [""])[0].lower()
                if not p1_url_rel:
                    self.logger.warning("Cannot resolve player_1_url; skipping node.")
                    continue
                p1_name = (p1.xpath("./div[@class='name']/a/text()") or [""])[0].strip()
                p1_seed = (
                    (p1.xpath("./div[@class='name']/span/text()") or [""])[0]
                    .replace("(", "")
                    .replace(")", "")
                    .strip()
                )

                # Winner flag (presence of a `.winner` div)
                p1_is_winner = bool(p1.xpath("./div[@class='winner']"))

                # Player 2 URL/Name/Seed
                p2_url_rel = (p2.xpath("./div[@class='name']/a/@href") or [""])[0].lower()
                p2_name = (p2.xpath("./div[@class='name']/a/text()") or [""])[0].strip()
                p2_seed = (
                    (p2.xpath("./div[@class='name']/span/text()") or [""])[0]
                    .replace("(", "")
                    .replace(")", "")
                    .strip()
                )

                # --- Scores per set (two score columns) ---
                score_cols = match_node.xpath(
                    "./div[@class='match-content']/div[@class='match-stats']/div[@class='stats-item']/div[@class='scores']"
                )
                if len(score_cols) != 2:
                    self.logger.warning(f"Unexpected score columns: {len(score_cols)}")

                # Accumulators
                p1_scores: List[str] = []
                p2_scores: List[str] = []
                tiebreaks: List[str] = []

                # Column 0 → player 1 set scores (and maybe tiebreaks)
                for item in (score_cols[0].xpath("./div[@class='score-item']") if score_cols else []):
                    cells = item.xpath("./*")
                    if not cells:
                        continue
                    p1_scores.append((cells[0].text or "").strip())
                    # If a second node exists, treat as tiebreak small score
                    tiebreaks.append((cells[1].text or "").strip() if len(cells) > 1 else "")

                # Column 1 → player 2 set scores (second may override tiebreak if present)
                for i, item in enumerate(score_cols[1].xpath("./div[@class='score-item']") if score_cols else []):
                    cells = item.xpath("./*")
                    if not cells:
                        continue
                    p2_scores.append((cells[0].text or "").strip())
                    if len(cells) > 1 and i < len(tiebreaks):
                        tiebreaks[i] = (cells[1].text or "").strip()

                # Winner / loser assignment
                if p1_is_winner:
                    winner_url = ATP_URL_PREFIX + self.remap_player_atp_url(p1_url_rel)
                    winner_name, winner_seed, w_scores = p1_name, p1_seed, p1_scores
                    loser_url = ATP_URL_PREFIX + self.remap_player_atp_url(p2_url_rel)
                    loser_name, loser_seed, l_scores = p2_name, p2_seed, p2_scores
                else:
                    winner_url = ATP_URL_PREFIX + self.remap_player_atp_url(p2_url_rel)
                    winner_name, winner_seed, w_scores = p2_name, p2_seed, p2_scores
                    loser_url = ATP_URL_PREFIX + self.remap_player_atp_url(p1_url_rel)
                    loser_name, loser_seed, l_scores = p1_name, p1_seed, p1_scores

                # Extract player codes from URLs
                try:
                    winner_code = winner_url.split("/")[6]
                    if len(winner_code) > 4:
                        self.logger.warning(f"Winner code too long: {winner_code} (len={len(winner_code)})")
                        continue
                except Exception as e:
                    if winner_name.lower().startswith("bye"):
                        self.logger.warning(f"Winner is BYE; skipping. detail={e}")
                        continue
                    self.logger.error(f"Cannot parse winner code from URL: {winner_url}; err={e}")
                    continue

                try:
                    loser_code = loser_url.split("/")[6]
                except Exception as e:
                    if loser_name.lower().startswith("bye") or loser_url == "http://www.atpworldtour.com#":
                        self.logger.warning(f"Loser is BYE/legacy; skipping. detail={e}")
                        continue
                    self.logger.error(f"Cannot parse loser code from URL: {loser_url}; err={e}")
                    continue

                # Match identifier (year-code-winner-loser-round)
                match_id = f"{tournament_id}-{winner_code}-{loser_code}-{stadie_id}"

                # Skip or override score if flagged
                if match_id in self._dic_match_scores_skip_adj:
                    continue

                # Compose score string
                if match_id in self._dic_match_scores_adj:
                    match_score = self._dic_match_scores_adj[match_id]
                    self.logger.warning(f"Score adjustment for {match_id}: {match_score}")
                else:
                    # Some pages have a 'match-notes' block with raw text like 'X wins the match 64 76(5)'
                    raw_notes = (match_node.xpath("./div[@class='match-notes']/text()") or [""])[0]
                    if raw_notes and "walkover" in raw_notes.lower():
                        match_score = "W/O"
                    elif raw_notes and "wins the match" in raw_notes:
                        # take everything after 'wins the match'
                        cut = raw_notes.lower().find("wins the match")
                        match_score = (
                            raw_notes[cut + len("wins the match") :]
                            .replace("\n", "")
                            .replace("\r", "")
                            .replace("\t", "")
                            .replace(".", "")
                            .replace("-", "")
                            .strip()
                        )
                    else:
                        match_score = self._compose_score_from_score_item_arrays(w_scores, l_scores, tiebreaks)

                # Squeeze multiple spaces
                while "  " in match_score:
                    match_score = match_score.replace("  ", " ")

                # Aggregate set-level stats (RET/W/O handled inside)
                score_array = self.parse_score(match_score, match_id, code)

                # Stats URL (if present)
                if match_id in self._dic_match_scores_stats_url_adj:
                    match_stats_url = self._dic_match_scores_stats_url_adj[match_id]
                    self.logger.warning(f"Stats URL adjustment for {match_id}: {match_stats_url}")
                else:
                    stats_href = match_node.xpath(
                        "./div[@class='match-footer']/div[@class='match-cta']"
                        "/a[text()='Match Stats' or text()='Stats']/@href"
                    )
                    match_stats_url = ATP_URL_PREFIX + stats_href[0].strip() if stats_href else ""

                # Match order (unavailable here)
                match_order = ""

                # Duration (mm:ss → minutes)
                dur_text = (match_node.xpath("./div[@class='match-header']/span[2]/text()") or [""])[0].strip()
                match_duration: Optional[int]
                if dur_text:
                    try:
                        mm, ss = [int(x) for x in dur_text.split(":")]
                        match_duration = 60 * mm + ss
                    except Exception as e:
                        self.logger.warning(f"Cannot parse duration '{dur_text}' for {match_id}: {e}")
                        match_duration = None
                else:
                    self.logger.warning(f"No duration found for {match_id}")
                    match_duration = None

                # Persist row (order MUST match INSERT_STR)
                self.data.append(
                    [
                        match_id,
                        tournament_id,
                        stadie_id,
                        match_order,
                        winner_code,
                        winner_url,
                        loser_code,
                        loser_url,
                        winner_seed,
                        loser_seed,
                        match_score,
                        match_stats_url,
                    ]
                    + score_array
                    + [match_duration]
                )

        except Exception as e:
            self.logger.error(f"url={url}; parse tournament error: {e}")
