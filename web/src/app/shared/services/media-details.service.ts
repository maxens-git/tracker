import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MediaRatings, MovieDetails, ShowDetails } from '../interfaces/media-details.interface';

@Injectable({
  providedIn: 'root'
})
export class MediaDetailsService {
  private http = inject(HttpClient);
  private apiUrl = "/api"

  getMovieDetails(tmdbId: number): Observable<MovieDetails> {
    return this.http.get<MovieDetails>(`${this.apiUrl}/Movies/${tmdbId}`);
  }

  getMovieRatings(tmdbId: number): Observable<MediaRatings | null> {
    return this.http.get<MediaRatings | null>(`${this.apiUrl}/Movies/${tmdbId}/ratings`);
  }

  getShowDetails(tmdbId: number): Observable<ShowDetails> {
    return this.http.get<ShowDetails>(`${this.apiUrl}/Shows/${tmdbId}`);
  }

  getShowRatings(tmdbId: number): Observable<MediaRatings | null> {
    return this.http.get<MediaRatings | null>(`${this.apiUrl}/Shows/${tmdbId}/ratings`);
  }
}
