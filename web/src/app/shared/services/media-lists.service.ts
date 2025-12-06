import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MediaListSummary } from '../interfaces/media-list.interface';

type LikeResponse = { tmdbId: number; liked: boolean };

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
}
