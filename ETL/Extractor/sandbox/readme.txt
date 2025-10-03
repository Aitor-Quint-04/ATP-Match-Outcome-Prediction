This code makes a specialized extractor that, for a given season (year), loads ATP matches (excluding Davis Cup), normalizes/validates the raw textual score via _parse_score,
and prepares structured score metrics (sets/games/tiebreaks, RET/W.O. flags).
It then performs an idempotent Oracle MERGE into stg_matches, updating existing rows or inserting new ones with the parsed score fields, with optional manual score adjustments applied per match.

It is not relevant for this project, since its main function it's update the match score from a tennis match that's going on. However, the user is free to include this module in the Extractor.
