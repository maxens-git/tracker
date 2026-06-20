import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { MediaItem, UserState } from '../interfaces/media';
import { MediaListSummary, PaginatedResult, MediaListItem } from '../interfaces/list';
import { Stats } from '../interfaces/stats';
import { EpisodeSeenDto } from '../interfaces/episode';
import { Activity } from '../interfaces/activity';

const API = '/api';

export interface AddListItemPayload {
  tmdbId: number;
  mediaType: string;
  posterPath?: string | null;
}

export interface AddToWatchlistPayload {
  posterPath?: string | null;
  runtime?: number | null;
}

export interface MarkSeenPayload {
  seen: boolean;
  runtime?: number | null;
}

export interface MarkSeasonSeenPayload {
  seen: boolean;
  episodeNumbers: number[];
}

export interface MarkShowSeenPayload {
  seen: boolean;
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
  updatedAt: string;
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

@Injectable({ providedIn: 'root' })
export class Api {
  private http = inject(HttpClient);

  // ── User states ──────────────────────────────────────────────────────────

  states(tmdbIds: number[], type: 'movie' | 'tv'): Observable<UserState[]> {
    return this.http.get<UserState[]>(`${API}/Media/states`, {
      params: { tmdbIds: tmdbIds.join(','), type }
    });
  }

  /**
   * Charge en une fois les états utilisateur (vu / aimé / listes) des films et séries
   * donnés, indexés par tmdbId. Une erreur réseau renvoie simplement une map vide.
   */
  statesByTmdbId(items: Pick<MediaItem, 'id' | 'media_type'>[]): Observable<Map<number, UserState>> {
    const movieIds = items.filter(i => i.media_type === 'movie').map(i => i.id);
    const showIds = items.filter(i => i.media_type === 'tv').map(i => i.id);

    const movieStates$ = movieIds.length ? this.states(movieIds, 'movie').pipe(catchError(() => of([]))) : of([]);
    const showStates$ = showIds.length ? this.states(showIds, 'tv').pipe(catchError(() => of([]))) : of([]);

    return forkJoin([movieStates$, showStates$]).pipe(
      map(([movieStates, showStates]) =>
        new Map([...movieStates, ...showStates].map(s => [s.tmdbId, s])))
    );
  }

  markSeen(tmdbId: number, type: 'movie' | 'tv', payload: MarkSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Media/${tmdbId}/seen`, payload, { params: { type } });
  }

  markLiked(tmdbId: number, type: 'movie' | 'tv', liked: boolean): Observable<unknown> {
    return this.http.post(`${API}/Media/${tmdbId}/liked`, liked, {
      headers: { 'Content-Type': 'application/json' },
      params: { type }
    });
  }

  addToWatchlist(tmdbId: number, type: 'movie' | 'tv', payload: AddToWatchlistPayload = {}): Observable<unknown> {
    return this.http.post(`${API}/Media/${tmdbId}/watchlist`, payload, { params: { type } });
  }

  removeFromWatchlist(tmdbId: number, type: 'movie' | 'tv'): Observable<unknown> {
    return this.http.delete(`${API}/Media/${tmdbId}/watchlist`, { params: { type } });
  }

  // ── Episodes ─────────────────────────────────────────────────────────────

  showEpisodes(showTmdbId: number): Observable<EpisodeSeenDto[]> {
    return this.http.get<EpisodeSeenDto[]>(`${API}/Shows/${showTmdbId}/episodes`);
  }

  markShowSeen(showTmdbId: number, payload: MarkShowSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seen`, payload);
  }

  markSeasonSeen(showTmdbId: number, seasonNumber: number, payload: MarkSeasonSeenPayload): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/seen`, payload);
  }

  markEpisodeSeen(showTmdbId: number, seasonNumber: number, episodeNumber: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Shows/${showTmdbId}/seasons/${seasonNumber}/episodes/${episodeNumber}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
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

  createList(dto: { name: string; description?: string; icon?: string }): Observable<MediaListSummary> {
    return this.http.post<MediaListSummary>(`${API}/MediaLists`, dto);
  }

  updateList(id: number, dto: { name?: string; description?: string; icon?: string }): Observable<unknown> {
    return this.http.put(`${API}/MediaLists/${id}`, dto);
  }

  deleteList(id: number): Observable<unknown> {
    return this.http.delete(`${API}/MediaLists/${id}`);
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  stats(): Observable<Stats> {
    return this.http.get<Stats>(`${API}/Stats`);
  }

  // ── Activité ─────────────────────────────────────────────────────────────

  activity(page = 1): Observable<PaginatedResult<Activity>> {
    return this.http.get<PaginatedResult<Activity>>(`${API}/Activity`, { params: { page } });
  }

  // ── Réglages & sorties ─────────────────────────────────────────────────

  settings(): Observable<Settings> {
    return this.http.get<Settings>(`${API}/Settings`);
  }

  updateSettings(settings: Omit<Settings, 'updatedAt'>): Observable<Settings> {
    return this.http.put<Settings>(`${API}/Settings`, settings);
  }

  sendTestNotification(): Observable<unknown> {
    return this.http.post(`${API}/Settings/test`, null);
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

/** Recopie les états utilisateur (vu / aimé / listes) sur chaque item, à partir de la map. */
export function withUserStates(items: MediaItem[], states: Map<number, UserState>): MediaItem[] {
  return items.map(item => {
    const s = states.get(item.id);
    return { ...item, seen: s?.seen ?? false, liked: s?.liked ?? false, listIds: s?.listIds ?? [] };
  });
}
