import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api } from '../../../shared/services/api';
import { MediaItem, TmdbTrendingResult, TmdbSearchResponse } from '../../../shared/interfaces/media';
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
    }).subscribe({
      next: ({ trending, popularMovies, popularShows, topRated }) => {
        const allItems = [
          ...trending.results,
          ...popularMovies.results,
          ...popularShows.results,
          ...topRated.results,
        ];
        const uniqueIds = [...new Set(allItems.map(i => i.id))];
        const movieIds = uniqueIds.filter(id => allItems.find(i => i.id === id)?.media_type === 'movie');
        const showIds = uniqueIds.filter(id => allItems.find(i => i.id === id)?.media_type === 'tv');

        const applyStates = (items: MediaItem[], stateMap: Map<number, { seen: boolean; liked: boolean }>) =>
          items.map(i => ({ ...i, seen: stateMap.get(i.id)?.seen ?? false, liked: stateMap.get(i.id)?.liked ?? false }));

        const movieStates$ = movieIds.length > 0
          ? this.api.states(movieIds, 'movie')
          : Promise.resolve([]);
        const showStates$ = showIds.length > 0
          ? this.api.states(showIds, 'tv')
          : Promise.resolve([]);

        forkJoin({ movieStates: movieStates$, showStates: showStates$ }).subscribe({
          next: ({ movieStates, showStates }) => {
            const stateMap = new Map<number, { seen: boolean; liked: boolean }>();
            for (const s of [...movieStates, ...showStates]) {
              stateMap.set(s.tmdbId, { seen: s.seen, liked: s.liked });
            }

            this.data.set({
              featuredItem: trending.results[0],
              trendingWeek: applyStates(trending.results.slice(0, 20), stateMap),
              popularMovies: applyStates(popularMovies.results.slice(0, 20), stateMap),
              popularShows: applyStates(popularShows.results.slice(0, 20), stateMap),
              topRated: applyStates(topRated.results.slice(0, 20), stateMap),
            });
            this.loading.set(false);
          },
        });
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
