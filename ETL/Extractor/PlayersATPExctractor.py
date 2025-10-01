from typing import List, Tuple, Optional
import os
import re
from lxml import html

from base_extractor import baseExtractor  


class PlayersATPExtractor(baseExtractor):
    """
    Extract ATP player profiles for a given year and stage them into `stg_players`.

    Workflow:
      1) Build the list of player profile URLs from DB (for a given year or missing names).
      2) For each profile URL, fetch the page and parse core biographical fields.
      3) Append rows to `self.data` matching the INSERT_STR column order.

    Notes:
      - This extractor relies on DB metadata (matches/tournaments) to discover players.
      - HTML structure on atptour.com may vary; XPaths are written to be tolerant.
    """

    def __init__(self, year: Optional[int]):
        super().__init__()
        self.year: Optional[int] = year
        self.url: str = ""
        self._players_url_list: List[Tuple[str]] = []

    # --------------------------------------------------------------------- #
    # Init / metadata                                                       #
    # --------------------------------------------------------------------- #

    def _init(self) -> None:
        """Configure logging, target table, SQL template, and stored procedures."""
        log_dir = "./logs"
        os.makedirs(log_dir, exist_ok=True)

        script = os.path.splitext(os.path.basename(__file__))[0]
        self.LOGFILE_NAME = f"{log_dir}/{script}.log"
        self.CSVFILE_NAME = ""  # optional CSV export
        self.TABLE_NAME = "stg_players"
        self.MODULE_NAME = "extract atp players"

        # Column order MUST match the sequence below
        self.INSERT_STR = """
            INSERT INTO stg_players(
                player_code, player_slug, first_name, last_name, player_url,
                flag_code, residence, birthplace, birthdate, turned_pro,
                weight_kg, height_cm, handedness, backhand
            ) VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14)
        """

        self.PROCESS_PROC_NAMES = ["sp_process_atp_players"]
        super()._init()

    # --------------------------------------------------------------------- #
    # Discovery                                                             #
    # --------------------------------------------------------------------- #

    def _build_players_url_list(self) -> None:
        """
        Populate `self._players_url_list` from DB.

        If `self.year` is None:
            - Load only players with missing first/last name.
        Else:
            - Load distinct player URLs that appear as winner/loser in matches for that year.
        """
        cur = None
        try:
            cur = self.con.cursor()
            if self.year is None:
                sql = "SELECT url FROM atp_players WHERE first_name IS NULL"
                self._players_url_list = cur.execute(sql).fetchall()
                self.logger.info("Loading players with empty names only")
            else:
                sql = """
                    SELECT DISTINCT w.url
                    FROM atp_players w
                    JOIN atp_matches m ON m.winner_code = w.code
                    JOIN atp_tournaments t ON m.tournament_id = t.id
                    WHERE t.year = :year
                    UNION
                    SELECT DISTINCT l.url
                    FROM atp_players l
                    JOIN atp_matches m ON m.loser_code = l.code
                    JOIN atp_tournaments t ON m.tournament_id = t.id
                    WHERE t.year = :year
                """
                self._players_url_list = cur.execute(sql, {"year": self.year}).fetchall()
                self.logger.info(f"Loading players for year {self.year}")
        finally:
            if cur:
                cur.close()

    # --------------------------------------------------------------------- #
    # Parse orchestration                                                   #
    # --------------------------------------------------------------------- #

    def _parse(self) -> None:
        """
        Main parse routine:
          - Discover profile URLs.
          - Iterate and parse each profile.
          - Append rows to `self.data`.
        """
        self._build_players_url_list()
        total = len(self._players_url_list)
        if total == 0:
            self.logger.warning("No player URLs to process.")
            return

        for idx, (player_url,) in enumerate(self._players_url_list, start=1):
            self.logger.info(f"Processing {player_url} ({idx}/{total})")
            self._parse_player(player_url)

    # --------------------------------------------------------------------- #
    # Single player parsing                                                 #
    # --------------------------------------------------------------------- #

    def _parse_player(self, url: str) -> None:
        """
        Fetch and parse a single player profile page.

        Extracted fields (in order):
          player_code, player_slug, first_name, last_name, player_url,
          flag_code, residence, birthplace, birthdate, turned_pro,
          weight_kg, height_cm, handedness, backhand
        """
        try:
            self.url = url
            html_content = self._request_url_by_chrome(self.url)
            if not html_content:
                self.logger.warning(f"Empty HTML for: {url}")
                return

            tree = html.fromstring(html_content)

            # --- Derive code/slug from URL path ---
            # Expected: /en/players/<slug>/<code>/overview
            parts = url.rstrip("/").split("/")
            player_code = parts[-2] if len(parts) >= 2 else "N/A"
            player_slug = parts[-3] if len(parts) >= 3 else "N/A"

            # --- Name parsing (robust to minor DOM changes) ---
            # Primary:
            name_nodes = tree.xpath("//div[@class='info']/div[@class='name']/span/text()")
            # Fallbacks could be added if needed
            if name_nodes:
                full_name = name_nodes[0].strip()
                # keep multi-token surnames
                tokens = full_name.split()
                first_name = tokens[0] if tokens else ""
                last_name = " ".join(tokens[1:]) if len(tokens) > 1 else ""
            else:
                first_name = last_name = ""

            # --- Defaults ---
            birthdate = ""
            weight_kg = ""
            height_cm = ""
            turned_pro = ""
            handedness = ""
            backhand = ""
            birthplace = ""
            flag_code = ""
            residence = ""  # not available on current pages, keep for schema

            # --- Personal details (left/right panes) ---
            left_items = tree.xpath("//div[@class='personal_details']//ul[contains(@class,'pd_left')]/li")
            right_items = tree.xpath("//div[@class='personal_details']//ul[contains(@class,'pd_right')]/li")

            # Precompiled regexes
            re_birth = re.compile(r"\((\d{4}/\d{2}/\d{2})\)")
            re_wkg = re.compile(r"\((\d+)\s*kg\)", re.I)
            re_hcm = re.compile(r"\((\d+)\s*cm\)", re.I)

            for li in left_items + right_items:
                label = li.xpath(".//span[1]/text()")
                value = li.xpath(".//span[2]//text()")
                if not label or not value:
                    continue

                label_text = (label[0] or "").strip()
                value_text = " ".join(v.strip() for v in value).strip()

                if label_text == "Age":
                    # Example: "19 (2005/11/03)"
                    m = re_birth.search(value_text)
                    birthdate = m.group(1) if m else ""
                elif label_text == "Weight":
                    m = re_wkg.search(value_text)
                    weight_kg = m.group(1) if m else ""
                elif label_text == "Height":
                    m = re_hcm.search(value_text)
                    height_cm = m.group(1) if m else ""
                elif label_text == "Turned pro":
                    turned_pro = value_text
                elif label_text == "Plays":
                    # e.g., "Right-Handed, Two-Handed Backhand"
                    parts = [p.strip() for p in value_text.split(",")]
                    handedness = parts[0] if parts else ""
                    backhand = parts[1] if len(parts) > 1 else ""
                elif label_text == "Birthplace":
                    birthplace = value_text
                elif label_text == "Country":
                    # Extract from flag use href (e.g., '#flag-ESP')
                    href = li.xpath(".//svg[contains(@class,'atp-flag')]/use/@href")
                    if href:
                        raw = href[0]
                        # take last token after '-' to get code
                        code = raw.split("-")[-1].upper()
                        # Normalize to your mapping (handles aliases/lc)
                        flag_code = self.remap_country_code(code)

            row = [
                player_code,
                player_slug,
                first_name,
                last_name,
                url,
                flag_code,
                residence,
                birthplace,
                birthdate,
                turned_pro,
                weight_kg,
                height_cm,
                handedness,
                backhand,
            ]
            self.data.append(row)

        except Exception as e:
            self.logger.error(f"parse_player error for URL {url}: {e}")
