import { Component, DestroyRef, inject, signal, computed, OnInit } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Subject, distinctUntilChanged, switchMap, of, timer } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
import { SearchHistoryService } from '../../../shared/services/search-history';
import { rank, deduplicate } from '../../../shared/services/search-ranking';
import { MediaItem, TmdbGenre } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { ButtonModule } from 'primeng/button';
import { IconFieldModule } from 'primeng/iconfield';
import { InputIconModule } from 'primeng/inputicon';
import { InputTextModule } from 'primeng/inputtext';
import { SelectButtonModule } from 'primeng/selectbutton';
import { SelectModule } from 'primeng/select';
import { MultiSelectModule } from 'primeng/multiselect';
import { ChipModule } from 'primeng/chip';
import { MessageModule } from 'primeng/message';

type SortKey = 'relevance' | 'rating' | 'date_desc' | 'date_asc' | 'popularity';

/**
 * Nombre de pages TMDB récupérées par recherche (20 résultats chacune).
 * Une seule page ne laissait presque rien aux filtres type/genre une fois les
 * personnes retirées ; les pages suivantes partent en parallèle, donc sans coût
 * de latence notable.
 */
const PAGES_PER_SEARCH = 3;

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [CommonModule, FormsModule, PosterCard, Spinner, ButtonModule, IconFieldModule, InputIconModule, InputTextModule, SelectButtonModule, SelectModule, MultiSelectModule, ChipModule, MessageModule],
  templateUrl: './search.html',
  styleUrl: './search.scss',
})
export class Search implements OnInit {
  private tmdb = inject(TmdbService);
  private api = inject(Api);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private destroyRef = inject(DestroyRef);
  private query$ = new Subject<string>();
  readonly history = inject(SearchHistoryService);

  query = '';
  allResults = signal<MediaItem[]>([]);
  loading = signal(false);
  searched = signal(false);
  error = signal(false);
  filter = signal<'all' | 'movie' | 'tv'>('all');

  // ── Filtres genre + tri (appliqués côté client sur les résultats) ──────────
  allGenres = signal<TmdbGenre[]>([]);
  selectedGenreIds = signal<number[]>([]);
  sort = signal<SortKey>('relevance');

  readonly sortOptions: { key: SortKey; label: string }[] = [
    { key: 'relevance', label: 'Pertinence' },
    { key: 'rating', label: 'Note' },
    { key: 'date_desc', label: 'Plus récent' },
    { key: 'date_asc', label: 'Plus ancien' },
    { key: 'popularity', label: 'Popularité' },
  ];

  /** Vrai si un filtre genre ou un tri non par défaut est actif. */
  hasActiveFilters = computed(() => this.selectedGenreIds().length > 0 || this.sort() !== 'relevance');

  /** Genres effectivement présents dans les résultats, pour ne proposer que des filtres utiles. */
  relevantGenres = computed(() => {
    const present = new Set<number>();
    for (const r of this.allResults()) for (const id of r.genre_ids ?? []) present.add(id);
    return this.allGenres().filter(g => present.has(g.id));
  });

  /** Résultats après filtre de type, filtre de genres et tri (tout côté client). */
  results = computed(() => {
    const f = this.filter();
    const genres = new Set(this.selectedGenreIds());
    let items = this.allResults();
    if (f !== 'all') items = items.filter(r => r.media_type === f);
    if (genres.size > 0) {
      items = items.filter(r => (r.genre_ids ?? []).some(id => genres.has(id)));
    }
    return this.sortItems(items);
  });

  movieCount = computed(() => this.allResults().filter(r => r.media_type === 'movie').length);
  showCount = computed(() => this.allResults().filter(r => r.media_type === 'tv').length);

  /** Options du <p-selectButton> de type, libellés comptés inclus. */
  typeOptions = computed(() => [
    { label: `Tout (${this.allResults().length})`, value: 'all' as const },
    { label: `Films (${this.movieCount()})`, value: 'movie' as const },
    { label: `Séries (${this.showCount()})`, value: 'tv' as const },
  ]);

  ngOnInit() {
    this.tmdb.genres().pipe(takeUntilDestroyed(this.destroyRef)).subscribe(g => this.allGenres.set(g));

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
      map(q => q.trim()),
      distinctUntilChanged(),
      switchMap(q => {
        this.error.set(false);
        if (!q) {
          this.allResults.set([]);
          this.searched.set(false);
          this.loading.set(false);
          this.clearQueryParams();
          return of({ query: q, results: [] as MediaItem[] });
        }
        this.loading.set(true);
        this.searched.set(true);
        this.syncQueryParams(q);
        // Une nouvelle frappe annule immédiatement toute la recherche précédente,
        // y compris l'appel API qui enrichit les états après la réponse TMDB.
        return timer(300).pipe(
          switchMap(() => this.tmdb.searchPages(q, PAGES_PER_SEARCH)),
          switchMap(items => {
            const media = items.filter(r => r.media_type === 'movie' || r.media_type === 'tv');
            const results = rank(deduplicate(media), q);
            return this.api.statesByTmdbId(results).pipe(
              map(states => ({ query: q, results: withUserStates(results, states) })),
            );
          }),
          catchError(() => {
            this.error.set(true);
            return of({ query: q, results: [] as MediaItem[] });
          }),
        );
      }),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe({
      next: ({ query, results }) => {
        this.allResults.set(results);
        // La recherche a abouti : on l'ajoute à l'historique récent.
        if (results.length > 0) this.history.record(query);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    this.query$.next(this.query);
  }

  onInput() { this.query$.next(this.query); }

  /** Relance une recherche depuis l'historique. */
  useRecent(q: string) {
    this.query = q;
    this.query$.next(q);
  }

  removeRecent(entry: string, event: MouseEvent) {
    event.stopPropagation();
    this.history.remove(entry);
  }

  clearHistory() { this.history.clear(); }

  setFilter(f: 'all' | 'movie' | 'tv') {
    this.filter.set(f);
    if (this.query.trim()) this.syncQueryParams(this.query);
  }

  // On met à jour l'URL via Location.replaceState plutôt que router.navigate : une
  // navigation relancerait le cycle du routeur, or ReloadRouteReuseStrategy
  // (shouldReuseRoute=false) + onSameUrlNavigation:'reload' détruiraient puis recréeraient
  // ce composant → nouvel ngOnInit → query$.next → syncQueryParams → … boucle infinie.
  private syncQueryParams(q: string) {
    const type = this.filter();
    this.replaceUrl(type === 'all' ? { q } : { q, type });
  }

  private clearQueryParams() {
    this.replaceUrl({});
  }

  private replaceUrl(queryParams: Record<string, string>) {
    const urlTree = this.router.createUrlTree([], { relativeTo: this.route, queryParams });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  // ── Filtres genre + tri ────────────────────────────────────────────────────

  resetFilters() {
    this.selectedGenreIds.set([]);
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
