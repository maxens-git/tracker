import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { SearchResponse } from '../interfaces/search-response.interface';

@Injectable({ providedIn: 'root' })
export class SimilarService {
  private http = inject(HttpClient);
  private readonly apiUrl = '/api/similar';

  getSimilarMovies(tmdbId: number, page: number = 1, take: number = 12): Observable<SearchResponse> {
    const params = new URLSearchParams({ page: page.toString(), take: take.toString() });
    return this.http.get<SearchResponse>(`${this.apiUrl}/movies/${tmdbId}?${params.toString()}`);
  }

  getSimilarShows(tmdbId: number, page: number = 1, take: number = 12): Observable<SearchResponse> {
    const params = new URLSearchParams({ page: page.toString(), take: take.toString() });
    return this.http.get<SearchResponse>(`${this.apiUrl}/shows/${tmdbId}?${params.toString()}`);
  }
}
