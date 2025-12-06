import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TMDbSearchResult } from '../interfaces/tmdb-trending.interface';
import { SearchResponse } from '../interfaces/search-response.interface';

@Injectable({ providedIn: 'root' })
export class SearchService {
  private http = inject(HttpClient);
  private readonly apiUrl = '/api/search';

  search(query: string, page: number = 1, take: number = 10): Observable<SearchResponse> {
    const params = new URLSearchParams({ query, page: page.toString(), take: take.toString() });
    return this.http.get<SearchResponse>(`${this.apiUrl}?${params.toString()}`);
  }

  suggest(query: string, take: number = 5): Observable<TMDbSearchResult[]> {
    const params = new URLSearchParams({ query, take: take.toString() });
    return this.http.get<TMDbSearchResult[]>(`${this.apiUrl}/suggestions?${params.toString()}`);
  }
}
