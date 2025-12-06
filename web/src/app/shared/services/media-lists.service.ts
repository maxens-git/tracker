import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MediaListSummary } from '../interfaces/media-list.interface';

@Injectable({ providedIn: 'root' })
export class MediaListsService {
  private readonly apiUrl = '/api/medialists';

  constructor(private http: HttpClient) {}

  getAll(): Observable<MediaListSummary[]> {
    return this.http.get<MediaListSummary[]>(this.apiUrl);
  }
}
