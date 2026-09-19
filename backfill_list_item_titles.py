#!/usr/bin/env python3
"""
One-shot : remplit le champ Title des MediaListItems et UserMedia existants
(ajoutés avant l'introduction de la colonne) en interrogeant TMDB.

Usage :
    python3 backfill_list_item_titles.py [--dry-run] [--limit N]

Nécessite pymysql et requests (voir le venv créé pour ce script).
"""

import argparse
import time
import sys

import pymysql
import requests

DB_HOST = "REDACTED_INTERNAL_IP"
DB_PORT = 3306
DB_NAME = "tracker"
DB_USER = "root"
DB_PASSWORD = "REDACTED"

TMDB_API_KEY = "REDACTED_TMDB_API_KEY"
TMDB_BASE_URL = "https://api.themoviedb.org/3"
TMDB_LANGUAGE = "fr-FR"

# MediaType enum côté backend (Models/UserMedia.cs) : 0 = Movie, 1 = Show
MEDIA_TYPE_MOVIE = 0
MEDIA_TYPE_TV = 1

TABLES = ["MediaListItems", "UserMedia"]


def fetch_title(tmdb_id: int, media_type: int) -> str | None:
    path = "movie" if media_type == MEDIA_TYPE_MOVIE else "tv"
    url = f"{TMDB_BASE_URL}/{path}/{tmdb_id}"
    try:
        resp = requests.get(
            url,
            params={"api_key": TMDB_API_KEY, "language": TMDB_LANGUAGE},
            timeout=10,
        )
    except requests.RequestException as exc:
        print(f"  ! erreur réseau pour {path}/{tmdb_id} : {exc}", file=sys.stderr)
        return None

    if resp.status_code != 200:
        print(f"  ! TMDB a répondu {resp.status_code} pour {path}/{tmdb_id}", file=sys.stderr)
        return None

    data = resp.json()
    title = data.get("title") if media_type == MEDIA_TYPE_MOVIE else data.get("name")
    return title.strip() if title else None


def missing_pairs(conn, table: str) -> set[tuple[int, int]]:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT DISTINCT TmdbId, MediaType
            FROM {table}
            WHERE Title IS NULL OR Title = ''
            """
        )
        return set(cur.fetchall())


def apply_title(conn, table: str, tmdb_id: int, media_type: int, title: str, dry_run: bool) -> None:
    if dry_run:
        return
    with conn.cursor() as cur:
        cur.execute(
            f"""
            UPDATE {table}
            SET Title = %s
            WHERE TmdbId = %s AND MediaType = %s AND (Title IS NULL OR Title = '')
            """,
            (title, tmdb_id, media_type),
        )
    conn.commit()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="N'écrit rien en base, affiche seulement ce qui serait fait.")
    parser.add_argument("--limit", type=int, default=None, help="Limite le nombre de médias distincts traités.")
    args = parser.parse_args()

    conn = pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        charset="utf8mb4",
    )

    try:
        per_table_pairs = {table: missing_pairs(conn, table) for table in TABLES}
        all_pairs = sorted(set().union(*per_table_pairs.values()), key=lambda p: (p[1], p[0]))

        if args.limit is not None:
            all_pairs = all_pairs[: args.limit]

        print(f"{len(all_pairs)} médias distincts sans titre à résoudre (tous tableaux confondus).")

        resolved = 0
        missed = 0

        for tmdb_id, media_type in all_pairs:
            title = fetch_title(tmdb_id, media_type)
            time.sleep(0.08)

            if not title:
                missed += 1
                print(f"  ? introuvable sur TMDB : mediaType={media_type} tmdbId={tmdb_id}")
                continue

            resolved += 1
            label = "movie" if media_type == MEDIA_TYPE_MOVIE else "tv"
            touched = [t for t in TABLES if (tmdb_id, media_type) in per_table_pairs[t]]
            print(f"  ok {label}/{tmdb_id} -> {title!r} ({', '.join(touched)})")

            for table in touched:
                apply_title(conn, table, tmdb_id, media_type, title, args.dry_run)

        print(f"\nTerminé. Résolus: {resolved}. Introuvables: {missed}. Dry run: {args.dry_run}.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
