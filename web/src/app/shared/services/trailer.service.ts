import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TrailersResponse } from '../interfaces/trailer.interface';

@Injectable({
    providedIn: 'root'
})
export class TrailerService {
    private http = inject(HttpClient);
    private apiUrl = "/api/Trailers";

    getMovieTrailers(tmdbId: number): Observable<TrailersResponse> {
        return this.http.get<TrailersResponse>(`${this.apiUrl}/movie/${tmdbId}`);
    }

    getShowTrailers(tmdbId: number): Observable<TrailersResponse> {
        return this.http.get<TrailersResponse>(`${this.apiUrl}/show/${tmdbId}`);
    }

    getYoutubeEmbedUrl(key: string): string {
        return `https://www.youtube.com/embed/${key}`;
    }

    getYoutubeThumbnailUrl(key: string): string {
        return `https://img.youtube.com/vi/${key}/mqdefault.jpg`;
    }
}
