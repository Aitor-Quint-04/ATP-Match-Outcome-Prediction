from typing import Dict, Optional, List, Tuple
from base_extractor import baseExtractor  

class MatchesBaseExtractor(baseExtractor):
    """
    Base utilities for match-related extraction and score parsing.

    This class extends `baseExtractor` with:
      - On-demand loading of score adjustments from DB (set scores, stats URL, skip flags).
      - Helpers to normalize/interpret match scores and match retirement codes.
      - A robust parser for per-set score strings that aggregates match-level stats.
    """

    # ------------------------------ Lifecycle --------------------------------

    def _init(self) -> None:
        """Initialize subclass state and then call base initialization."""
        self._dic_match_scores_adj: Dict[str, str] = {}
        self._dic_match_scores_stats_url_adj: Dict[str, str] = {}
        self._dic_match_scores_skip_adj: Dict[str, str] = {}
        super()._init()

    # ------------------------------ DB helpers -------------------------------

    def _fetch_adjustments(self, column: str, target: Dict[str, str]) -> None:
        """
        Generic helper to populate a dictionary from `match_scores_adjustments`.

        Args:
            column: Column name to fetch (e.g., 'set_score', 'stats_url', 'to_skip').
            target: Dict to fill with key=match_id, value=column.
        """
        cur = None
        try:
            cur = self.con.cursor()
            sql = f"SELECT match_id, {column} FROM match_scores_adjustments WHERE {column} IS NOT NULL"
            for match_id, value in cur.execute(sql).fetchall():
                target[str(match_id)] = str(value)
        finally:
            if cur:
                cur.close()

    def _fill_dic_match_scores_adj(self) -> None:
        """Load manual set-score adjustments into `_dic_match_scores_adj`."""
        self._fetch_adjustments("set_score", self._dic_match_scores_adj)

    def _fill_dic_match_scores_stats_url_adj(self) -> None:
        """Load manual stats-url adjustments into `_dic_match_scores_stats_url_adj`."""
        self._fetch_adjustments("stats_url", self._dic_match_scores_stats_url_adj)

    def _fill_dic_match_scores_skip_adj(self) -> None:
        """Load skip flags into `_dic_match_scores_skip_adj`."""
        self._fetch_adjustments("to_skip", self._dic_match_scores_skip_adj)

    # ------------------------------ Score parsing ----------------------------

    def parse_score(
        self,
        match_score: str,
        match_id: str,
        tournament_code: str
    ) -> List[Optional[int]]:
        """
        Parse a raw match score string into aggregate stats.

        Supports:
          - Regular sets (e.g., '64', '76(5)' as '765'/'76[5]' variants).
          - NextGen tie formats (first-to-4, e.g., '43', '34', with/without detail).
          - Super tiebreaks / match tiebreaks (e.g., '10[8]', '108', '810', etc.).
          - Unfinished/ret/walkover cases via `get_match_ret()`.

        Args:
            match_score: Raw score string (e.g., '64 36 76[7]', 'W/O', 'RET', etc.).
            match_id: Match identifier (for logging context).
            tournament_code: Code to disambiguate special formats (e.g., NextGen '7696').

        Returns:
            [match_ret, winner_sets_won, loser_sets_won,
             winner_games_won, loser_games_won,
             winner_tiebreaks_won, loser_tiebreaks_won]
            where `match_ret` is a string like '(RET)', '(W/O)', '(WEA)' or None.
        """
        try:
            # Initialize aggregates
            winner_sets_won = loser_sets_won = 0
            winner_games_won = loser_games_won = 0
            winner_tiebreaks_won = loser_tiebreaks_won = 0

            match_ret = self.get_match_ret(match_score)

            # If retired/walkover/etc., we do not parse sets
            if match_ret is not None:
                return [
                    match_ret, None, None, None, None, None, None
                ]

            # Split score by spaces into set chunks
            match_score_array = match_score.split()

            for set_score in match_score_array:
                # Tie-set shorthand like '10[8]' → normalize if needed
                if '[' in set_score or ']' in set_score:
                    # keep for special handling, also accept already normalized variants
                    pass

                # --- Laver Cup tie-set (e.g., '[10-8]' variants) ---
                if '[' in set_score:
                    # count as 1 set for the winner and 1 "game" for winner (as in original logic)
                    winner_sets_won += 1
                    winner_games_won += 1
                    # Log special cases
                    if tournament_code == '9210':
                        self.logger.info(
                            f"(tie set) Laver Cup; match_id={match_id}; set_score={set_score}; all={match_score_array}"
                        )
                    else:
                        self.logger.warning(
                            f"(tie set) non-Laver; match_id={match_id}; set_score={set_score}; all={match_score_array}"
                        )
                    # Tiebreaks count as won by winner
                    winner_tiebreaks_won += 1
                    continue

                # --- Regular 2-char sets like '64', '75', '76', '06' ---
                if len(set_score) == 2:
                    pair = set_score[:2]
                    # Whitelisted quick checks (GS big scores, NextGen special, etc.)
                    if (tournament_code == '7696') and pair in ('40', '41', '42', '04', '14', '24'):
                        self.logger.info(
                            f"(small score) NextGen; match_id={match_id}; set={set_score}; all={match_score_array}"
                        )
                    elif pair in ('86', '97', '68', '79') and tournament_code in ['580', '560', '540', '520']:
                        self.logger.info(
                            f"(big score) Grand Slam; match_id={match_id}; set={set_score}; all={match_score_array}"
                        )
                    elif pair in ('86', '97', '68', '79') and tournament_code in ['96']:
                        self.logger.warning(
                            f"(big score) Olympic; match_id={match_id}; set={set_score}; all={match_score_array}"
                        )
                    elif pair not in ('60', '61', '62', '63', '64', '75', '76', '06', '16', '26', '36', '46', '57', '67'):
                        self.logger.error(f"score not in white list; match_id={match_id}; set={set_score}")

                    # Decide winner/loser for the set
                    if set_score[0] > set_score[1]:
                        winner_sets_won += 1
                        winner_games_won += int(set_score[0])
                        loser_games_won += int(set_score[1])
                        if pair == '76':
                            winner_tiebreaks_won += 1
                        elif pair == '43' and tournament_code == '7696':
                            winner_tiebreaks_won += 1
                        elif int(set_score[0]) - int(set_score[1]) < 2:
                            self.logger.error(f"(win) margin <2; match_id={match_id}; set={set_score}")
                    elif set_score[0] < set_score[1]:
                        loser_sets_won += 1
                        winner_games_won += int(set_score[0])
                        loser_games_won += int(set_score[1])
                        if pair == '67':
                            loser_tiebreaks_won += 1
                        elif pair == '34' and tournament_code == '7696':
                            loser_tiebreaks_won += 1
                        elif int(set_score[1]) - int(set_score[0]) < 2:
                            self.logger.error(f"(los) margin <2; match_id={match_id}; set={set_score}")
                    else:
                        self.logger.error(f"len==2 but equal digits; match_id={match_id}; set={set_score}")

                # --- 3-char forms for super tiebreaks like '108', '810', etc. ---
                elif len(set_score) == 3:
                    if set_score in ('810', '911'):  # loser won 1st part
                        loser_sets_won += 1
                        loser_games_won += int(set_score[0:2]) if set_score == '911' else 10
                        winner_games_won += int(set_score[-1])
                    elif set_score in ('108', '106', '107', '119'):
                        winner_sets_won += 1
                        # handle 3-char digits explicitly
                        if set_score == '108':
                            winner_games_won += 10; loser_games_won += 8
                        elif set_score == '106':
                            winner_games_won += 10; loser_games_won += 6
                        elif set_score == '107':
                            winner_games_won += 10; loser_games_won += 7
                        elif set_score == '119':
                            winner_games_won += 11; loser_games_won += 9
                    else:
                        self.logger.error(f"len==3 unrecognized; match_id={match_id}; set={set_score}")

                # --- 4-char sets like '2218' (very long sets) ---
                elif len(set_score) == 4:
                    # Heuristic warnings outside GS
                    if tournament_code not in ['580', '560', '540', '520'] or set_score > '2200':
                        self.logger.warning(
                            f"(huge score) match_id={match_id}; set={set_score}; all={match_score_array}"
                        )
                    left, right = set_score[:2], set_score[2:]
                    if left > right:
                        winner_sets_won += 1
                        winner_games_won += int(left)
                        loser_games_won += int(right)
                        if int(left) - int(right) < 2:
                            self.logger.error(f"(win) margin <2; match_id={match_id}; set={set_score}")
                    elif right > left:
                        loser_sets_won += 1
                        winner_games_won += int(left)
                        loser_games_won += int(right)
                        if int(right) - int(left) < 2:
                            self.logger.error(f"(los) margin <2; match_id={match_id}; set={set_score}")
                    else:
                        self.logger.error(
                            f"len==4 but tie; match_id={match_id}; left={left}; right={right}; set={set_score}"
                        )

                # --- 7+ chars, detailed tiebreaks like '76[12-10]' flattened as '761210' ---
                elif len(set_score) >= 7:
                    left, right = set_score[:2], set_score[2:4]
                    if left > right:
                        winner_sets_won += 1
                        winner_games_won += int(left)
                        loser_games_won += int(right)
                        winner_tiebreaks_won += 1
                    elif left < right:
                        loser_sets_won += 1
                        winner_games_won += int(left)
                        loser_games_won += int(right)
                        loser_tiebreaks_won += 1
                    else:
                        self.logger.error(
                            f"len>=7 but tie; match_id={match_id}; LHS={left}; RHS={right}; set={set_score}"
                        )

                else:
                    self.logger.error(f"Unhandled set format; match_id={match_id}; set={set_score}")

            # Basic sanity on final set count (common ATP outcomes)
            allowed = {'30', '31', '32', '21', '20'}
            if f"{winner_sets_won}{loser_sets_won}" not in allowed:
                self.logger.error(
                    f"(unexpected match score) score={winner_sets_won}{loser_sets_won} "
                    f"match_id={match_id}; sets={match_score_array}"
                )

            return [
                match_ret,
                winner_sets_won, loser_sets_won,
                winner_games_won, loser_games_won,
                winner_tiebreaks_won, loser_tiebreaks_won
            ]

        except Exception as e:
            self.logger.error(f"match_id={match_id}; parse_score error: {e}")
            return [None, None, None, None, None, None, None]

    def adjust_score(self, match_id: str, score: str) -> str:
        """
        Apply manual override for a given match score if present in adjustments.

        Args:
            match_id: Match identifier.
            score: Raw scraped score.

        Returns:
            Adjusted score if found; otherwise the original `score`.
        """
        if match_id in self._dic_match_scores_adj:
            adj = self._dic_match_scores_adj[match_id]
            self.logger.warning(f"Adjustment applied for match_id={match_id}; score={adj}")
            return adj
        return score

    @staticmethod
    def get_match_ret(match_score: str) -> Optional[str]:
        """
        Detect retirement/walkover/weather flags from a raw score string.

        Returns:
            '(W/O)', '(RET)', '(WEA)' or None if the score looks like a played match.
        """
        s = (match_score or "").strip()
        if not s:
            return None

        up = s.upper()
        if "W/O" in up or "INV" in up or "WALKOVER" in up:
            return "(W/O)"
        if "WEA" in up:
            return "(WEA)"
        if "RE" in up or "RET" in up or "DEF" in up or "UNP" in up:
            return "(RET)"
        if "PLAYED AND UNFINISHED" in up or "PLAYED AND ABANDONED" in up or "UNFINISHED" in up:
            return "(RET)"
        return None

    def normalize_tie_set_score(self, tie_set_score: str) -> str:
        """
        Normalize tie-set strings to a consistent '10[xx]'-style shape when given in bracket-first form.

        Example:
            Input:  '[11-9]'  →  '10[11-9]' (after minimal normalization)
            NOTE: Keep consistent with your upstream/downstream score conventions.
        """
        self.logger.info(f"normalize_tie_set_score IN: {tie_set_score}")
        if not tie_set_score:
            return tie_set_score

        # Example normalization pass for formats that start with '['
        if tie_set_score[0] == '[':
            # strip brackets/dashes, then prefix '10[' ... ']'
            tmp = tie_set_score.replace('-', '').replace('[', '').replace(']', '')
            # Keep only the last two digits if needed, or adapt to your pipeline
            tail = tmp[2:] if len(tmp) > 2 else tmp
            tie_set_score = f"10[{tail}]"

        self.logger.info(f"normalize_tie_set_score OUT: {tie_set_score}")
        return tie_set_score
