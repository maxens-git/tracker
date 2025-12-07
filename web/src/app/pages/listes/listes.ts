import { Component, OnInit, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaListsService } from '../../shared/services/media-lists.service';
import { MediaListSummary } from '../../shared/interfaces/media-list.interface';
import { MovieDetails, ShowDetails } from '../../shared/interfaces/media-details.interface';
import { MediaGrid, MediaItem } from './media-grid/media-grid';
import { forkJoin } from 'rxjs';

type TabType = 'lists' | 'seen' | 'liked' | 'watchlist';

@Component({
  selector: 'app-listes',
  standalone: true,
  imports: [CommonModule, MediaGrid],
  templateUrl: './listes.html',
  styleUrl: './listes.scss',
})
export class Listes implements OnInit {
  protected lists = signal<MediaListSummary[] | null>(null);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  protected activeTab = signal<TabType>('lists');
  protected seenItems = signal<MediaItem[]>([]);
  protected likedItems = signal<MediaItem[]>([]);
  protected watchlistItems = signal<MediaItem[]>([]);
  protected loadingSeen = signal<boolean>(false);
  protected loadingLiked = signal<boolean>(false);
  protected loadingWatchlist = signal<boolean>(false);

  private seenPage = 1;
  private likedPage = 1;
  private watchlistPage = 1;
  private seenTotalPages = 1;
  private likedTotalPages = 1;
  private watchlistTotalPages = 1;
  private isLoadingMore = false;

  constructor(private mediaListsService: MediaListsService) {}

  ngOnInit(): void {
    this.fetchLists();
  }

  @HostListener('window:scroll')
  onScroll(): void {
    if (this.isLoadingMore) return;

    const scrollPosition = window.innerHeight + window.scrollY;
    const threshold = document.documentElement.scrollHeight - 500;

    if (scrollPosition >= threshold) {
      if (this.activeTab() === 'seen' && this.seenPage < this.seenTotalPages) {
        this.loadMoreSeen();
      } else if (this.activeTab() === 'liked' && this.likedPage < this.likedTotalPages) {
        this.loadMoreLiked();
      } else if (this.activeTab() === 'watchlist' && this.watchlistPage < this.watchlistTotalPages) {
        this.loadMoreWatchlist();
      }
    }
  }

  protected setActiveTab(tab: TabType): void {
    this.activeTab.set(tab);
    
    if (tab === 'seen' && this.seenItems().length === 0) {
      this.fetchSeenItems();
    } else if (tab === 'liked' && this.likedItems().length === 0) {
      this.fetchLikedItems();
    } else if (tab === 'watchlist' && this.watchlistItems().length === 0) {
      this.fetchWatchlistItems();
    }
  }

  private fetchLists(): void {
    this.loading.set(true);
    this.error.set(null);

    this.mediaListsService.getAll().subscribe({
      next: (data) => {
        this.lists.set(data);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossible de charger vos listes pour le moment.');
        this.loading.set(false);
      }
    });
  }

  private fetchSeenItems(): void {
    this.loadingSeen.set(true);
    this.seenPage = 1;

    forkJoin({
      movies: this.mediaListsService.getSeenMovies(this.seenPage),
      shows: this.mediaListsService.getSeenShows(this.seenPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        this.seenTotalPages = Math.max(movies.totalPages, shows.totalPages);

        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.seenItems.set([...movieItems, ...showItems]);
        this.loadingSeen.set(false);
      },
      error: () => {
        this.loadingSeen.set(false);
      }
    });
  }

  private loadMoreSeen(): void {
    if (this.isLoadingMore) return;
    
    this.isLoadingMore = true;
    this.seenPage++;

    forkJoin({
      movies: this.mediaListsService.getSeenMovies(this.seenPage),
      shows: this.mediaListsService.getSeenShows(this.seenPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.seenItems.set([...this.seenItems(), ...movieItems, ...showItems]);
        this.isLoadingMore = false;
      },
      error: () => {
        this.seenPage--;
        this.isLoadingMore = false;
      }
    });
  }

  private fetchLikedItems(): void {
    this.loadingLiked.set(true);
    this.likedPage = 1;

    forkJoin({
      movies: this.mediaListsService.getLikedMovies(this.likedPage),
      shows: this.mediaListsService.getLikedShows(this.likedPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        this.likedTotalPages = Math.max(movies.totalPages, shows.totalPages);

        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.likedItems.set([...movieItems, ...showItems]);
        this.loadingLiked.set(false);
      },
      error: () => {
        this.loadingLiked.set(false);
      }
    });
  }

  private fetchWatchlistItems(): void {
    this.loadingWatchlist.set(true);
    this.watchlistPage = 1;

    forkJoin({
      movies: this.mediaListsService.getWatchlistMovies(this.watchlistPage),
      shows: this.mediaListsService.getWatchlistShows(this.watchlistPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        this.watchlistTotalPages = Math.max(movies.totalPages, shows.totalPages);

        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.watchlistItems.set([...movieItems, ...showItems]);
        this.loadingWatchlist.set(false);
      },
      error: () => {
        this.loadingWatchlist.set(false);
      }
    });
  }

  private loadMoreLiked(): void {
    if (this.isLoadingMore) return;
    
    this.isLoadingMore = true;
    this.likedPage++;

    forkJoin({
      movies: this.mediaListsService.getLikedMovies(this.likedPage),
      shows: this.mediaListsService.getLikedShows(this.likedPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.likedItems.set([...this.likedItems(), ...movieItems, ...showItems]);
        this.isLoadingMore = false;
      },
      error: () => {
        this.likedPage--;
        this.isLoadingMore = false;
      }
    });
  }

  private loadMoreWatchlist(): void {
    if (this.isLoadingMore) return;
    
    this.isLoadingMore = true;
    this.watchlistPage++;

    forkJoin({
      movies: this.mediaListsService.getWatchlistMovies(this.watchlistPage),
      shows: this.mediaListsService.getWatchlistShows(this.watchlistPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const
        }));

        this.watchlistItems.set([...this.watchlistItems(), ...movieItems, ...showItems]);
        this.isLoadingMore = false;
      },
      error: () => {
        this.watchlistPage--;
        this.isLoadingMore = false;
      }
    });
  }
}
