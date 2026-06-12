import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { forkJoin, map, switchMap } from 'rxjs';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
import { MediaItem } from '../../../shared/interfaces/media';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { backdropUrl, displayTitle, displayYear } from '../../../shared/services/tmdb-image';

interface HomeData {
  featuredItem?: MediaItem;
  trendingWeek: MediaItem[];
  popularMovies: MediaItem[];
  popularShows: MediaItem[];
  topRated: MediaItem[];
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink, MediaRow, Spinner],
  templateUrl: './home.html',
  styleUrl: './home.scss',
})
export class Home implements OnInit {
  private tmdb = inject(TmdbService);
  private api = inject(Api);

  data = signal<HomeData | null>(null);
  loading = signal(true);
  error = signal<string | null>(null);

  ngOnInit() {
    forkJoin({
      trending: this.tmdb.trendingWeek(),
      popularMovies: this.tmdb.popularMovies(),
      popularShows: this.tmdb.popularShows(),
      topRated: this.tmdb.topRated('movie'),
    }).pipe(
      // Une fois les rangées TMDB chargées, on récupère les états utilisateur de tous les items.
      switchMap(rows => {
        const allItems = [
          ...rows.trending.results,
          ...rows.popularMovies.results,
          ...rows.popularShows.results,
          ...rows.topRated.results,
        ];
        return this.api.statesByTmdbId(allItems).pipe(
          map(states => ({ rows, states })),
        );
      }),
    ).subscribe({
      next: ({ rows, states }) => {
        this.data.set({
          featuredItem: rows.trending.results[0],
          trendingWeek: withUserStates(rows.trending.results.slice(0, 20), states),
          popularMovies: withUserStates(rows.popularMovies.results.slice(0, 20), states),
          popularShows: withUserStates(rows.popularShows.results.slice(0, 20), states),
          topRated: withUserStates(rows.topRated.results.slice(0, 20), states),
        });
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossible de charger les tendances');
        this.loading.set(false);
      },
    });
  }

  hero(d: HomeData) {
    const item = d.featuredItem;
    if (!item) return null;
    return {
      title: displayTitle(item),
      year: displayYear(item),
      overview: item.overview,
      backdrop: backdropUrl(item.backdrop_path, 'original'),
      link: ['/' + item.media_type, item.id],
    };
  }
}
