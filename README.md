# ATP Match Outcome Prediction — *A crown‑jewel dataset + a model that really delivers*

> **Tagline:** *End‑to‑end ETL + scalable feature engineering + calibrated XGBoost delivering state‑of‑the‑art tennis match win probabilities. Built for reproducibility. Designed for sports analytics.*

---

## ✨ What is this?

This repository brings together the **entire workflow** to predict ATP match outcomes from 1999 to today:
**scraping → parsing → SQL staging → ETL/feature engineering → year‑wise validation → calibration → hold‑out evaluation** and, most importantly, a **curated longitudinal dataset** that’s the project’s **crown jewel**.

You get two deliverables:

1. **A rich, long‑horizon dataset** (the *jewel*): 1999–2025 coverage, with **real competitive context** features (rest, travel, adaptation to surface & indoor, prior load) for **both players**.
2. **A calibrated XGBoost model** that outputs realistic win probabilities and strong out‑of‑sample metrics.

If you work in **sports analytics**, **quantitative sports trading**, **scouting**, or **ML R&D for sports**, this repo offers **production‑grade building blocks** backed by **high‑quality data**.

---

## 🔑 Why this project stands out

* **Serious, reproducible ETL.** Temporal ordering is enforced, leakage is avoided, and the unit of analysis (match–player) is consistent across time.
* **Unique “fatigue & adaptation” features** (for both player roles):

  * Days/weeks since previous tournament.
  * Discrete signals: *back‑to‑back*, *two‑weeks gap*, *long rest*.
  * Country / continent / surface / indoor–outdoor changes.
  * **Red‑eye risk** (intercontinental + consecutive week).
  * **Travel fatigue score** (composite).
* **Cold‑start pre‑1999** with historical seed (Jeff Sackmann): last seen date & tournament prior to 1999, and round normalization (**ER→R128**) for phase alignment.
* **Validation that mirrors reality**:

  * **Year‑wise cross‑validation (2000–2025)** with an **`id` guarantee** (both rows of a match stay together).
  * **OOF (2000–2022)** to train a **calibrated probability** model via isotonic regression.
  * **Hold‑out 2023–2025**, also broken down by tournament type.
* **Calibrated probabilities** + **cost‑optimal thresholding** for decision‑ready outputs.

---

## 🏆 Results (executive summary)

> Figures come from the notebook with embedded outputs (`MODEL/model1.ipynb`) and are indicative for this data snapshot and setup.

* **Year‑wise CV 2000–2025** (26 folds, `id` leakage‑safe):
  **AUC ≈ 0.964 | LogLoss ≈ 0.224 | Brier ≈ 0.072 | Accuracy ≈ 0.89**
* **OOF 2000–2022** (for isotonic calibration):
  **AUC ≈ 0.972 | LogLoss ≈ 0.210 | Brier ≈ 0.068**
* **Hold‑out 2023–2025** (calibrated probabilities):
  **AUC ≈ 0.915 | LogLoss ≈ 0.379 | Brier ≈ 0.120 | Accuracy ≈ 0.821**

**Bottom line:** the system **generalizes** and the **probabilities are calibrated**—a must for risk‑aware decisioning.

---

## 🗂️ Repository structure (actual file names)

```
ATP-Match-Outcome-Prediction/
├─ Data_Example/
│  └─ sample.csv                      # Tiny sample for quick inspection
│
├─ ETL/
│  ├─ Extractor/
│  │  ├─ MatchesATPExtractor.py
│  │  ├─ MatchesBaseExtractor.py
│  │  ├─ PlayersATPExtractor.py
│  │  ├─ StatsATPExtractor.py
│  │  ├─ TournamentsATPExtractor.py
│  │  ├─ base_extractor.py
|  |  ├─ constants.py
│  │  └─ runner.py
│  │
│  ├─ Load/
│  │  └─ CreateData.R                 # R loader/assembler
│  │
│  └─ SQL/
│     ├─ Procedures&Functions/        # Stored procs & UDFs (sf_* / sp_*)
│     ├─ Tables/
│     │  └─ Staging/
|     |  |     ├─ stg_match_scores.sql
|     |  |     ├─ stg_match_stats.sql
|     |  |     ├─ stg_matches.sql
|     |  |     ├─ stg_players.sql
|     |  |     ├─ stg_teams.sql
|     |  |     └─ stg_tournaments.sql
│     │  ├─ atp_matches.sql
│     │  ├─ atp_matches_enriched.sql
│     │  ├─ atp_players.sql
│     │  ├─ atp_tournaments.sql
│     │  ├─ countries.sql
│     │  ├─ indoor_outdoor.sql
│     │  ├─ match_scores_adjustments.sql
│     │  ├─ player_points.sql
│     │  ├─ points_rulebook.sql
│     │  ├─ points_rules.sql
│     │  ├─ series.sql
│     │  ├─ series_category.sql
│     │  ├─ stadies.sql            # (kept as‑is)
│     │  └─ surfaces.sql
│     └─ views/
│        ├─ vw_atp_matches.sql
│        └─ vw_player_stats.sql
│
├─ Transform/
│  ├─ Ranking Scrapping/
│  │  ├─ Ranking_scrapping.py         # Headless HTML fetch from atptour.com
│  │  ├─ rankings_to_csv.py           # BeautifulSoup → per‑date rankings CSV
│  │  ├─ DataTransform1.R
│  │  ├─ DataTransform2.R
│  │  ├─ DataTransform3.R
│  │  ├─ DataTransform4.R
│  │  ├─ DataTransform5_1.R
│  │  ├─ DataTransform6.R
│  │  ├─ DataTransform6_1.R
│  │  ├─ DataTransform7.R
│  │  ├─ DataTransform8.R
│  │  ├─ DataTransform9.R
│  │  ├─ DataTransform10.R
│  │  ├─ DataTransform11.R
│  │  ├─ DataTransform12.R
│  │  ├─ readme.txt
│  └─ transform_info.txt
│  │
│  └─ (other feature scripts live here)
│
├─ MODEL/
│  └─ model1.ipynb                    # CV by year, OOF calibration, hold‑out 2023–2025
│
├─ LICENSE
└─ README.md                          # You are here
```

> **Note on dates file**: the rankings fetcher uses `fechas.txt` populated directly from ATP HTML. Example lines present in that file (as found in source pages):
> `<option value="2025-09-22">2025.09.22</option>`
> `<option value="2025-09-15">2025.09.15</option>`
> …the **`value`** field is parsed as `YYYY-mm-dd`.

---

## 🧪 Pipeline at a glance

```
  A[Ranking_scrapping.py (headless)] --> B[raw HTML (.txt per date)]
  B --> C[rankings_to_csv.py (BeautifulSoup)]
  C --> D[SQL Staging (Tables/ Staging/)]
  D --> E[Procedures & Functions (sf_*/sp_*)]
  E --> F[Views (vw_atp_matches, vw_player_stats)]

  %% Python ETL extractors run AFTER SQL creation (all run by runner.py)
  F --> X1[ETL/Extractor/TournamentsATPExtractor.py]
  X1 --> X2[ETL/Extractor/PlayersATPExtractor.py]
  X2 --> X3[ETL/Extractor/MatchesATPExtractor.py]
  X3 --> X4[ETL/Extractor/StatsATPExtractor.py]

  X4 --> G[CreateData.R & DataTransform*.R]
  G --> H[Final enriched dataset]
  H --> I[MODEL/model1.ipynb — XGBoost]
  I --> J[CV by year + OOF calibration + hold‑out]
```

### 1) Scraping & Parsing

**A. Core HTML Extractors (Python)**
Located in `ETL/Extractor/`, these modules perform the **primary data extraction from ATP web pages (HTML scraping)** and normalize outputs for staging:

* `ETL/Extractor/base_extractor.py` & `ETL/Extractor/constants.py` — shared session, headers, retries/backoff, helpers, and constants (URLs, paths, regexes). Designed for polite scraping.
* `ETL/Extractor/MatchesATPExtractor.py` — crawls & parses match pages/feeds and prepares match-level records.
* `ETL/Extractor/PlayersATPExtractor.py` — extracts player pages (bio/handedness/backhand, country, etc.).
* `ETL/Extractor/TournamentsATPExtractor.py` — pulls tournament metadata (location, surface, category, indoor/outdoor).
* `ETL/Extractor/StatsATPExtractor.py` — scrapes stats blocks where available and aligns them to match IDs/players.

> **Notes:** Extractors follow a "fetch → parse (BeautifulSoup) → normalize" pattern. Raw HTML/JSON can be cached locally to make runs reproducible and to minimize load on the origin.

**B. Rankings Scrapers (headless) + Parser**

* `Transform/Ranking Scrapping/Ranking_scrapping.py` — downloads **official ATP rankings HTML** in **headless mode** and stores full HTML as text (`rankings_YYYY-mm-dd.txt`).
  *This design is deliberate:* saving raw HTML first makes the pipeline **finite and reproducible**; you can re‑parse locally without revisiting the site.
* `Transform/Ranking Scrapping/rankings_to_csv.py` — parses those files and extracts **`ranking`** and **`player_code`** per date (robust to absolute/relative URLs and locale prefixes like `/es/`, `/en/`).

---

### 2) SQL Staging & Business Logic

* **Tables** under `ETL/SQL/Tables/Staging/` define the staging schema: `atp_matches.sql`, `atp_matches_enriched.sql`, `atp_players.sql`, `atp_tournaments.sql`, `points_rulebook.sql`, `surfaces.sql`, etc.
* **Procedures & functions** under `ETL/SQL/Procedures&Functions/` (files beginning with `sf_` / `sp_`) implement:

  * Delta and hash logic for incremental loads (`*_delta_hash.sql`).
  * Player points rules application & enrichment (`sp_apply_points_rules.sql`, `sp_calculate_player_points.sql`, `sp_enrich_atp_matches.sql`).
  * Merge/processing orchestration for matches, players, tournaments (e.g., `sp_merge_atp_players.sql`, `sp_process_atp_matches.sql`).
* **Views** in `ETL/SQL/views/` expose analytics‑ready joins: `vw_atp_matches.sql`, `vw_player_stats.sql`.

---

### 3) ETL / Feature Engineering (R)

* `ETL/Load/CreateData.R` and the series of `Transform/Ranking Scrapping/DataTransform*.R` scripts stitch everything into a **match–player** panel.
* Feature highlights (mirrored for `player_*` and `opponent_*`):

  * **Rest & load:** `*_days_since_prev_tournament`, `*_weeks_since_prev_tournament`, `*_prev_tour_matches`.
  * **Adaptation flags:** `*_country_changed`, `*_continent_changed`, `*_surface_changed`, `*_indoor_changed`.
  * **Fatigue proxies:** `*_back_to_back_week`, `*_two_weeks_gap`, `*_long_rest`, `*_red_eye_risk`, `*_travel_fatigue`.

---

### 4) Modeling (Python, Jupyter)

* `MODEL/model1.ipynb` implements:

  * `ColumnTransformer` (sparse **One‑Hot** for categoricals, numeric coercion to `float32`).
  * **XGBoost** (`tree_method=hist`) with early stopping.
  * **CV by year (2000–2025)** with **`id` grouping** (both rows of a match stay together).
  * **OOF 2000–2022** for **isotonic calibration**.
  * **Hold‑out 2023–2025** with breakdowns by tournament type and a **cost‑optimal threshold** utility.

---

## 💎 The dataset (the crown jewel)

* **Coverage**: 1999–2025 (with pre‑1999 seeds where applicable).
* **Unit**: **match–player** rows (two rows per match), with mirrored `player_*` / `opponent_*` context for match‑up modeling.
* **Key examples**:

  * `player_days_since_prev_tournament`, `opponent_days_since_prev_tournament`
  * `player_red_eye_risk`, `opponent_red_eye_risk`
  * `player_travel_fatigue`, `opponent_travel_fatigue`
  * `player_prev_tour_matches`, `player_prev_tour_max_round` (and mirrored opponent features)
  * Context: `surface`, `indoor_outdoor`, `best_of`, `tournament_country`, `tournament_category`, ranking trends, home flags, etc.
* **Ready for ML/BI**: clean column types, temporal safety, long‑term consistency.

---

# 🚀 Quickstart

> Assumes **Python 3.10+**, **R 4.2+**, and isolated envs (conda/venv).

---

## 1) Clone

```bash
git clone https://github.com/Aitor-Quint-04/ATP-Match-Outcome-Prediction.git
cd ATP-Match-Outcome-Prediction
```

## 2) Install Python deps 

```bash
python -m pip install -U pandas numpy scipy scikit-learn xgboost beautifulsoup4 lxml selenium
# Optional: easy driver management
python -m pip install -U webdriver-manager
```

## 3) Fetch rankings HTML & parse

```bash
python "Transform/Ranking Scrapping/Ranking_scrapping.py"
python "Transform/Ranking Scrapping/rankings_to_csv.py"
```

## 4) Create staging & run SQL logic

Load the scripts in this order:

1. `ETL/SQL/Tables/Staging/` (tables)
2. `ETL/SQL/Procedures&Functions/` (procedures/functions)
3. `ETL/SQL/views/` (views)

## 5) Run Python ETL extractors (in order)

> Run from the repo root so relative imports/config resolve correctly.

```bash

# 0) Run dependencies
python "ETL/Extractor/base_extractor.py"
python "ETL/Extractor/constants.py"
python "ETL/Extractor/MatchesBaseExtractor.py"

# 1) Tournaments
python "ETL/Extractor/TournamentsATPExtractor.py"

# 2) Players
python "ETL/Extractor/PlayersATPExtractor.py"

# 3) Matches
python "ETL/Extractor/MatchesATPExtractor.py"

# 4) Stats
python "ETL/Extractor/StatsATPExtractor.py"

# 5) Run the extractor (check the code)
pyton "ETL/Extractor/runner.py"

```

## 6) Assemble features (R)

```r
# In R
source("ETL/Load/CreateData.R")
# or run the DataTransform*.R scripts inside Transform/Ranking Scrapping/
```

### 6‑bis) Full R transformation pipeline (step‑by‑step)

All transformation scripts live in **`Transform/Ranking Scrapping/`** and are designed to run **sequentially**. They progressively build the final **match–player panel** (two rows per match) with mirrored `player_*` / `opponent_*` context.

> Required packages (typical): `data.table`, `dplyr`, `readr`, `stringr`, `lubridate`, `tidyr`, `purrr`. Install as needed.

**Script responsibilities (by file):**

**(read the codes doc)**

1. **`DataTransform1.R`** – Base normalization

   * Coerce types, standardize column names, parse `tournament_start_dtm`, rounds and match order.
   * Normalize keys and fix minor inconsistencies.
  
     **...**

2. **`DataTransform3.R`** – Geography & context

   * Country → continent mapping; indoor/outdoor normalization.
   * Surface harmonization (clay/hard/grass); stadium metadata if required.

     **...**

3. **`DataTransform5.R`** – Rankings join

   * Merge per‑date rankings (from scraping) into matches by player and date.
   * Create ranking trend features (e.g., 4w/12w deltas if available).
  
     **...**

15. **`DataTransformFINAL.R`** 

    * Write the long‑horizon enriched dataset (e.g., `database_99-25_1.csv`).
    * Bayesian Smooth
    * Correlation analysis

> Notes
>
> * `ETL/Load/CreateData.R` can orchestrate or prepare inputs.
> * Intermediate artifacts (if any) are written under your configured output directory.

### One‑shot runner for all R transforms

Use this snippet to execute the transforms **in the right order** (explicitly lists `5_1` and `6_1` to avoid alphanumeric sorting issues):

```r
# ---- packages (install if needed) ----
req <- c("data.table","dplyr","readr","stringr","lubridate","tidyr","purrr","zoo","progress","roll")
new <- setdiff(req, rownames(installed.packages()))
if (length(new)) install.packages(new)
invisible(lapply(req, library, character.only = TRUE))

# ---- paths ----
ROOT <- getwd()  # run from repo root
SCRIPTS <- file.path

order <- c(
  "Transform/Ranking Scrapping/DataTransform1.R",
  "Transform/Ranking Scrapping/DataTransform2.R",
  "Transform/Ranking Scrapping/DataTransform3.R",
  "Transform/Ranking Scrapping/DataTransform4.R",
  "Transform/Ranking Scrapping/DataTransform5.R",
  "Transform/Ranking Scrapping/DataTransform5_1.R",
  "Transform/Ranking Scrapping/DataTransform6.R",
  "Transform/Ranking Scrapping/DataTransform6_1.R",
  "Transform/Ranking Scrapping/DataTransform7.R",
  "Transform/Ranking Scrapping/DataTransform8.R",
  "Transform/Ranking Scrapping/DataTransform9.R",
  "Transform/Ranking Scrapping/DataTransform10.R",
  "Transform/Ranking Scrapping/DataTransform11.R",
  "Transform/Ranking Scrapping/DataTransform12.R"
)

for (s in order) {
  cat(sprintf("\n>>> Running: %s\n", s))
  source(s, echo = TRUE, max.deparse.length = Inf)
}

cat("\nAll transforms finished. Check the exported dataset (e.g., database_99-25_1.csv).\n")
```

---

## 7) Model

Open **`MODEL/model1.ipynb`** and run all cells to reproduce: **CV by year**, **OOF calibration**, and **hold‑out 2023–2025**.

> A tiny sample lives in `Data_Example/sample.csv` for quick sanity checks.

---

## 🧰 Practical tips

* **Separate download & parsing**: save HTML once, parse many times—faster and kinder to the origin.
* **Avoid leakage**: never fit the preprocessor on validation folds; the notebook uses per‑fold clones.
* **Use the cost‑optimal threshold**: when decisions carry asymmetric costs, tune `cost_fp`/`cost_fn` and deploy `thr*`.

---

## ⚠️ Data & ethics

* **Scraping** must follow the source site’s **Terms of Use**, **robots.txt**, and reasonable rate limits.
* This repo is for **research/educational** purposes. You’re responsible for compliance and downstream use.
* **Not betting advice.** If you operate in betting contexts, understand legal constraints, risk management, and calibration needs.

---

## 🗺️ Roadmap

* [ ] Export the **final dataset** in partitioned Parquet with a full **data dictionary**.
* [ ] Minimal **feature store** (ETL versioning + artifact registry).
* [ ] Additional baselines (Logistic, CatBoost, LightGBM) + **ensembles**.
* [ ] Drift monitoring by season and tournament type.
* [ ] Lightweight API for serving **calibrated probabilities** in real time.

---

## 🤝 Contributing

Ideas, PRs and issues are very welcome! If you propose new features, please **motivate the sports mechanism** you’re capturing and include **out‑of‑sample evidence**.

---

## 📄 License

Code under a permissive open license (see `LICENSE`).
Please also review the terms that apply to any **source data** you use.

---

## 🎯 TL;DR

This project combines **robust ETL**, **context‑rich competitive features**, and a **calibrated XGBoost** with metrics that **generalize**.
The **dataset is the crown jewel**: deep, consistent and ready to power serious **sports analytics**—from research to production.
