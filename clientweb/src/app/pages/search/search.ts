import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Subject, debounceTime, distinctUntilChanged, switchMap, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
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
  allResults = signal<MediaItem[]>([]);
  loading = signal(false);
  searched = signal(false);
  filter = signal<'all' | 'movie' | 'tv'>('all');

  /** Résultats filtrés par type (film / série / tout). */
  results = computed(() => {
    const f = this.filter();
    const all = this.allResults();
    return f === 'all' ? all : all.filter(r => r.media_type === f);
  });

  movieCount = computed(() => this.allResults().filter(r => r.media_type === 'movie').length);
  showCount = computed(() => this.allResults().filter(r => r.media_type === 'tv').length);

  ngOnInit() {
    const initial = this.route.snapshot.queryParamMap.get('q') ?? '';
    const initialType = this.route.snapshot.queryParamMap.get('type');
    if (initialType === 'movie' || initialType === 'tv') {
      this.filter.set(initialType);
    }
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
          this.allResults.set([]);
          this.searched.set(false);
          this.loading.set(false);
          this.router.navigate([], { queryParams: {}, replaceUrl: true });
          return of(null);
        }
        this.loading.set(true);
        this.searched.set(true);
        this.syncQueryParams(q);
        return this.tmdb.search(q).pipe(catchError(() => of(null)));
      }),
      // Pour chaque réponse TMDB, on enrichit les résultats avec les états utilisateur.
      switchMap(resp => {
        if (!resp) return of([] as MediaItem[]);
        const results = resp.results.filter(r => r.media_type === 'movie' || r.media_type === 'tv');
        return this.api.statesByTmdbId(results).pipe(
          map(states => withUserStates(results, states))
        );
      })
    ).subscribe({
      next: results => {
        if (results) this.allResults.set(results);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    this.query$.next(this.query);
  }

  onInput() { this.query$.next(this.query); }

  setFilter(f: 'all' | 'movie' | 'tv') {
    this.filter.set(f);
    if (this.query.trim()) this.syncQueryParams(this.query);
  }

  private syncQueryParams(q: string) {
    const type = this.filter();
    this.router.navigate([], {
      queryParams: type === 'all' ? { q } : { q, type },
      replaceUrl: true,
    });
  }
}
