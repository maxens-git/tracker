import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Subject, debounceTime, distinctUntilChanged, switchMap, forkJoin, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api } from '../../../shared/services/api';
import { MediaItem } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [CommonModule, FormsModule, PosterCard, Spinner],
  templateUrl: './search.html',
  styleUrl: './search.scss',
})
export class Search implements OnInit {
  private tmdb = inject(TmdbService);
  private api = inject(Api);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private query$ = new Subject<string>();

  query = '';
  results = signal<MediaItem[]>([]);
  loading = signal(false);
  searched = signal(false);

  ngOnInit() {
    const initial = this.route.snapshot.queryParamMap.get('q') ?? '';
    if (initial) {
      this.query = initial;
      this.searched.set(true);
      this.loading.set(true);
    }

    this.query$.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(q => {
        if (!q.trim()) {
          this.results.set([]);
          this.searched.set(false);
          this.loading.set(false);
          this.router.navigate([], { queryParams: {}, replaceUrl: true });
          return of(null);
        }
        this.loading.set(true);
        this.searched.set(true);
        this.router.navigate([], { queryParams: { q }, replaceUrl: true });
        return this.tmdb.search(q).pipe(catchError(() => of(null)));
      }),
      switchMap(resp => {
        if (!resp) return of([] as MediaItem[]);
        const results = resp.results.filter(r => r.media_type === 'movie' || r.media_type === 'tv');
        const movieIds = results.filter(r => r.media_type === 'movie').map(r => r.id);
        const showIds = results.filter(r => r.media_type === 'tv').map(r => r.id);

        const movieStates$ = movieIds.length > 0 ? this.api.states(movieIds, 'movie').pipe(catchError(() => of([]))) : of([]);
        const showStates$ = showIds.length > 0 ? this.api.states(showIds, 'tv').pipe(catchError(() => of([]))) : of([]);

        return forkJoin({ movieStates: movieStates$, showStates: showStates$ }).pipe(
          map(({ movieStates, showStates }) => {
            const stateMap = new Map([...movieStates, ...showStates].map(s => [s.tmdbId, s]));
            return results.map(r => {
              const s = stateMap.get(r.id);
              return { ...r, seen: s?.seen ?? false, liked: s?.liked ?? false, listIds: s?.listIds ?? [] };
            });
          })
        );
      })
    ).subscribe({
      next: results => {
        if (results) this.results.set(results);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    this.query$.next(this.query);
  }

  onInput() { this.query$.next(this.query); }
}
