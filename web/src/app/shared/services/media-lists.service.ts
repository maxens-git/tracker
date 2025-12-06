import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MediaListSummary } from '../interfaces/media-list.interface';
import { MovieDetails, ShowDetails } from '../interfaces/media-details.interface';

type LikeResponse = { tmdbId: number; liked: boolean };
type SeenResponse = { id: number; seen: boolean };

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

@Injectable({ providedIn: 'root' })
export class MediaListsService {
  private readonly apiUrl = '/api/medialists';

  constructor(private http: HttpClient) {}

  getAll(): Observable<MediaListSummary[]> {
    return this.http.get<MediaListSummary[]>(this.apiUrl);
  }

  setMovieLiked(tmdbId: number, liked: boolean): Observable<LikeResponse> {
    return this.http.post<LikeResponse>(`${this.apiUrl}/movies/${tmdbId}/like`, null, {
      params: { liked }
    });
  }

  likeMovie(tmdbId: number): Observable<LikeResponse> {
    return this.setMovieLiked(tmdbId, true);
  }

  unlikeMovie(tmdbId: number): Observable<LikeResponse> {
    return this.setMovieLiked(tmdbId, false);
  }

  setShowLiked(tmdbId: number, liked: boolean): Observable<LikeResponse> {
    return this.http.post<LikeResponse>(`${this.apiUrl}/shows/${tmdbId}/like`, null, {
      params: { liked }
    });
  }

  likeShow(tmdbId: number): Observable<LikeResponse> {
    return this.setShowLiked(tmdbId, true);
  }

  unlikeShow(tmdbId: number): Observable<LikeResponse> {
    return this.setShowLiked(tmdbId, false);
  }

  setMovieSeen(id: number, seen: boolean): Observable<SeenResponse> {
    return this.http.post<SeenResponse>(`/api/movies/${id}/seen`, seen);
  }

  setShowSeen(id: number, seen: boolean): Observable<SeenResponse> {
    return this.http.post<SeenResponse>(`/api/shows/${id}/seen`, seen);
  }

  setSeasonSeen(id: number, seen: boolean): Observable<SeenResponse> {
    return this.http.post<SeenResponse>(`/api/shows/seasons/${id}/seen`, seen);
  }

  setEpisodeSeen(id: number, seen: boolean): Observable<SeenResponse> {
    return this.http.post<SeenResponse>(`/api/shows/episodes/${id}/seen`, seen);
  }

  getLikedMovies(page: number = 1): Observable<PaginatedResult<MovieDetails>> {
    return this.http.get<PaginatedResult<MovieDetails>>(`${this.apiUrl}/liked/movies`, {
      params: { page: page.toString() }
    });
  }

  getLikedShows(page: number = 1): Observable<PaginatedResult<ShowDetails>> {
    return this.http.get<PaginatedResult<ShowDetails>>(`${this.apiUrl}/liked/shows`, {
      params: { page: page.toString() }
    });
  }

  getSeenMovies(page: number = 1): Observable<PaginatedResult<MovieDetails>> {
    return this.http.get<PaginatedResult<MovieDetails>>(`${this.apiUrl}/seen/movies`, {
      params: { page: page.toString() }
    });
  }

  getSeenShows(page: number = 1): Observable<PaginatedResult<ShowDetails>> {
    return this.http.get<PaginatedResult<ShowDetails>>(`${this.apiUrl}/seen/shows`, {
      params: { page: page.toString() }
    });
  }

  addMovieToList(listId: number, tmdbId: number): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/${listId}/movies/${tmdbId}`, null);
  }

  removeMovieFromList(listId: number, tmdbId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${listId}/movies/${tmdbId}`);
  }

  addShowToList(listId: number, tmdbId: number): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/${listId}/shows/${tmdbId}`, null);
  }

  removeShowFromList(listId: number, tmdbId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${listId}/shows/${tmdbId}`);
  }
}

