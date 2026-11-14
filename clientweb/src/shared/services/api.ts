import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpResponse } from '@angular/common/http';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { MediaItem, TmdbGenre, UserState } from '../interfaces/media';
import { MediaListSummary, PaginatedResult, MediaListItem } from '../interfaces/list';
import { Stats, StatsListGenres } from '../interfaces/stats';
import { EpisodeSeenDto } from '../interfaces/episode';
import { Activity } from '../interfaces/activity';
import { WatchEvent } from '../interfaces/watch-event';

const API = '/api';

export interface AddListItemPayload {
  tmdbId: number;
  mediaType: string;
  posterPath?: string | null;
  title?: string | null;
  genres?: TmdbGenre[] | null;
}

export interface AddToWatchlistPayload {
  posterPath?: string | null;
  runtime?: number | null;
  title?: string | null;
  genres?: TmdbGenre[] | null;
}

export interface MarkSeenPayload {
  seen: boolean;
  posterPath?: string | null;
  runtime?: number | null;
  title?: string | null;
  genres?: TmdbGenre[] | null;
}

export interface AddWatchPayload {
  watchedAt: string;
  posterPath?: string | null;
  runtime?: number | null;
  title?: string | null;
  genres?: TmdbGenre[] | null;
}

export interface MarkSeasonSeenPayload {
  seen: boolean;
  episodeNumbers: number[];
}

export interface MarkShowSeenPayload {
  seen: boolean;
  posterPath?: string | null;
  title?: string | null;
  genres?: TmdbGenre[] | null;
  seasons: { seasonNumber: number; episodeNumbers: number[] }[];
}

export interface Settings {
  ntfyEnabled: boolean;
  ntfyUrl?: string | null;
  ntfyTopic?: string | null;
  ntfyToken?: string | null;
  notifyDaysAhead: number;
  notificationHour: number;
  notificationMinute: number;
  torrentsEnabled: boolean;
  prowlarrUrl?: string | null;
  prowlarrApiKey?: string | null;
  allDebridApiKey?: string | null;
  tmdbApiKey?: string | null;
  tmdbBaseUrl?: string | null;
  tmdbLanguage?: string | null;
  updatedAt: string;
  iosLocalNotificationsEnabled?: boolean | null;
}

export type WebSettingsUpdate = Omit<Settings, 'updatedAt' | 'iosLocalNotificationsEnabled'>;

export interface BackupImportResult {
  exportedAt: string;
  counts: Record<string, number>;
}

export interface Indexer {
  id: number;
  name: string;
}

export interface TorrentCategory {
  id: number;
  name: string;
}

export interface TorrentResult {
  title: string;
  size: number;
  seeders: number;
  leechers: number;
  indexer: string;
  magnetUrl: string;
  category: string | null;
  publishDate: string | null;
}

export interface TorrentBookmark extends TorrentResult {
  id: number;
  addedAt: string;
}

export interface DebridFile {
  filename: string;
  size: number;
  link: string;
}

export interface DebridResult {
  files: DebridFile[];
}

export interface UnlockResult {
  directLink: string;
}

// ── Séances de cinéma (Allociné) ─────────────────────────────────────────
export interface Showtime {
  id: string;
  iso: string;
  date: string;
  time: string;         // "09:45"
  version: string | null; // "VO" / "VF"
  formats: string[];    // IMAX, DOLBY_CINEMA, PLF, 3D...
  isPreview: boolean;
  ticketingUrl: string | null;
}

export interface ShowtimeMovie {
  id: number | null;
  title: string;
  poster: string | null;
  runtime: string | null; // déjà formaté, ex. "2h 53min"
  genres: string[];
  url: string | null;
  shows: Showtime[];
}

export interface Theater {
  code: string;
  name: string | null;
  address: string | null;
  postalCode: string | null;
  city: string | null;
  image: string | null;
}

export interface TheaterShowtimes {
  theater: Theater;
  date: string;
  nextDate: string | null;
  movies: ShowtimeMovie[];
}

export interface FavoriteTheater {
  id: number;
  code: string;
  isActive: boolean; // coché : ses séances sont affichées (état mémorisé)
  position: number;
}

export interface TrackedMedia {
  id: number;
  tmdbId: number;
  mediaType: 'movie' | 'tv';
  title: string;
  posterPath?: string | null;
  addedAt: string;
}

export interface TrackedMediaState {
  tmdbId: number;
  mediaType: 'movie' | 'tv';
  tracked: boolean;
}

export interface InProgressShow {
  showTmdbId: number;
  posterPath?: string | null;
  seenEpisodeCount: number;
  lastSeasonNumber: number;
  lastEpisodeNumber: number;
  lastWatchedAt: string;
}

export interface CalendarInfo {
  webcalUrl: string;
  httpsUrl: string;
}

export interface AddTrackedMediaPayload {
  tmdbId: number;
  mediaType: 'movie' | 'tv';
  title: string;
  posterPath?: string | null;
}

export interface SystemLog {
  id: number;
  createdAt: string;
  level: 'Trace' | 'Debug' | 'Information' | 'Warning' | 'Error' | 'Critical' | string;
  category: string;
  message: string;
  exception?: string | null;
  eventId: number;
  traceId?: string | null;
  method?: string | null;
  path?: string | null;
  statusCode?: number | null;
  elapsedMs?: number | null;
}

@Injectable({ providedIn: 'root' })
export class Api {
  private http = inject(HttpClient);

  // ── User states ──────────────────────────────────────────────────────────

  states(tmdbIds: number[], type: 'movie' | 'tv'): Observable<UserState[]> {
    const ids = [...new Set(tmdbIds)].filter(id => Number.isInteger(id) && id > 0 && id <= 2147483647);
    if (!ids.length) return of([]);

    // Les filmographies peuvent dépasser la taille maximale d'une URL HTTP.
    const batches: Observable<UserState[]>[] = [];
    for (let start = 0; start < ids.length; start += 100) {
      batches.push(this.http.get<UserState[]>(`${API}/Media/states`, {
        params: { tmdbIds: ids.slice(start, start + 100).join(','), type }
      }));
    }
    return forkJoin(batches).pipe(map(results => results.flat()));
  }

  /**
   * Charge en une fois les états utilisateur (vu / aimé / listes) des films et séries
   * donnés, indexés par type et tmdbId (les deux catalogues partagent des IDs).
   * Une erreur réseau conserve le chargement des métadonnées sans état personnel.
   */
  statesByTmdbId(items: Pick<MediaItem, 'id' | 'media_type'>[]): Observable<Map<string, UserState>> {
    const movieIds = items.filter(i => i.media_type === 'movie').map(i => i.id);
    const showIds = items.filter(i => i.media_type === 'tv').map(i => i.id);

    const movieStates$ = movieIds.length ? this.states(movieIds, 'movie').pipe(catchError(() => of([]))) : of([]);
    const showStates$ = showIds.length ? this.states(showIds, 'tv').pipe(catchError(() => of([]))) : of([]);

    return forkJoin([movieStates$, showStates$]).pipe(
      map(([movieStates, showStates]) => new Map([
        ...movieStates.map(s => [mediaStateKey({ id: s.tmdbId, media_type: 'movie' }), s] as const),
        ...showStates.map(s => [mediaStateKey({ id: s.tmdbId, media_type: 'tv' }), s] as const),
      ]))
    );
  }

  markSeen(tmdbId: number, type: 'movie' | 'tv', payload: MarkSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Media/${tmdbId}/seen`, { ...payload, genres: payload.genres ?? [] }, { params: { type } });
  }

  getWatches(tmdbId: number, type: 'movie' | 'tv'): Observable<WatchEvent[]> {
    return this.http.get<WatchEvent[]>(`${API}/Media/${tmdbId}/watches`, { params: { type } })
      .pipe(map(events => events.map(normalizeWatchDate)));
  }

  addWatch(tmdbId: number, type: 'movie' | 'tv', payload: AddWatchPayload): Observable<WatchEvent> {
    return this.http.post<WatchEvent>(`${API}/Media/${tmdbId}/watches`, { ...payload, genres: payload.genres ?? [] }, { params: { type } })
      .pipe(map(normalizeWatchDate));
  }

  deleteWatch(tmdbId: number, type: 'movie' | 'tv', watchId: number): Observable<unknown> {
    return this.http.delete(`${API}/Media/${tmdbId}/watches/${watchId}`, { params: { type } });
  }

  markLiked(tmdbId: number, type: 'movie' | 'tv', liked: boolean, title?: string | null, posterPath?: string | null): Observable<unknown> {
    const params: Record<string, string> = { type };
    if (title) params['title'] = title;
    if (posterPath) params['posterPath'] = posterPath;
    return this.http.post(`${API}/Media/${tmdbId}/liked`, liked, {
      headers: { 'Content-Type': 'application/json' },
      params
    });
  }

  addToWatchlist(tmdbId: number, type: 'movie' | 'tv', payload: AddToWatchlistPayload = {}): Observable<unknown> {
    return this.http.post(`${API}/Media/${tmdbId}/watchlist`, { ...payload, genres: payload.genres ?? [] }, { params: { type } });
  }

  removeFromWatchlist(tmdbId: number, type: 'movie' | 'tv'): Observable<unknown> {
    return this.http.delete(`${API}/Media/${tmdbId}/watchlist`, { params: { type } });
  }

  // ── Episodes ─────────────────────────────────────────────────────────────

  showEpisodes(showTmdbId: number): Observable<EpisodeSeenDto[]> {
    return this.http.get<EpisodeSeenDto[]>(`${API}/Shows/${showTmdbId}/episodes`);
  }

  markShowSeen(showTmdbId: number, payload: MarkShowSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seen`, { ...payload, genres: payload.genres ?? [] });
  }

  markSeasonSeen(showTmdbId: number, seasonNumber: number, payload: MarkSeasonSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/seen`, payload);
  }

  /** Séries « en cours » : au moins un épisode vu, série non terminée. */
  inProgressShows(): Observable<InProgressShow[]> {
    return this.http.get<InProgressShow[]>(`${API}/Shows/in-progress`);
  }

  markEpisodeSeen(showTmdbId: number, seasonNumber: number, episodeNumber: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/episodes/${episodeNumber}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  getEpisodeWatches(showTmdbId: number, seasonNumber: number, episodeNumber: number): Observable<WatchEvent[]> {
    return this.http.get<WatchEvent[]>(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/episodes/${episodeNumber}/watches`)
      .pipe(map(events => events.map(normalizeWatchDate)));
  }

  addEpisodeWatch(showTmdbId: number, seasonNumber: number, episodeNumber: number, watchedAt: string): Observable<WatchEvent> {
    return this.http.post<WatchEvent>(
      `${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/episodes/${episodeNumber}/watches`, { watchedAt })
      .pipe(map(normalizeWatchDate));
  }

  deleteEpisodeWatch(showTmdbId: number, seasonNumber: number, episodeNumber: number, watchId: number): Observable<unknown> {
    return this.http.delete(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/episodes/${episodeNumber}/watches/${watchId}`);
  }

  // ── Lists ────────────────────────────────────────────────────────────────

  lists(): Observable<MediaListSummary[]> {
    return this.http.get<MediaListSummary[]>(`${API}/MediaLists`);
  }

  list(id: number): Observable<MediaListSummary> {
    return this.http.get<MediaListSummary>(`${API}/MediaLists/${id}`);
  }

  listItems(id: number | 'seen' | 'liked' | 'watchlist', page = 1, type = 'all'): Observable<PaginatedResult<MediaListItem>> {
    return this.http.get<PaginatedResult<MediaListItem>>(`${API}/MediaLists/${id}/items`, { params: { page, type } });
  }

  addItemToList(listId: number, payload: AddListItemPayload): Observable<unknown> {
    return this.http.post(`${API}/MediaLists/${listId}/items`, payload);
  }

  removeItemFromList(listId: number, tmdbId: number, type: 'movie' | 'tv'): Observable<unknown> {
    return this.http.delete(`${API}/MediaLists/${listId}/items/${tmdbId}`, { params: { type } });
  }

  createList(dto: { name: string; description?: string }): Observable<MediaListSummary> {
    return this.http.post<MediaListSummary>(`${API}/MediaLists`, dto);
  }

  updateList(id: number, dto: { name?: string; description?: string }): Observable<unknown> {
    return this.http.put(`${API}/MediaLists/${id}`, dto);
  }

  deleteList(id: number): Observable<unknown> {
    return this.http.delete(`${API}/MediaLists/${id}`);
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  stats(): Observable<Stats> {
    return this.http.get<Stats>(`${API}/Stats`);
  }

  genresByList(): Observable<StatsListGenres[]> {
    return this.http.get<StatsListGenres[]>(`${API}/Stats/genres-by-list`);
  }

  // ── Activité ─────────────────────────────────────────────────────────────

  activity(page = 1): Observable<PaginatedResult<Activity>> {
    return this.http.get<PaginatedResult<Activity>>(`${API}/Activity`, { params: { page } });
  }

  // ── Logs système ────────────────────────────────────────────────────────

  logs(page = 1, level = 'all', search = ''): Observable<PaginatedResult<SystemLog>> {
    return this.http.get<PaginatedResult<SystemLog>>(`${API}/Logs`, {
      params: { page, level, search }
    });
  }

  clearLogs(): Observable<unknown> {
    return this.http.delete(`${API}/Logs`);
  }

  // ── Réglages & sorties ─────────────────────────────────────────────────

  settings(): Observable<Settings> {
    return this.http.get<Settings>(`${API}/Settings`);
  }

  updateSettings(settings: WebSettingsUpdate): Observable<Settings> {
    return this.http.put<Settings>(`${API}/Settings`, settings);
  }

  sendTestNotification(): Observable<unknown> {
    return this.http.post(`${API}/Settings/test`, null);
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────

  exportBackup(includeLogs: boolean): Observable<HttpResponse<Blob>> {
    return this.http.get(`${API}/Backup/export`, {
      params: { includeLogs },
      responseType: 'blob',
      observe: 'response',
    });
  }

  /** Remplace toute la base par le contenu du fichier (envoyé tel quel). */
  importBackup(file: Blob): Observable<BackupImportResult> {
    return this.http.post<BackupImportResult>(`${API}/Backup/import`, file, {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ── Recherche torrents & débridage ─────────────────────────────────────

  torrentIndexers(): Observable<Indexer[]> {
    return this.http.get<Indexer[]>(`${API}/torrents/indexers`);
  }

  torrentCategories(): Observable<TorrentCategory[]> {
    return this.http.get<TorrentCategory[]>(`${API}/torrents/categories`);
  }

  searchTorrents(query: string, indexerIds?: number[] | null, categoryId?: number | null): Observable<TorrentResult[]> {
    const params: Record<string, string | string[]> = { query };
    if (indexerIds?.length) params['indexerIds'] = indexerIds.map(String);
    if (categoryId != null) params['categoryId'] = String(categoryId);
    return this.http.get<TorrentResult[]>(`${API}/torrents/search`, { params });
  }

  debridMagnet(magnet: string): Observable<DebridResult> {
    return this.http.post<DebridResult>(`${API}/torrents/debrid`, { magnet });
  }

  unlockLink(link: string): Observable<UnlockResult> {
    return this.http.post<UnlockResult>(`${API}/torrents/unlock`, { link });
  }

  // ── Marque-pages torrents (persistés en base) ──────────────────────────

  torrentBookmarks(): Observable<TorrentBookmark[]> {
    return this.http.get<TorrentBookmark[]>(`${API}/torrent-bookmarks`);
  }

  addTorrentBookmark(torrent: TorrentResult): Observable<TorrentBookmark> {
    return this.http.post<TorrentBookmark>(`${API}/torrent-bookmarks`, torrent);
  }

  removeTorrentBookmark(id: number): Observable<void> {
    return this.http.delete<void>(`${API}/torrent-bookmarks/${id}`);
  }

  // ── Séances de cinéma (Allociné) ───────────────────────────────────────

  // Programme d'un cinéma pour une date (YYYY-MM-DD, défaut aujourd'hui côté serveur).
  showtimes(theater: string, date?: string | null): Observable<TheaterShowtimes> {
    const params: Record<string, string> = { theater };
    if (date) params['date'] = date;
    return this.http.get<TheaterShowtimes>(`${API}/showtimes`, { params });
  }

  // Programme de plusieurs cinémas pour une date. Une salle injoignable est simplement absente.
  multiShowtimes(codes: string[], date?: string | null): Observable<TheaterShowtimes[]> {
    const params: Record<string, string> = { theaters: codes.join(',') };
    if (date) params['date'] = date;
    return this.http.get<TheaterShowtimes[]>(`${API}/showtimes/multi`, { params });
  }

  // ── Cinémas favoris ─────────────────────────────────────────────────────

  favoriteTheaters(): Observable<FavoriteTheater[]> {
    return this.http.get<FavoriteTheater[]>(`${API}/favorite-theaters`);
  }

  addFavoriteTheater(code: string): Observable<FavoriteTheater> {
    return this.http.post<FavoriteTheater>(`${API}/favorite-theaters`, { code });
  }

  removeFavoriteTheater(id: number): Observable<void> {
    return this.http.delete<void>(`${API}/favorite-theaters/${id}`);
  }

  setFavoriteTheaterActive(id: number, isActive: boolean): Observable<void> {
    return this.http.put<void>(`${API}/favorite-theaters/${id}/active`, { isActive });
  }

  trackedMedia(): Observable<TrackedMedia[]> {
    return this.http.get<TrackedMedia[]>(`${API}/TrackedMedia`);
  }

  trackedMediaState(tmdbId: number, type: 'movie' | 'tv'): Observable<TrackedMediaState> {
    return this.http.get<TrackedMediaState>(`${API}/TrackedMedia/state`, { params: { tmdbId, type } });
  }

  addTrackedMedia(payload: AddTrackedMediaPayload): Observable<TrackedMedia> {
    return this.http.post<TrackedMedia>(`${API}/TrackedMedia`, payload);
  }

  removeTrackedMedia(tmdbId: number, type: 'movie' | 'tv'): Observable<unknown> {
    return this.http.delete(`${API}/TrackedMedia/${tmdbId}`, { params: { type } });
  }

  calendarInfo(): Observable<CalendarInfo> {
    return this.http.get<CalendarInfo>(`${API}/calendar/info`);
  }
}

// MySQL restitue les DateTime UTC sans suffixe. Le navigateur les interpréterait
// comme des heures locales, contrairement aux réponses d'ajout qui portent « Z ».
function normalizeWatchDate(event: WatchEvent): WatchEvent {
  const value = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(event.watchedAt) ? event.watchedAt : `${event.watchedAt}Z`;
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? { ...event, watchedAt: date.toISOString() } : event;
}

export function mediaStateKey(item: Pick<MediaItem, 'id' | 'media_type'>): string {
  return `${item.media_type}:${item.id}`;
}

/** Recopie les états utilisateur (vu / aimé / listes) sur chaque item, à partir de la map. */
export function withUserStates(items: MediaItem[], states: Map<string, UserState>): MediaItem[] {
  return items.map(item => {
    const s = states.get(mediaStateKey(item));
    return {
      ...item,
      seen: s?.seen ?? item.seen ?? false,
      watchCount: s?.watchCount ?? item.watchCount ?? 0,
      liked: s?.liked ?? item.liked ?? false,
      listIds: s?.listIds ?? item.listIds ?? [],
    };
  });
}
