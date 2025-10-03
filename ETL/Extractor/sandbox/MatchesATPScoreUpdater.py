# matches_atp_score_updater_extractor.py
from matches_base_extractor import MatchesBaseExtractor
import os


class MatchesATPScoreUpdaterExtractor(MatchesBaseExtractor):
    """
    Extractor that validates and (re)writes match scores into the staging table.

    Workflow:
      1) Pull the list of matches (for a given year) from VW_MATCHES.
      2) Normalize/validate the textual score into structured fields using _parse_score.
      3) Upsert (MERGE) the result into STG_MATCHES:
         - Update score-related fields if the row exists.
         - Insert a new row with score fields if it does not exist.
    """

    def __init__(self, year: int):
        """
        :param year: Target season to check/update scores for.
        """
        super().__init__()
        self.year: int = year
        self.url: str = ''  # Unused but kept for base API symmetry

    # --- Base lifecycle -------------------------------------------------------

    def _init(self) -> None:
        """
        Configure logging, staging target, SQL and post-process hooks.
        """
        os.makedirs("./logs", exist_ok=True)
        self.LOGFILE_NAME = f'./logs/{os.path.splitext(os.path.basename(__file__))[0]}.log'
        self.CSVFILE_NAME = ''  # No CSV dump for this updater
        self.TABLE_NAME = 'stg_matches'
        # Oracle MERGE to idempotently upsert only score-related columns.
        self.INSERT_STR = """
            MERGE INTO stg_matches tgt
            USING (
                SELECT
                    :1 AS id,
                    :2 AS score,
                    :3 AS match_ret,
                    :4 AS winner_sets_won,
                    :5 AS winner_games_won,
                    :6 AS winner_tiebreaks_won,
                    :7 AS loser_sets_won,
                    :8 AS loser_games_won,
                    :9 AS loser_tiebreaks_won
                FROM dual
            ) src
            ON (tgt.id = src.id)
            WHEN MATCHED THEN UPDATE SET
                tgt.score                 = src.score,
                tgt.match_ret             = src.match_ret,
                tgt.winner_sets_won       = src.winner_sets_won,
                tgt.winner_games_won      = src.winner_games_won,
                tgt.winner_tiebreaks_won  = src.winner_tiebreaks_won,
                tgt.loser_sets_won        = src.loser_sets_won,
                tgt.loser_games_won       = src.loser_games_won,
                tgt.loser_tiebreaks_won   = src.loser_tiebreaks_won
            WHEN NOT MATCHED THEN INSERT (
                id, score, match_ret,
                winner_sets_won, winner_games_won, winner_tiebreaks_won,
                loser_sets_won,  loser_games_won,  loser_tiebreaks_won
            ) VALUES (
                src.id, src.score, src.match_ret,
                src.winner_sets_won, src.winner_games_won, src.winner_tiebreaks_won,
                src.loser_sets_won,  src.loser_games_won,  src.loser_tiebreaks_won
            )
        """
        # No stored procedures needed after this MERGE
        self.PROCESS_PROC_NAMES = []
        super()._init()

    # --- Extraction steps -----------------------------------------------------

    def _parse(self) -> None:
        """
        Main extraction step:
          - Load candidate matches list.
          - Preload score adjustments dictionaries.
          - Validate/normalize each score and build the MERGE parameter rows.
        """
        self._fill_matches_list()
        self._fill_dic_match_scores_adj()  # Optional manual fixes/overrides

        for match_tpl in self._matches_list:
            self._check_match_score(match_tpl)

    def _fill_matches_list(self) -> None:
        """
        Fetches the list of matches to check/update for the configured season.
        Source: VW_MATCHES (excluding Davis Cup).
        """
        cur = None
        try:
            cur = self.con.cursor()
            sql = """
                SELECT id, tournament_code, score
                FROM vw_matches
                WHERE tournament_year = :year
                  AND series_id != 'dc'
                ORDER BY tournament_start_dtm, tournament_code, stadie_ord
            """
            self._matches_list = cur.execute(sql, {'year': self.year}).fetchall()
            self.logger.info(f'Checking {len(self._matches_list)} matches for year {self.year}')
        finally:
            if cur:
                cur.close()

    def _check_match_score(self, tpl: tuple) -> None:
        """
        Normalize and validate a single textual score, producing the MERGE payload.

        :param tpl: (match_id, tournament_code, score_text)
        """
        match_id, tournament_code, match_score = tpl

        try:
            # Apply manual adjustments if present
            if match_id in self._dic_match_scores_adj:
                match_score = self._dic_match_scores_adj[match_id]
                self.logger.warning(f'Adjustment applied for match_id={match_id}: score="{match_score}"')

            scores_arr = self._parse_score(match_score, match_id, tournament_code)
            if not scores_arr:
                self.logger.warning(
                    f"⚠️ match_id={match_id}: could not parse score '{match_score}'"
                )
                return

            # _parse_score returns:
            # [match_ret, win_sets, los_sets, win_games, los_games, win_tb, los_tb]
            # MERGE expects 9 binds in the exact order below.
            row = [match_id, match_score] + scores_arr
            self.data.append(row)

        except Exception as exc:
            self.logger.error(f"❌ match_id={match_id}: error parsing score '{match_score}': {exc}")
