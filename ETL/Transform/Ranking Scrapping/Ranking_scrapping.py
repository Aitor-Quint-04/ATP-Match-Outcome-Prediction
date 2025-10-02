# ==================================================================================================
# ATP Rankings — HTML Snapshot Scraper (Playwright, HEADLESS ENFORCED) + normalization of mixed dates
# --------------------------------------------------------------------------------------------------
# Why this design?
#   • Faster & safer: for a finite universe of weekly rankings it’s far more efficient to *persist
#     the raw HTML once per date* (one .txt per week) and do all parsing in a separate, offline
#     script. This avoids repeated network calls while you iterate on parsing logic.
#
# Input dates (from the ATP page’s HTML)
#   The local `fechas.txt` contains <option> lines extracted from the site and may mix separators:
#       <option value="2025.09-22">2025.09.22</option>
#       <option value="2025-09-15">2025.09.15</option>
#       <option value="2025-09-08">2025.09.08</option>
#       <option value="2025-08-25">2025.08.25</option>
#       <option value="2025-08-18">2025.08.18</option>
#       <option value="2025-08-04">2025.08.04</option>
#       <option value="2025-07-28">2025.07.28</option>
#   We normalize every date to ISO YYYY-MM-DD before building the URL.
#
# What this script does
#   1) Read & normalize all dates from fechas.txt.
#   2) Launch a **headless** Firefox (Playwright) — headless is not optional here.
#   3) Block heavy resources (images, fonts, CSS) to speed up loads.
#   4) Save full DOM HTML to /home/aitor/Descargas/html/rankings_<YYYY-MM-DD>.txt (one per date).
#
# Robustness
#   • Random short waits to let dynamic content settle.
#   • Two consecutive timeouts abort the run (likely network or throttling).
# ==================================================================================================

import re
import time
import random
import subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
from playwright._impl._errors import TimeoutError as PlaywrightTimeoutError

# ------------------------------------
# Configuration
# ------------------------------------
HTML_DIR = Path("/home/aitor/Descargas/html")
HTML_DIR.mkdir(parents=True, exist_ok=True)

ARCHIVO_FECHAS = "fechas.txt"


# ------------------------------------
# Utilities
# ------------------------------------
def _normalize_date_token(token: str) -> str | None:
    """
    Normalize date tokens that might use '.' or '-' (or a mix) as separators.
    Accepts patterns like '2025.09-22', '2025-09-15', '2025.09.08'.
    Returns canonical 'YYYY-MM-DD' or None if it can’t parse.
    """
    m = re.search(r'(\d{4})[.\-](\d{2})[.\-](\d{2})', token)
    if not m:
        return None
    yyyy, mm, dd = m.group(1), m.group(2), m.group(3)
    return f"{yyyy}-{mm}-{dd}"


def extraer_fechas(archivo: str) -> list[str]:
    """
    Extract and normalize all value="YYYY[-|.]MM[-|.]DD" tokens from 'fechas.txt'.
    Deduplicates while preserving order.
    """
    fechas: list[str] = []
    seen = set()
    with open(archivo, "r", encoding="utf-8") as f:
        for linea in f:
            v = re.search(r'value="([^"]+)"', linea)
            if not v:
                continue
            canonical = _normalize_date_token(v.group(1))
            if canonical and canonical not in seen:
                fechas.append(canonical)
                seen.add(canonical)
    print(f"✅ Se han cargado {len(fechas)} fechas válidas (normalizadas a YYYY-MM-DD).")
    return fechas


def matar_procesos_firefox() -> None:
    """
    Best-effort kill of stray Firefox processes before a new launch (helps if prior runs hung).
    """
    print("🔪 Matando procesos activos de Firefox...")
    try:
        subprocess.run(["pkill", "-f", "firefox"], check=False)
        time.sleep(2)
        print("✅ Procesos de Firefox eliminados.")
    except Exception as e:
        print(f"⚠️ Error al matar procesos de Firefox: {e}")


def guardar_html(page, fecha: str) -> None:
    """
    Persist full page HTML to a text file for later offline parsing.
    """
    try:
        content = page.content()
        destino = HTML_DIR / f"rankings_{fecha}.txt"
        with open(destino, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"💾 Guardado: {destino}")
    except Exception as e:
        print(f"❌ Error guardando HTML: {e}")


# ------------------------------------
# Main
# ------------------------------------
def main() -> None:
    fechas = extraer_fechas(ARCHIVO_FECHAS)
    if not fechas:
        print("⚠️ No se encontraron fechas parseables en el archivo. Abortando.")
        return

    consecutive_timeouts = 0

    with sync_playwright() as p:
        for fecha in fechas:
            matar_procesos_firefox()

            url = f"https://www.atptour.com/es/rankings/singles?rankRange=1-5000&dateWeek={fecha}"
            print(f"\n🌍 Abriendo navegador para fecha: {fecha}")
            print(f"🔗 URL: {url}")

            # Headless is ENFORCED (no toggle)
            browser = p.firefox.launch(headless=True, timeout=60000)
            context = browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/114.0.0.0 Safari/537.36"
                ),
                viewport={"width": 1280, "height": 800},
                java_script_enabled=True,
            )

            # Block heavy resources to accelerate loads
            context.route(
                "**/*",
                lambda route, request: (
                    route.abort()
                    if request.resource_type in {"image", "font", "stylesheet"}
                    else route.continue_()
                ),
            )

            page = context.new_page()

            try:
                page.goto(url, wait_until="domcontentloaded", timeout=90000)
                consecutive_timeouts = 0
            except PlaywrightTimeoutError:
                consecutive_timeouts += 1
                print(f"⏳ Timeout en {fecha} ({consecutive_timeouts} consecutivo/s).")
                try:
                    context.close()
                    browser.close()
                except Exception:
                    pass
                if consecutive_timeouts >= 2:
                    print("🚫 Dos timeouts seguidos. Deteniendo ejecución.")
                    break
                else:
                    continue
            except Exception as e:
                print(f"❌ Error navegando a {fecha}: {e}")
                try:
                    context.close()
                    browser.close()
                except Exception:
                    pass
                continue

            # Gentle wait to reduce flakiness on dynamic content
            wait_time = random.uniform(1.0, 2.5)
            print(f"⏳ Esperando {wait_time:.1f}s para estabilizar el DOM...")
            time.sleep(wait_time)

            guardar_html(page, fecha)

            # Cleanly close context & browser per iteration
            try:
                context.close()
            finally:
                browser.close()
            print(f"🛑 Navegador cerrado para fecha: {fecha}")

    print("\n🏁 Proceso completado.")


if __name__ == "__main__":
    main()
