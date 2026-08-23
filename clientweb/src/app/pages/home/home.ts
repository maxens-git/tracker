import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { forkJoin, map, of, switchMap } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
import { MediaItem } from '../../../shared/interfaces/media';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import { ContinueRow, ContinueItem } from '../../../shared/components/continue-row/continue-row';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { ButtonModule } from 'primeng/button';
import { TagModule } from 'primeng/tag';
import { MessageModule } from 'primeng/message';
import { backdropUrl, displayTitle, displayYear } from '../../../shared/services/tmdb-image';

interface HomeData {
  featuredItem?: MediaItem;
  continueWatching: ContinueItem[];
  trendingWeek: MediaItem[];
  popularMovies: MediaItem[];
  popularShows: MediaItem[];
  topRated: MediaItem[];
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink, MediaRow, ContinueRow, Spinner, ButtonModule, TagModule, MessageModule],
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
      // Séries en cours : une erreur réseau ne doit pas casser l'accueil.
      inProgress: this.api.inProgressShows().pipe(catchError(() => of([]))),
    }).pipe(
      // On récupère les fiches TMDB des séries en cours (titre + poster à jour).
      switchMap(rows => {
        const continueRequests = rows.inProgress.map(s => ({ tmdbId: s.showTmdbId, mediaType: 'tv' }));
        return this.tmdb.fetchMany(continueRequests).pipe(
          map(continueItems => ({ rows, continueItems })),
        );
      }),
      // Puis les états utilisateur (vu / aimé / listes) de tous les items affichés.
      switchMap(({ rows, continueItems }) => {
        const allItems = [
          ...continueItems,
          ...rows.trending.results,
          ...rows.popularMovies.results,
          ...rows.popularShows.results,
          ...rows.topRated.results,
        ];
        return this.api.statesByTmdbId(allItems).pipe(
          map(states => ({ rows, continueItems, states })),
        );
      }),
    ).subscribe({
      next: ({ rows, continueItems, states }) => {
        const continueWithStates = withUserStates(continueItems, states);
        // On rattache à chaque fiche TMDB la progression renvoyée par le backend.
        const continueWatching: ContinueItem[] = continueWithStates.map(item => {
          const progress = rows.inProgress.find(s => s.showTmdbId === item.id);
          return {
            item,
            lastSeasonNumber: progress?.lastSeasonNumber ?? 1,
            lastEpisodeNumber: progress?.lastEpisodeNumber ?? 1,
            seenEpisodeCount: progress?.seenEpisodeCount ?? 0,
          };
        });
        this.data.set({
          featuredItem: rows.trending.results[0],
          continueWatching,
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
      backdrop: backdropUrl(item.backdrop_path, 'w1280'),
      link: ['/' + item.media_type, item.id],
    };
  }
}
