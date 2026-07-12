import { Component, inject, signal, OnInit, computed } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Api } from '../../../shared/services/api';
import { Stats, StatsGenreBucket, StatsListGenres, CombinedYearBucket, CombinedMonthBucket } from '../../../shared/interfaces/stats';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SYSTEM_LIST } from '../../../shared/constants';

const MONTHS_FR = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
const GENRE_COLLAPSED_COUNT = 7;

@Component({
  selector: 'app-stats',
  standalone: true,
  imports: [Spinner],
  templateUrl: './stats.html',
  styleUrl: './stats.scss',
})
export class StatsPage implements OnInit {
  private api = inject(Api);

  stats = signal<Stats | null>(null);
  listGenres = signal<StatsListGenres[]>([]);
  selectedListId = signal<number | null>(null);
  loading = signal(true);
  error = signal(false);
  showAllGenres = signal(false);
  // 'titles' = % de titres ayant ce genre (somme > 100%) ; 'tags' = part de chaque genre (somme = 100%)
  genreMode = signal<'titles' | 'tags'>('titles');

  /** Genres bruts de la liste sélectionnée. */
  private selectedGenres = computed<StatsGenreBucket[]>(() =>
    this.listGenres().find(l => l.listId === this.selectedListId())?.genres ?? []);

  /** Genres de la liste sélectionnée avec le % recalculé selon le mode choisi. */
  private scoredGenres = computed<StatsGenreBucket[]>(() => {
    const genres = this.selectedGenres();
    if (this.genreMode() === 'titles') return genres;
    const totalTags = genres.reduce((sum, g) => sum + g.count, 0);
    if (totalTags === 0) return genres;
    return genres.map(g => ({ ...g, percentage: Math.round((g.count * 100) / totalTags) }));
  });

  visibleGenres = computed<StatsGenreBucket[]>(() => {
    const genres = this.scoredGenres();
    return this.showAllGenres() ? genres : genres.slice(0, GENRE_COLLAPSED_COUNT);
  });

  hasMoreGenres = computed(() => this.selectedGenres().length > GENRE_COLLAPSED_COUNT);

  /** Listes proposées dans le sélecteur (celles ayant au moins un genre). */
  genreLists = computed<StatsListGenres[]>(() => this.listGenres().filter(l => l.genres.length > 0));

  byYear = computed<CombinedYearBucket[]>(() => {
    const s = this.stats();
    if (!s) return [];
    const map = new Map<number, CombinedYearBucket>();
    for (const b of s.moviesSeenByYear) {
      map.set(b.year, { year: b.year, movies: b.count, episodes: 0, total: b.count });
    }
    for (const b of s.episodesSeenByYear) {
      const existing = map.get(b.year);
      if (existing) { existing.episodes = b.count; existing.total += b.count; }
      else map.set(b.year, { year: b.year, movies: 0, episodes: b.count, total: b.count });
    }
    return Array.from(map.values()).sort((a, b) => a.year - b.year);
  });

  byMonth = computed<CombinedMonthBucket[]>(() => {
    const s = this.stats();
    if (!s) return [];

    const now = new Date();
    const buckets: CombinedMonthBucket[] = [];

    for (let i = 11; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const y = d.getFullYear(), m = d.getMonth() + 1;
      const movies = s.moviesSeenByMonth.find(b => b.year === y && b.month === m)?.count ?? 0;
      const episodes = s.episodesSeenByMonth.find(b => b.year === y && b.month === m)?.count ?? 0;
      buckets.push({ label: MONTHS_FR[m - 1], movies, episodes, total: movies + episodes });
    }
    return buckets;
  });

  maxYear = computed(() => Math.max(...this.byYear().map(b => b.total), 1));
  maxMonth = computed(() => Math.max(...this.byMonth().map(b => b.total), 1));
  maxGenre = computed(() => Math.max(...this.scoredGenres().map(g => g.percentage), 1));

  ngOnInit() {
    // Les genres par liste sont secondaires : une erreur ne doit pas masquer le reste des stats.
    forkJoin([
      this.api.stats(),
      this.api.genresByList().pipe(catchError(() => of([] as StatsListGenres[]))),
    ]).subscribe({
      next: ([stats, listGenres]) => {
        this.stats.set(stats);
        this.listGenres.set(listGenres);
        this.selectedListId.set(this.defaultListId(listGenres));
        this.loading.set(false);
      },
      error: () => { this.error.set(true); this.loading.set(false); },
    });
  }

  /** Liste sélectionnée par défaut : « Vu » si elle a des genres, sinon la première non vide. */
  private defaultListId(lists: StatsListGenres[]): number | null {
    const withGenres = lists.filter(l => l.genres.length > 0);
    const seen = withGenres.find(l => l.isSystem && l.name === SYSTEM_LIST.seen);
    return (seen ?? withGenres[0])?.listId ?? null;
  }

  selectList(id: number) {
    this.selectedListId.set(id);
    this.showAllGenres.set(false);
  }

  formatRuntime(minutes: number): string {
    if (!minutes) return '—';
    const days = Math.floor(minutes / 1440);
    const hours = Math.floor((minutes % 1440) / 60);
    const mins = minutes % 60;
    if (days > 0) return `${days}j ${hours}h`;
    if (hours > 0) return `${hours}h ${mins}min`;
    return `${mins}min`;
  }

  formatRuntimeHours(minutes: number): string {
    if (!minutes) return '—';
    const hours = Math.floor(minutes / 60);
    return `${new Intl.NumberFormat('fr-FR').format(hours)} h`;
  }

  pct(value: number, max: number): string {
    return max > 0 ? `${Math.round((value / max) * 100)}%` : '0%';
  }

  genreColor(index: number): string {
    return ['#e89a63', '#8ba7ea', '#51b7d3', '#a7ba63', '#64bd8d', '#ea8e94', '#dd83ae'][index % 7];
  }
}
