#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==================================================================================================
# ATP Rankings — Offline HTML → CSV extractor (BeautifulSoup)
# --------------------------------------------------------------------------------------------------
# Overview
#   This script parses *previously downloaded* ATP rankings HTML snapshots (saved as plain .txt),
#   extracts (player_code, ranking) pairs for each date, and writes one CSV per date.
#
# Why offline?
#   Crawling and parsing are split on purpose: the scraping step stores full HTML for each date, and
#   this script parses those stable snapshots. This makes iteration on parsing logic fast and safe.
#
# Inputs
#   • fechas.txt — contains <option> lines from the ATP site; this parser reads dates strictly in
#                  ISO form (YYYY-MM-DD) via extraer_fechas(), and sorts them DESC (newest first).
#   • /home/aitor/Descargas/html/rankings_<YYYY-MM-DD>.txt — one HTML snapshot per date (text file).
#
# Extraction logic (per <tr class="lower-row"> = one ranking row)
#   • ranking:  the <td> with classes "rank" (and often "bold heavy tiny-cell", colspan="2").
#   • code:     the first <a> under <td class="player"> pointing to a /players/ URL; we accept
#               overview or rankings-breakdown (any locale), fall back to any /players/ link.
#               The player code is the 3-4 char segment after /players/<slug>/, e.g. y171.
#   • Duplicates are avoided: rows often include two links for the same player; first one wins.
#
# Outputs
#   • /home/aitor/Descargas/Project/Scrapping/Scrapping de Rankings/rankings csv/
#       rankings_<YYYY-MM-DD>.csv  with header: player_code, ranking
#
# Notes
#   • HTML structure on atptour.com may change; selectors include small fallbacks to be resilient.
#   • Non-existent snapshots are skipped with a message; the rest of the dates continue.
# ==================================================================================================

import os
import re
import csv
from urllib.parse import urlparse
from datetime import datetime
from bs4 import BeautifulSoup

# ---------------------------------- Configuration paths ----------------------------------
html_dir = "/home/aitor/Descargas/html"
fechas_file = "/home/aitor/Descargas/Project/Scrapping/Scrapping de Rankings/fechas.txt"
output_dir = "/home/aitor/Descargas/Project/Scrapping/Scrapping de Rankings/rankings csv"

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

# ==================================== Utilities ==========================================

def extraer_fechas(archivo):
    """
    Extract ISO dates (YYYY-MM-DD) from <option> lines in 'fechas.txt'.

    The scraping pipeline normalizes dates when saving HTML. This parser is intentionally strict
    and only accepts ISO-formatted value attributes (value="YYYY-MM-DD"). Any other lines are ignored.

    Returns
    -------
    list[str]
        Dates as strings, in the order they appear in the file (deduplicated later).
    """
    fechas = []
    with open(archivo, 'r', encoding='utf-8') as f:
        for linea in f:
            # Capture the "value" attribute if it matches strict ISO yyyy-mm-dd
            m = re.search(r'value="(\d{4}-\d{2}-\d{2})"', linea)
            if m:
                fechas.append(m.group(1))
    print(f"✅ Se han cargado {len(fechas)} fechas.")
    return fechas


def extraer_codigo_desde_url(href: str) -> str | None:
    """
    Extract the ATP player code from a /players/ URL.

    Expected URL shapes (absolute or relative, any locale prefix):
      - /en/players/<slug>/<code>/overview
      - /es/players/<slug>/<code>/rankings
      - https://www.atptour.com/<locale>/players/<slug>/<code>/...

    We primarily grab the third segment after 'players': players/<slug>/<code>/...
    If that fails, we fall back to a regex for a single letter + 3/4 digits (e.g., 'y171').

    Parameters
    ----------
    href : str
        Anchor href attribute, absolute or relative.

    Returns
    -------
    str | None
        Player code string, or None if not recognized.
    """
    if not href:
        return None

    # Normalize to a path component (strip scheme/host if absolute)
    path = urlparse(href).path if href.startswith(("http://", "https://")) else href
    parts = [p for p in path.split('/') if p]
    low = [p.lower() for p in parts]

    # Primary: position relative to 'players'
    try:
        i = low.index('players')
    except ValueError:
        # Not a /players/ link
        return None

    # players/<slug>/<code>/...
    if len(parts) > i + 2:
        return parts[i + 2]

    # Fallback: robust regex search anywhere in the path
    m = re.search(r"/players/[^/]+/([a-z]\d{3,4})(?:/|$)", path, re.IGNORECASE)
    return m.group(1) if m else None


# ================================ Read & sort dates =======================================
# Deduplicate while preserving file order (dict.fromkeys trick), then sort by date DESC
fechas = list(dict.fromkeys(extraer_fechas(fechas_file)))
fechas.sort(key=lambda s: datetime.strptime(s, "%Y-%m-%d"), reverse=True)

# ================================ Process each date ======================================
for fecha in fechas:
    # The scraper saves snapshots as plain text files
    input_path = os.path.join(html_dir, f"rankings_{fecha}.txt")
    output_path = os.path.join(output_dir, f"rankings_{fecha}.csv")

    if not os.path.exists(input_path):
        # Missing snapshot: warn and continue with the next date
        print(f"Archivo no encontrado: {input_path}")
        continue

    # Parse HTML with BeautifulSoup; ignore decoding errors just in case
    with open(input_path, 'r', encoding='utf-8', errors='ignore') as file:
        soup = BeautifulSoup(file, 'html.parser')

    # Use a dict to avoid duplicates: first occurrence wins
    jugadores: dict[str, int] = {}

    # Each real ranking row uses <tr class="lower-row">
    filas = soup.select('tr.lower-row')
    for fila in filas:
        # ------- RANK extraction -------
        # Preferred: td.rank.bold.heavy.tiny-cell[colspan="2"]
        celda_rank = fila.select_one('td.rank.bold.heavy.tiny-cell[colspan="2"]')
        if not celda_rank:
            # Fallbacks to be tolerant with class changes:
            #   a) td.rank.tiny-cell
            #   b) any <td> whose class list contains 'rank'
            celda_rank = (
                fila.select_one('td.rank.tiny-cell')
                or fila.find('td', class_=lambda c: c and 'rank' in c.split())
            )
        if not celda_rank:
            # No rank cell found in this row; skip
            continue

        ranking_text = celda_rank.get_text(strip=True)
        # Extract only digits (e.g., "1", " 12 ", "#34")
        try:
            ranking = int(re.sub(r"[^0-9]", "", ranking_text))
        except ValueError:
            # Non-integer or unexpected content; skip row
            continue

        # ------- PLAYER CODE extraction -------
        celda_player = fila.select_one('td.player')
        if not celda_player:
            continue

        enlace = None
        # Prefer overview; fallback to rankings-breakdown; finally any /players/
        for sel in ["a[href*='/overview']", "a[href*='/rankings-breakdown']", "a[href*='/players/']"]:
            enlace = celda_player.select_one(sel)
            if enlace:
                break
        if not enlace:
            continue

        url = enlace.get('href', '')
        codigo = extraer_codigo_desde_url(url)
        if not codigo:
            # The link is not parsable as a players URL
            continue

        # Avoid duplicates: keep the first rank encountered for a player
        if codigo not in jugadores:
            jugadores[codigo] = ranking

    # ------------------------------ Write CSV ------------------------------
    # CSV sorted by rank ascending; header included
    with open(output_path, 'w', encoding='utf-8', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["player_code", "ranking"])
        for codigo, rk in sorted(jugadores.items(), key=lambda kv: kv[1]):
            writer.writerow([codigo, rk])

    print(f"Fecha {fecha}: {len(jugadores)} jugadores procesados -> {output_path}")

print("Proceso completado!")
