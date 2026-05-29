import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, forkJoin, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { environment } from '../../environments/environment';
import {
  TmdbMovie, TmdbShow, TmdbSeason, TmdbCredits, TmdbVideos,
  TmdbSearchResponse, TmdbTrendingResult, MediaItem
} from '../interfaces/media';

const BASE = environment.tmdbBaseUrl;
const KEY = environment.tmdbApiKey;
const LANG = environment.tmdbLang;

function params(extra: Record<string, string | number> = {}): HttpParams {
  let p = new HttpParams().set('api_key', KEY).set('language', LANG);
  for (const [k, v] of Object.entries(extra)) p = p.set(k, String(v));
  return p;
}

@Injectable({ providedIn: 'root' })
export class TmdbService {
  private http = inject(HttpClient);

  movie(tmdbId: number): Observable<TmdbMovie> {
    return this.http.get<TmdbMovie>(`${BASE}/movie/${tmdbId}`, { params: params() });
  }

  show(tmdbId: number): Observable<TmdbShow> {
    return this.http.get<TmdbShow>(`${BASE}/tv/${tmdbId}`, { params: params() });
  }

  season(showId: number, seasonNumber: number): Observable<TmdbSeason> {
    return this.http.get<TmdbSeason>(`${BASE}/tv/${showId}/season/${seasonNumber}`, { params: params() });
  }

  movieCredits(tmdbId: number): Observable<TmdbCredits> {
    return this.http.get<TmdbCredits>(`${BASE}/movie/${tmdbId}/credits`, { params: params() });
  }

  showCredits(tmdbId: number): Observable<TmdbCredits> {
    return this.http.get<TmdbCredits>(`${BASE}/tv/${tmdbId}/credits`, { params: params() });
  }

  movieVideos(tmdbId: number): Observable<TmdbVideos> {
    return this.http.get<TmdbVideos>(`${BASE}/movie/${tmdbId}/videos`, { params: params() });
  }

  showVideos(tmdbId: number): Observable<TmdbVideos> {
    return this.http.get<TmdbVideos>(`${BASE}/tv/${tmdbId}/videos`, { params: params() });
  }

  similarMovies(tmdbId: number): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/movie/${tmdbId}/similar`, { params: params() }).pipe(
      map(r => withMediaType(r, 'movie'))
    );
  }

  similarShows(tmdbId: number): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/tv/${tmdbId}/similar`, { params: params() }).pipe(
      map(r => withMediaType(r, 'tv'))
    );
  }

  search(query: string, page = 1): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/search/multi`, {
      params: params({ query, page })
    });
  }

  trendingWeek(): Observable<TmdbTrendingResult> {
    return this.http.get<TmdbTrendingResult>(`${BASE}/trending/all/week`, { params: params() });
  }

  popularMovies(page = 1): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/movie/popular`, { params: params({ page }) }).pipe(
      map(r => withMediaType(r, 'movie'))
    );
  }

  popularShows(page = 1): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/tv/popular`, { params: params({ page }) }).pipe(
      map(r => withMediaType(r, 'tv'))
    );
  }

  topRated(mediaType: 'movie' | 'tv', page = 1): Observable<TmdbSearchResponse> {
    return this.http.get<TmdbSearchResponse>(`${BASE}/${mediaType}/top_rated`, { params: params({ page }) }).pipe(
      map(r => withMediaType(r, mediaType))
    );
  }

  fetchMany(items: { tmdbId: number; mediaType: string }[]): Observable<MediaItem[]> {
    if (items.length === 0) return of([]);
    const calls = items.map(({ tmdbId, mediaType }) => {
      const type = mediaType === 'movie' ? 'movie' : 'tv';
      return this.http.get<TmdbMovie | TmdbShow>(`${BASE}/${type}/${tmdbId}`, { params: params() }).pipe(
        map(r => toMediaItem(r, type)),
        catchError(() => of(null))
      );
    });
    return forkJoin(calls).pipe(
      map(results => results.filter((r): r is MediaItem => r !== null))
    );
  }
}

function withMediaType(response: TmdbSearchResponse, mediaType: 'movie' | 'tv'): TmdbSearchResponse {
  return {
    ...response,
    results: response.results.map(item => ({ ...item, media_type: item.media_type || mediaType }))
  };
}

export function toMediaItem(r: TmdbMovie | TmdbShow, mediaType: 'movie' | 'tv'): MediaItem {
  if (mediaType === 'movie') {
    const m = r as TmdbMovie;
    return {
      id: m.id,
      media_type: 'movie',
      title: m.title,
      original_title: m.original_title,
      overview: m.overview,
      poster_path: m.poster_path,
      backdrop_path: m.backdrop_path,
      release_date: m.release_date,
      vote_average: m.vote_average,
      vote_count: m.vote_count,
      popularity: m.popularity,
      seen: false
    };
  } else {
    const s = r as TmdbShow;
    return {
      id: s.id,
      media_type: 'tv',
      name: s.name,
      original_name: s.original_name,
      overview: s.overview,
      poster_path: s.poster_path,
      backdrop_path: s.backdrop_path,
      first_air_date: s.first_air_date,
      vote_average: s.vote_average,
      vote_count: s.vote_count,
      popularity: s.popularity,
      seen: false
    };
  }
}
