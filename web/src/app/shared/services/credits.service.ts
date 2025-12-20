import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { CreditsResponse } from '../interfaces/credits.interface';

@Injectable({
    providedIn: 'root'
})
export class CreditsService {
    private http = inject(HttpClient);
    private apiUrl = "/api/Credits";

    getMovieCredits(tmdbId: number): Observable<CreditsResponse> {
        return this.http.get<CreditsResponse>(`${this.apiUrl}/movie/${tmdbId}`);
    }

    getShowCredits(tmdbId: number): Observable<CreditsResponse> {
        return this.http.get<CreditsResponse>(`${this.apiUrl}/show/${tmdbId}`);
    }

    getProfileImageUrl(profilePath: string | undefined | null, size: string = 'w185'): string {
        if (!profilePath) {
            return '';
        }
        return `https://image.tmdb.org/t/p/${size}${profilePath}`;
    }
}
