import os
import gc
import csv
import time
import psutil
import requests
import cx_Oracle
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
import undetected_chromedriver as uc

from constants import (
    CONNECTION_STRING, INDOOR_OUTDOOR_MAP, SURFACE_MAP, COUNTRY_NAME_MAP,
    COUNTRY_CODE_MAP, STADIE_CODES_MAP, PLAYERS_ATP_URL_MAP, CITY_COUNTRY_MAP,
    WEBDRIVER_PHANTOMJS_EXECUTABLE_PATH
)
from logger.logger import Logger


class BaseExtractor:
    """
    Base class for web data extraction, transformation, and loading (ETL) into Oracle DB.
    Handles:
      - Web scraping (Selenium/PhantomJS/requests)
      - Data preprocessing and mapping utilities
      - Database connection, truncation, insertion, and stored procedure execution
      - Logging and error handling
    """

    def __init__(self):
        # General properties
        self.url = ""
        self.data = []
        self.response_str = ""
        self.TABLE_NAME = ""
        self.INSERT_STR = ""
        self.PROCESS_PROC_NAMES = []
        self.LOGFILE_NAME = ""
        self.CSVFILE_NAME = ""
        self.MODULE_NAME = ""

        # WebDriver state
        self._driver = None
        self._driver_use_count = 0
        self._max_driver_uses = 50  # Restart driver every N uses

        # Init logger and DB
        self._init()

    def _init(self):
        """Initialize logger and database connection."""
        self.logger = Logger(self.LOGFILE_NAME, self.MODULE_NAME)
        self._connect_to_db()

    # -------------------------------------------------------------------------
    # -------------------------- STATIC HELPERS -------------------------------
    # -------------------------------------------------------------------------

    @staticmethod
    def get_script_name():
        """Return the current script filename."""
        return os.path.basename(__file__)

    @staticmethod
    def remap_indoor_outdoor_name(short_name: str) -> str:
        """Remap indoor/outdoor short name to full form."""
        return INDOOR_OUTDOOR_MAP.get(short_name)

    @staticmethod
    def remap_surface_name(short_name: str) -> str:
        """Remap surface short name to full form."""
        return SURFACE_MAP.get(short_name)

    @staticmethod
    def remap_stadie_code(round_name: str) -> str:
        """Remap tournament round to standardized stadie code."""
        return STADIE_CODES_MAP.get(round_name)

    @staticmethod
    def remap_country_name(country_name: str) -> str:
        """Remap country name if available in dictionary."""
        return COUNTRY_NAME_MAP.get(country_name, country_name)

    @staticmethod
    def remap_country_name_by_location(location: str, country_name: str) -> str:
        """Remap country based on city location if available."""
        return CITY_COUNTRY_MAP.get(location, country_name)

    @staticmethod
    def remap_country_code(country_code: str) -> str:
        """Remap country code if available in dictionary."""
        return COUNTRY_CODE_MAP.get(country_code, country_code)

    @staticmethod
    def remap_player_atp_url(player_url: str) -> str:
        """Remap player ATP URL if available in dictionary."""
        return PLAYERS_ATP_URL_MAP.get(player_url, player_url)

    @staticmethod
    def normalize_date_str(date: str) -> str:
        """
        Normalize a date string like "18 February 1995" into "18.02.1995".
        Raises ValueError if the month is not recognized.
        """
        if not date:
            return ""

        months = {
            'January': '01', 'February': '02', 'March': '03', 'April': '04',
            'May': '05', 'June': '06', 'July': '07', 'August': '08',
            'September': '09', 'October': '10', 'November': '11', 'December': '12'
        }

        date_arr = date.split(" ")
        try:
            date_arr[1] = months[date_arr[1]]
            return " ".join(date_arr)
        except Exception:
            raise ValueError("Not a valid month string")

    @staticmethod
    def parse_tournament_dates(dates: str) -> (str, str):
        """
        Parse tournament dates in the format 'DD Month YYYY - DD Month YYYY'.
        Returns (start_date, finish_date) in format dd.mm.yyyy.
        """
        if not dates:
            return "", ""

        dates_arr = dates.replace(",", "").split("-")
        dates_arr = [i.strip() for i in dates_arr]

        start_date_arr = dates_arr[0].split(" ")
        finish_date_arr = dates_arr[1].split(" ")

        finish_date = BaseLoader.normalize_date_str(dates_arr[1]).replace(" ", ".")

        n = len(start_date_arr)
        if n == 1:
            start_date = BaseLoader.normalize_date_str(
                " ".join([start_date_arr[0], finish_date_arr[1], finish_date_arr[2]])
            ).replace(" ", ".")
        elif n == 2:
            start_date = BaseLoader.normalize_date_str(
                " ".join([start_date_arr[0], start_date_arr[1], finish_date_arr[2]])
            ).replace(" ", ".")
        elif n == 3:
            start_date = BaseLoader.normalize_date_str(dates_arr[1]).replace(" ", ".")
        else:
            start_date = None

        return start_date, finish_date

    # -------------------------------------------------------------------------
    # --------------------------- WEBDRIVER -----------------------------------
    # -------------------------------------------------------------------------

    def _init_driver(self):
        """Initialize a fresh undetected Chrome driver with optimized settings."""
        # Kill stale Chrome processes
        chrome_killed = 0
        for proc in psutil.process_iter(["name"]):
            try:
                if proc.info["name"] and "chrome" in proc.info["name"].lower():
                    proc.kill()
                    chrome_killed += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

        self.logger.info(f"🧹 Killed {chrome_killed} Chrome processes before driver restart.")

        options = uc.ChromeOptions()
        options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument("--disable-extensions")
        options.add_argument("--mute-audio")
        options.add_argument("--window-size=800,600")
        options.add_argument("--incognito")
        options.page_load_strategy = "eager"
        options.add_argument(
            "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        )

        # Disable unnecessary resources
        prefs = {
            "profile.managed_default_content_settings.images": 2,
            "profile.managed_default_content_settings.stylesheets": 2,
            "profile.managed_default_content_settings.cookies": 2,
            "profile.managed_default_content_settings.plugins": 2,
            "profile.managed_default_content_settings.popups": 2,
            "profile.managed_default_content_settings.geolocation": 2,
            "profile.managed_default_content_settings.media_stream": 2,
        }
        options.add_experimental_option("prefs", prefs)

        self._driver = uc.Chrome(options=options)
        self._driver.set_page_load_timeout(15)
        self._driver_use_count = 0
        self.logger.info("✅ New Chrome driver initialized.")

    def _request_url_by_chrome(self, url: str, timeout: int = 5, max_retries: int = 3) -> str:
        """
        Request a URL using Chrome driver, with retry logic and Cloudflare detection.
        Returns HTML content or None if blocked/fails.
        """
        if not url:
            url = self.url
            self.logger.info(f"Input URL is empty, using default self.url = {self.url}")

        attempt = 0
        while attempt < max_retries:
            try:
                # Restart driver if needed
                if (
                    not hasattr(self, "_driver")
                    or self._driver is None
                    or self._driver_use_count >= self._max_driver_uses
                ):
                    if getattr(self, "_driver", None):
                        try:
                            self._driver.quit()
                        except Exception:
                            pass
                        self._driver = None
                        gc.collect()
                        time.sleep(0.5)
                    self._init_driver()

                self.logger.info(f"🌐 [Attempt {attempt + 1}] Accessing: {url}")
                self._driver.get(url)

                WebDriverWait(self._driver, 1.5, poll_frequency=0.05).until(
                    lambda d: d.execute_script("return document.readyState") == "complete"
                )

                content = self._driver.page_source
                self._driver_use_count += 1

                if "cf-chl" in content or "Verifique que usted es un ser humano" in content:
                    self.logger.warning(f"⚠ Cloudflare blocked access to {url}.")
                    return None

                return content

            except Exception as e:
                self.logger.error(f"❌ Error in attempt {attempt + 1} accessing {url}: {str(e)}")
                attempt += 1
                time.sleep(1.2)

        self.logger.error(f"❌ Failed after {max_retries} attempts for {url}")
        return None

    # -------------------------------------------------------------------------
    # --------------------------- DATABASE ------------------------------------
    # -------------------------------------------------------------------------

    def _connect_to_db(self):
        """Establish a new Oracle DB connection."""
        self.con = cx_Oracle.connect(CONNECTION_STRING, encoding="UTF-8")
        self.logger.info("(Re)connected to DB.")

    def _truncate_table(self):
        """Truncate target table before loading new data."""
        try:
            self._connect_to_db()
            cur = self.con.cursor()
            if self.TABLE_NAME:
                cur.execute(f"TRUNCATE TABLE {self.TABLE_NAME}")
        finally:
            cur.close()

    def _store_in_csv(self):
        """Store extracted data in a CSV file."""
        if self.CSVFILE_NAME:
            with open(self.CSVFILE_NAME, "w", encoding="utf-8", newline="") as csv_file:
                writer = csv.writer(csv_file)
                writer.writerows(self.data)

    def _process_data(self):
        """Call stored procedures defined in PROCESS_PROC_NAMES list."""
        try:
            self._connect_to_db()
            cur = self.con.cursor()
            for proc in self.PROCESS_PROC_NAMES:
                self.logger.info(f"Calling procedure {proc}")
                cur.callproc(proc)
        finally:
            cur.close()

    def _load_to_stg(self):
        """Insert data into staging table using INSERT_STR template."""
        try:
            self._connect_to_db()
            cur = self.con.cursor()
            if self.INSERT_STR:
                cur.executemany(self.INSERT_STR, self.data)
                self.con.commit()
                self.logger.info(f"{len(self.data)} row(s) inserted.")
        finally:
            cur.close()

    # -------------------------------------------------------------------------
    # ------------------------- ABSTRACT METHODS ------------------------------
    # -------------------------------------------------------------------------

    def _parse(self):
        """Parse response string into self.data (to be implemented in subclass)."""
        raise NotImplementedError

    def _post_process_data(self):
        """Post-processing hook (optional in subclasses)."""
        pass

    def _pre_process_data(self):
        """Pre-processing hook (optional in subclasses)."""
        pass

    # -------------------------------------------------------------------------
    # ----------------------------- MAIN FLOW ---------------------------------
    # -------------------------------------------------------------------------

    def extract(self):
        """
        Main ETL process:
          1. Request URL
          2. Parse response
          3. Truncate target table
          4. Store data to CSV
          5. Load data to staging
          6. Pre-process, call procs, post-process
          7. Handle logs and errors
        """
        try:
            self._request_url_by_chrome(self.url)
            self._parse()
            self._truncate_table()
            self._store_in_csv()
            self._load_to_stg()
            self._pre_process_data()
            self._process_data()
            self._post_process_data()
            self.logger.finish_batch_successfully()
        except Exception as e:
            self.logger.error(f"Error: {str(e)}")
            self.logger.finish_batch_with_errors()
        finally:
            self.con.close()
