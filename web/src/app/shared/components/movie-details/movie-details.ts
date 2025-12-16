
import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { SimilarService } from '../../services/similar.service';
import { MediaListsService } from '../../services/media-lists.service';
import { CommonModule } from '@angular/common';
import { MovieDetails } from '../../interfaces/media-details.interface';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';
import { PosterCardComponent } from '../poster-card/poster-card';
import { MediaListSummary } from '../../interfaces/media-list.interface';

@Component({
  selector: 'app-movie-details',
  standalone: true,
  imports: [CommonModule, PosterCardComponent],
  templateUrl: './movie-details.html',
  styleUrl: './movie-details.scss'
})
export class MovieDetailsComponent implements OnInit {
    protected listActionLoading = signal<{ [listId: number]: boolean }>({});
  protected movieDetails = signal<MovieDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected likeLoading = signal<boolean>(false);
  protected seenLoading = signal<boolean>(false);
  protected watchlistLoading = signal<boolean>(false);
  protected inWatchlist = signal<boolean>(false);
  protected watchlistId = signal<number | null>(null);
  protected error = signal<string | null>(null);
  protected similar = signal<TMDbSearchResult[]>([]);
  protected similarLoading = signal<boolean>(true);
  protected showListModal = signal<boolean>(false);
  protected lists = signal<MediaListSummary[]>([]);
  protected listLoading = signal<boolean>(false);

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private mediaDetailsService: MediaDetailsService,
    private similarService: SimilarService,
    private mediaListsService: MediaListsService
  ) {}

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const tmdbId = Number(params.get('id'));
      if (!tmdbId) return;
      this.fetchMovie(tmdbId);
    });
  }

  private loadSimilarMovies(tmdbId: number): void {
    this.similarLoading.set(true);
    this.similarService.getSimilarMovies(tmdbId).subscribe({
      next: (response) => {
        this.similar.set(response.results ?? []);
        this.similarLoading.set(false);
      },
      error: () => {
        this.similar.set([]);
        this.similarLoading.set(false);
      }
    });
  }

  protected onSimilarSelect(tmdbId: number): void {
    if (!tmdbId) return;
    this.router.navigate(['/movies', tmdbId]);
  }

  protected toggleLike(): void {
    const movie = this.movieDetails();
    if (!movie) return;

    this.likeLoading.set(true);
    const next = !movie.liked;

    this.mediaListsService.setMovieLiked(movie.tmdbId, next).subscribe({
      next: (res) => {
        this.movieDetails.update((current) => current ? { ...current, liked: res.liked } : current);
        this.likeLoading.set(false);
      },
      error: () => {
        this.likeLoading.set(false);
      }
    });
  }

  protected toggleSeen(): void {
    const movie = this.movieDetails();
    if (!movie) return;

    this.seenLoading.set(true);
    const next = !movie.seen;

    this.mediaListsService.setMovieSeen(movie.id, next).subscribe({
      next: (res) => {
        this.movieDetails.update((current) => current ? { ...current, seen: res.seen } : current);
        this.seenLoading.set(false);
      },
      error: () => {
        this.seenLoading.set(false);
      }
    });
  }

  protected openListModal(): void {
    this.showListModal.set(true);
    this.listLoading.set(true);
    this.mediaListsService.getAll().subscribe({
      next: (data) => {
        this.lists.set(data);
        this.listLoading.set(false);
      },
      error: () => {
        this.listLoading.set(false);
      }
    });
  }

  protected closeListModal(): void {
    this.showListModal.set(false);
  }

  protected addToList(listId: number): void {
    const movie = this.movieDetails();
    if (!movie) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.addMovieToList(listId, movie.tmdbId).subscribe({
      next: () => {
        this.movieDetails.update(current => current ? { ...current, listIds: [...(current.listIds || []), listId] } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error adding movie to list:', err);
      }
    });
  }

  private fetchMovie(tmdbId: number): void {
    this.loading.set(true);
    this.error.set(null);
    this.movieDetails.set(undefined);

    this.mediaDetailsService.getMovieDetails(tmdbId).subscribe({
      next: (data) => {
        this.movieDetails.set(data);
        this.loading.set(false);
        this.setWatchlistState(data);
        this.loadRatingsIfNeeded(tmdbId, data);
        this.loadSimilarMovies(tmdbId);
        console.log(data)
      },
      error: () => {
        this.error.set('Erreur lors du chargement du film');
        this.loading.set(false);
      }
    });
  }

  // Determine watchlist id and whether movie is in it
  private setWatchlistState(movie: MovieDetails): void {
    this.mediaListsService.getAll().subscribe({
      next: (lists) => {
        this.lists.set(lists);
        const watch = lists.find(l => l.isSystem && l.name === 'Watchlist');
        if (watch) {
          this.watchlistId.set(watch.id);
          this.inWatchlist.set(!!movie.listIds?.includes(watch.id));
        } else {
          this.watchlistId.set(null);
          this.inWatchlist.set(false);
        }
      },
      error: () => {
        this.watchlistId.set(null);
        this.inWatchlist.set(false);
      }
    });
  }

  protected isInList(listId: number): boolean {
    const movie = this.movieDetails();
    return !!movie?.listIds?.includes(listId);
  }

  protected removeFromList(listId: number): void {
    const movie = this.movieDetails();
    if (!movie) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.removeMovieFromList(listId, movie.tmdbId).subscribe({
      next: () => {
        this.movieDetails.update(current => current ? { ...current, listIds: (current.listIds || []).filter(id => id !== listId) } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error removing movie from list:', err);
      }
    });
    
  }

  protected toggleWatchlist(): void {
    const movie = this.movieDetails();
    if (!movie) return;

    this.watchlistLoading.set(true);
    if (this.inWatchlist()) {
      this.mediaListsService.removeMovieFromWatchlist(movie.tmdbId).subscribe({
        next: () => {
          this.inWatchlist.set(false);
          // remove watchlist id from movie.listIds if known
          const wid = this.watchlistId();
          if (wid) {
            this.movieDetails.update(current => current ? { ...current, listIds: (current.listIds || []).filter(id => id !== wid) } : current);
          }
          this.watchlistLoading.set(false);
        },
        error: () => {
          this.watchlistLoading.set(false);
        }
      });
    } else {
      this.mediaListsService.addMovieToWatchlist(movie.tmdbId).subscribe({
        next: () => {
          this.inWatchlist.set(true);
          const wid = this.watchlistId();
          if (wid) {
            this.movieDetails.update(current => current ? { ...current, listIds: [...(current.listIds || []), wid] } : current);
          }
          this.watchlistLoading.set(false);
        },
        error: () => {
          this.watchlistLoading.set(false);
        }
      });
    }

  }

  protected tmdbRating(movie: MovieDetails): number | null {
    return movie.ratings?.tmdbRating ?? movie.voteAverage ?? null;
  }

  protected tmdbVotes(movie: MovieDetails): number | null {
    return movie.ratings?.tmdbVotes ?? movie.voteCount ?? null;
  }

  protected imdbRating(movie: MovieDetails): number | null {
    return movie.ratings?.imdbRating ?? null;
  }

  protected imdbVotes(movie: MovieDetails): number | null {
    return movie.ratings?.imdbVotes ?? null;
  }

  protected rottenRating(movie: MovieDetails): number | null {
    return movie.ratings?.rottenTomatoesRating ?? null;
  }

  private loadRatingsIfNeeded(tmdbId: number, movie: MovieDetails): void {
    if (!this.needsExternalRatings(movie)) {
      return;
    }

    this.mediaDetailsService.getMovieRatings(tmdbId).subscribe({
      next: (ratings) => {
        if (!ratings) return;
        this.movieDetails.update((current) => current ? { ...current, ratings } : current);
      },
      error: () => {
        // Fail silently; ratings are optional for initial render.
      }
    });
  }

  private needsExternalRatings(movie: MovieDetails): boolean {
    const ratings = movie.ratings;
    return !ratings || (ratings.imdbRating === null && ratings.rottenTomatoesRating === null);
  }
}
