const BASE = 'https://image.tmdb.org/t/p';

export function posterUrl(path: string | undefined | null, size: 'w185' | 'w342' | 'w500' | 'original' = 'w342'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

export function backdropUrl(path: string | undefined | null, size: 'w780' | 'w1280' | 'original' = 'w1280'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

/** Image d'illustration d'un épisode (« still » TMDB). */
export function stillUrl(path: string | undefined | null, size: 'w300' | 'w780' = 'w300'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

export function profileUrl(path: string | undefined | null, size: 'w185' | 'w342' = 'w185'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

/** Année (AAAA) d'une date ISO, ou chaîne vide. */
export function yearOf(date?: string | null): string {
  return date ? date.slice(0, 4) : '';
}

export function displayTitle(item: { title?: string | null; name?: string | null }): string {
  return item.title || item.name || '';
}

export function displayYear(item: { release_date?: string | null; first_air_date?: string | null }): string {
  return yearOf(item.release_date || item.first_air_date);
}
