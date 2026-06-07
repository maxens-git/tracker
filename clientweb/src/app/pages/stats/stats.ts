import { Component, inject, signal, OnInit, computed } from '@angular/core';
import { Api } from '../../../shared/services/api';
import { Stats, CombinedYearBucket, CombinedMonthBucket } from '../../../shared/interfaces/stats';
import { Spinner } from '../../../shared/components/spinner/spinner';

const MONTHS_FR = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

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
  loading = signal(true);
  error = signal(false);

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

  ngOnInit() {
    this.api.stats().subscribe({
      next: data => { this.stats.set(data); this.loading.set(false); },
      error: () => { this.error.set(true); this.loading.set(false); },
    });
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

  pct(value: number, max: number): string {
    return max > 0 ? `${Math.round((value / max) * 100)}%` : '0%';
  }
}
