const BASE = 'https://image.tmdb.org/t/p';

export function posterUrl(path: string | undefined | null, size: 'w185' | 'w342' | 'w500' = 'w342'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

export function backdropUrl(path: string | undefined | null, size: 'w780' | 'w1280' | 'original' = 'w1280'): string | null {
  return path ? `${BASE}/${size}${path}` : null;
}

export function displayTitle(item: { title?: string | null; name?: string | null }): string {
  return item.title || item.name || '';
}

export function displayYear(item: { release_date?: string | null; first_air_date?: string | null }): string {
  const date = item.release_date || item.first_air_date;
  return date ? date.slice(0, 4) : '';
}
