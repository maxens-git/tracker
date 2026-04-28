import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TrendingHome, SearchResponse } from '../interfaces/media';
import { MovieDto, CreditsDto, TrailersDto } from '../interfaces/movie';

const API = 'http://localhost:5050/api';

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

  markSeen(id: number, seen: boolean): Observable<unknown> {
    return this.http.post(`${API}/Movies/${id}/seen`, seen, {
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
