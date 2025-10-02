# ATP Match Outcome Prediction — *A crown‑jewel dataset + a model that really delivers*

> **Tagline:** *End‑to‑end ETL + scalable feature engineering + calibrated XGBoost delivering state‑of‑the‑art tennis match win probabilities. Built for reproducibility. Designed for sports analytics.*

---

## ✨ What is this?

This repository brings together the **entire workflow** to predict ATP match outcomes from 1999 to today:
**scraping → parsing → ETL → feature engineering → year‑wise validation → calibration → hold‑out evaluation** and, most importantly, a **curated longitudinal dataset** that’s the project’s **crown jewel**.

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

## 🗂️ Repository structure (indicative)

```
ATP-Match-Outcome-Prediction/
├─ MODEL/
│  └─ model1.ipynb           # Training + year-wise CV + OOF + calibration + hold-out
├─ Scrapping/
│  ├─ rankings_fetch.py      # Playwright (headless) — saves HTML per date
│  └─ rankings_parse.py      # BeautifulSoup — produces per-date rankings CSV
├─ ETL/
│  ├─ rest_travel_proxies.R  # data.table/dplyr — feature engineering (both roles)
│  └─ helpers/               # utilities, country→continent maps, etc.
├─ data/                     # (suggested) intermediate inputs
├─ output/                   # (suggested) enriched datasets / predictions
└─ README.md                 # this document
```

---

## 🧪 Pipeline at a glance

```
flowchart LR
  A[ATP Rankings HTML] --> B[Parsing (BeautifulSoup)]
  B --> C[Per-date rankings CSV]
  C --> D[Integration with matches + pre-99 seeding]
  D --> E[Features: rest, travel, adaptation (dual role)]
  E --> F[Final dataset (crown jewel)]
  F --> G[XGBoost modeling]
  G --> H[Year-wise CV + OOF]
  H --> I[Isotonic calibration + cost threshold]
  I --> J[2023–2025 hold-out + reports]
```

### 1) Scraping & Parsing (Playwright + BeautifulSoup)

* **`rankings_fetch.py`** downloads **official ATP HTML** in **headless mode** and stores it as `.txt` (`rankings_YYYY-mm-dd.txt`).

  > Efficient by design: separating *HTML download* from *data scraping* lets you **reprocess locally** without hitting the origin (and makes the pipeline **finite**).
* **`rankings_parse.py`** extracts **ranking** and **player_code** per date (robust to locale and absolute/relative URLs).

> **Date format note**: `fechas.txt` contains values extracted from page HTML such as
> `<option value="2025-09-15">2025.09.15</option>`. The parser reads the `value="YYYY-mm-dd"` field.

### 2) ETL & Feature Engineering (R: `data.table` + `dplyr`)

* Sorting by `tournament_start_dtm`, `tournament_id`, phase and `match_order`.
* **Pre‑1999 seeding**: last seen date per player + last tournament, with round normalization **ER→R128** to align phases.
* **Role‑symmetric features** (`player_*` / `opponent_*`):

  * `*_days_since_prev_tournament`, `*_weeks_since_prev_tournament`
  * Flags: `*_back_to_back_week`, `*_two_weeks_gap`, `*_long_rest`
  * Changes: `*_country_changed`, `*_surface_changed`, `*_indoor_changed`, `*_continent_changed`
  * Composites: `*_red_eye_risk`, `*_travel_fatigue`
  * Prior load: `*_prev_tour_matches`, `*_prev_tour_max_round`
* Stable **country → continent** mapping (offline dictionary).

### 3) Modeling (Python, `MODEL/model1.ipynb`)

* **Preprocessing** via `ColumnTransformer`:

  * **One‑Hot** for categoricals (*sparse*) + safe imputation.
  * Numerics coerced to `float32`.
* **XGBoost** (`tree_method=hist`) with **early stopping** and fixed seed.
* **Year‑wise cross‑validation** (2000–2025) with `id` grouping.
* **OOF 2000–2022** for **isotonic calibration** (`IsotonicRegression`).
* **Hold‑out 2023–2025** in one batch transform + predict, with metrics by year and tournament type.
* **Cost‑optimal threshold**: tune `cost_fp`/`cost_fn` to your use‑case.

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

## 🚀 Quickstart

> Assumes **Python 3.10+**, **R 4.2+**, and isolated envs (conda/venv).

1. **Clone** the repo

```bash
git clone https://github.com/Aitor-Quint-04/ATP-Match-Outcome-Prediction.git
cd ATP-Match-Outcome-Prediction
```

2. **Install Python deps**

```bash
pip install -r requirements.txt
python -m playwright install firefox
```

3. **Download HTML (headless) & parse rankings**

```bash
python Scrapping/rankings_fetch.py     # saves /html/rankings_YYYY-mm-dd.txt
python Scrapping/rankings_parse.py     # writes per-date CSV into /rankings csv
```

4. **Run ETL/Features** (R)

* Open `ETL/rest_travel_proxies.R`, set input/output paths, and execute.
* Output: **enriched table** with all `player_*` / `opponent_*` features.

5. **Train & evaluate**

* Open `MODEL/model1.ipynb` and run all cells.
* You’ll get: **year‑wise CV**, **calibrated OOF** and **2023–2025 hold‑out**, plus breakdowns by tournament type.

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

Code under a standard open license (see `LICENSE`).
Please also review the terms that apply to any **source data** you use.

---

## 🎯 TL;DR

This project combines **robust ETL**, **context‑rich competitive features**, and a **calibrated XGBoost** with metrics that **generalize**.
The **dataset is the crown jewel**: deep, consistent and ready to power serious **sports analytics**—from research to production.
