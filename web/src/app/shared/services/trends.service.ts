import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TrendingHomeData } from '../interfaces/tmdb-trending.interface';

@Injectable({
  providedIn: 'root'
})
export class TrendsService {
  private apiUrl = '/api/trends';

  constructor(private http: HttpClient) {}

  getHomeData(): Observable<TrendingHomeData> {
    return this.http.get<TrendingHomeData>(`${this.apiUrl}/home`);
  }
}
