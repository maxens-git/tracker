import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { Ripple } from 'primeng/ripple';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Subject, debounceTime, distinctUntilChanged, switchMap, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
import { MediaItem, TmdbGenre } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { ButtonModule } from 'primeng/button';
import { IconFieldModule } from 'primeng/iconfield';
import { InputIconModule } from 'primeng/inputicon';
import { InputTextModule } from 'primeng/inputtext';

type SortKey = 'relevance' | 'rating' | 'date_desc' | 'date_asc' | 'popularity';

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [Ripple, CommonModule, FormsModule, PosterCard, Spinner, ButtonModule, IconFieldModule, InputIconModule, InputTextModule],
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

  // ── Filtres genre + tri (appliqués côté client sur les résultats) ──────────
  allGenres = signal<TmdbGenre[]>([]);
  selectedGenreIds = signal<Set<number>>(new Set());
  sort = signal<SortKey>('relevance');
  showFilters = signal(false);

  readonly sortOptions: { key: SortKey; label: string }[] = [
    { key: 'relevance', label: 'Pertinence' },
    { key: 'rating', label: 'Note' },
    { key: 'date_desc', label: 'Plus récent' },
    { key: 'date_asc', label: 'Plus ancien' },
    { key: 'popularity', label: 'Popularité' },
  ];

  /** Vrai si un filtre genre ou un tri non par défaut est actif. */
  hasActiveFilters = computed(() => this.selectedGenreIds().size > 0 || this.sort() !== 'relevance');

  /** Genres effectivement présents dans les résultats, pour ne proposer que des filtres utiles. */
  relevantGenres = computed(() => {
    const present = new Set<number>();
    for (const r of this.allResults()) for (const id of r.genre_ids ?? []) present.add(id);
    return this.allGenres().filter(g => present.has(g.id));
  });

  /** Résultats après filtre de type, filtre de genres et tri (tout côté client). */
  results = computed(() => {
    const f = this.filter();
    const genres = this.selectedGenreIds();
    let items = this.allResults();
    if (f !== 'all') items = items.filter(r => r.media_type === f);
    if (genres.size > 0) {
      items = items.filter(r => (r.genre_ids ?? []).some(id => genres.has(id)));
    }
    return this.sortItems(items);
  });

  movieCount = computed(() => this.allResults().filter(r => r.media_type === 'movie').length);
  showCount = computed(() => this.allResults().filter(r => r.media_type === 'tv').length);

  ngOnInit() {
    this.tmdb.genres().subscribe(g => this.allGenres.set(g));

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

  // ── Filtres genre + tri ────────────────────────────────────────────────────

  toggleFilters() { this.showFilters.update(v => !v); }

  setSort(key: SortKey) { this.sort.set(key); }

  isGenreSelected(id: number) { return this.selectedGenreIds().has(id); }

  toggleGenre(id: number) {
    this.selectedGenreIds.update(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  resetFilters() {
    this.selectedGenreIds.set(new Set());
    this.sort.set('relevance');
  }

  /** Applique le tri courant à une liste de résultats (copie, sans muter le signal). */
  private sortItems(items: MediaItem[]): MediaItem[] {
    const sort = this.sort();
    if (sort === 'relevance') return items;
    const date = (r: MediaItem) => r.release_date || r.first_air_date || '';
    const copy = [...items];
    switch (sort) {
      case 'rating': return copy.sort((a, b) => b.vote_average - a.vote_average);
      case 'popularity': return copy.sort((a, b) => b.popularity - a.popularity);
      case 'date_desc': return copy.sort((a, b) => date(b).localeCompare(date(a)));
      case 'date_asc': return copy.sort((a, b) => date(a).localeCompare(date(b)));
      default: return copy;
    }
  }
}
