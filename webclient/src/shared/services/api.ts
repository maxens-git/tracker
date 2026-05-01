import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TrendingHome, SearchResponse } from '../interfaces/media';
import { MovieDto, CreditsDto, TrailersDto } from '../interfaces/movie';
import { ShowDto } from '../interfaces/show';
import { MediaListSummary, PaginatedResult, MediaListSearchItem } from '../interfaces/list';
import { Stats } from '../interfaces/stats';

const API = '/api';

@Injectable({ providedIn: 'root' })
export class Api {
  private http = inject(HttpClient);

  home(): Observable<TrendingHome> {
    return this.http.get<TrendingHome>(`${API}/Trends/home`);
  }

  search(query: string): Observable<SearchResponse> {
    return this.http.get<SearchResponse>(`${API}/Search`, { params: { query, take: 20 } });
  }

  movie(tmdbId: number): Observable<MovieDto> {
    return this.http.get<MovieDto>(`${API}/Movies/${tmdbId}`);
  }

  movieCredits(tmdbId: number): Observable<CreditsDto> {
    return this.http.get<CreditsDto>(`${API}/Credits/movie/${tmdbId}`);
  }

  movieTrailers(tmdbId: number): Observable<TrailersDto> {
    return this.http.get<TrailersDto>(`${API}/Trailers/movie/${tmdbId}`);
  }

  markMovieSeen(id: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Movies/${id}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /** @deprecated use markMovieSeen */
  markSeen(id: number, seen: boolean): Observable<unknown> {
    return this.markMovieSeen(id, seen);
  }

  show(tmdbId: number): Observable<ShowDto> {
    return this.http.get<ShowDto>(`${API}/Shows/${tmdbId}`);
  }

  showCredits(tmdbId: number): Observable<CreditsDto> {
    return this.http.get<CreditsDto>(`${API}/Credits/show/${tmdbId}`);
  }

  showTrailers(tmdbId: number): Observable<TrailersDto> {
    return this.http.get<TrailersDto>(`${API}/Trailers/show/${tmdbId}`);
  }

  markShowSeen(id: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Shows/${id}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  markSeasonSeen(id: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Shows/seasons/${id}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  markEpisodeSeen(id: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Shows/episodes/${id}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  similarMovies(tmdbId: number): Observable<SearchResponse> {
    return this.http.get<SearchResponse>(`${API}/Similar/movies/${tmdbId}`);
  }

  similarShows(tmdbId: number): Observable<SearchResponse> {
    return this.http.get<SearchResponse>(`${API}/Similar/shows/${tmdbId}`);
  }

  addMovieToWatchlist(tmdbId: number): Observable<unknown> {
    return this.http.post(`${API}/Movies/${tmdbId}/watchlist`, null);
  }

  removeMovieFromWatchlist(tmdbId: number): Observable<unknown> {
    return this.http.delete(`${API}/Movies/${tmdbId}/watchlist`);
  }

  addShowToWatchlist(tmdbId: number): Observable<unknown> {
    return this.http.post(`${API}/Shows/${tmdbId}/watchlist`, null);
  }

  removeShowFromWatchlist(tmdbId: number): Observable<unknown> {
    return this.http.delete(`${API}/Shows/${tmdbId}/watchlist`);
  }

  likeMovie(tmdbId: number, liked: boolean): Observable<unknown> {
    return this.http.post(`${API}/MediaLists/movies/${tmdbId}/like`, null, { params: { liked } });
  }

  likeShow(tmdbId: number, liked: boolean): Observable<unknown> {
    return this.http.post(`${API}/MediaLists/shows/${tmdbId}/like`, null, { params: { liked } });
  }

  addMovieToList(listId: number, tmdbId: number): Observable<unknown> {
    return this.http.post(`${API}/MediaLists/${listId}/movies/${tmdbId}`, null);
  }

  removeMovieFromList(listId: number, tmdbId: number): Observable<unknown> {
    return this.http.delete(`${API}/MediaLists/${listId}/movies/${tmdbId}`);
  }

  addShowToList(listId: number, tmdbId: number): Observable<unknown> {
    return this.http.post(`${API}/MediaLists/${listId}/shows/${tmdbId}`, null);
  }

  removeShowFromList(listId: number, tmdbId: number): Observable<unknown> {
    return this.http.delete(`${API}/MediaLists/${listId}/shows/${tmdbId}`);
  }

  stats(): Observable<Stats> {
    return this.http.get<Stats>(`${API}/Stats`);
  }

  lists(): Observable<MediaListSummary[]> {
    return this.http.get<MediaListSummary[]>(`${API}/MediaLists`);
  }

  list(id: number): Observable<MediaListSummary> {
    return this.http.get<MediaListSummary>(`${API}/MediaLists/${id}`);
  }

  listMovies(id: number, page = 1): Observable<PaginatedResult<MovieDto>> {
    return this.http.get<PaginatedResult<MovieDto>>(`${API}/MediaLists/${id}/movies`, { params: { page } });
  }

  listShows(id: number, page = 1): Observable<PaginatedResult<ShowDto>> {
    return this.http.get<PaginatedResult<ShowDto>>(`${API}/MediaLists/${id}/shows`, { params: { page } });
  }

  searchList(id: number, query: string, page = 1, type = 'all'): Observable<PaginatedResult<MediaListSearchItem>> {
    return this.http.get<PaginatedResult<MediaListSearchItem>>(`${API}/MediaLists/${id}/search`, { params: { query, page, type } });
  }
}
