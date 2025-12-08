import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { StatsDto } from '../interfaces/stats.interface';

@Injectable({ providedIn: 'root' })
export class StatsService {
  private http = inject(HttpClient);
  private apiUrl = '/api/stats';

  getStats(): Observable<StatsDto> {
    return this.http.get<StatsDto>(this.apiUrl);
  }
}
