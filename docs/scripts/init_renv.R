# scripts/init_renv.R
# Initialize a clean renv project and lock the requested packages

# --- optional but recommended: pin CRAN to a dated snapshot for reproducibility
# Use a recent date; adjust if you need exact historical versions.
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/2025-10-01"))

# Install renv if missing
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Initialize (or activate if already initialized)
if (!file.exists("renv.lock")) {
  renv::init(bare = TRUE)  # minimal project library
} else {
  renv::activate()
}

# Packages to lock
pkgs <- c(
  "data.table","dplyr","readr","stringr","lubridate",
  "tidyr","purrr","zoo","progress","roll"
)

# Install into the project library
install.packages(pkgs, dependencies = TRUE)

# Snapshot to create/update renv.lock (no interactive prompts)
renv::snapshot(prompt = FALSE)

cat("\nrenv setup complete ✅\n")
cat("Locked packages:\n")
print(pkgs)
cat("\nFiles generated/updated: renv.lock, renv/activate.R, renv/settings.json\n")
