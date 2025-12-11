import { Component, OnInit, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { InputTextModule } from 'primeng/inputtext';
import { MediaListsService, MediaListSearchItem } from '../../shared/services/media-lists.service';
import { MediaListSummary } from '../../shared/interfaces/media-list.interface';
import { MediaGrid, MediaItem } from './media-grid/media-grid';
import { forkJoin, Subscription } from 'rxjs';

type TabType = 'lists' | 'seen' | 'liked' | 'watchlist';

@Component({
  selector: 'app-listes',
  standalone: true,
  imports: [CommonModule, FormsModule, InputTextModule, MediaGrid],
  templateUrl: './listes.html',
  styleUrl: './listes.scss',
})
export class Listes implements OnInit {
  protected lists = signal<MediaListSummary[] | null>(null);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  protected activeTab = signal<TabType>('lists');
  protected selectedList = signal<MediaListSummary | null>(null);
  protected selectedListItems = signal<MediaItem[]>([]);
  protected loadingSelectedList = signal<boolean>(false);
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
  private selectedListPage = 1;
  private selectedListTotalPages = 1;
  private isLoadingMore = false;

  protected listSearchTerm: string = '';
  private listSearchPage = 1;
  private listSearchTotalPages = 1;
  private isSearchingList = false;
  private listSearchDebounce?: ReturnType<typeof setTimeout>;
  private listSearchSub?: Subscription;

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
      } else if (this.activeTab() === 'lists' && this.selectedList()) {
        if (this.isSearchingList && this.listSearchPage < this.listSearchTotalPages) {
          this.loadMoreSelectedListItems();
        } else if (!this.isSearchingList && this.selectedListPage < this.selectedListTotalPages) {
          this.loadMoreSelectedListItems();
        }
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

  protected onListSelect(list: MediaListSummary): void {
    if (this.selectedList()?.id === list.id && this.selectedListItems().length > 0) {
      return;
    }

    this.selectedList.set(list);
    this.selectedListPage = 1;
    this.selectedListTotalPages = 1;
    this.selectedListItems.set([]);
    this.resetListSearchState();
    this.fetchSelectedListItems(list.id);
  }

  protected clearSelectedList(): void {
    this.selectedList.set(null);
    this.selectedListItems.set([]);
    this.loadingSelectedList.set(false);
    this.isLoadingMore = false;
    this.selectedListPage = 1;
    this.selectedListTotalPages = 1;
    this.resetListSearchState();
  }

  protected onListSearchChange(value: string): void {
    this.listSearchTerm = value ?? '';
    const trimmed = this.listSearchTerm.trim();

    clearTimeout(this.listSearchDebounce);
    this.listSearchSub?.unsubscribe();

    if (!this.selectedList()) return;

    if (!trimmed) {
      this.resetListSearchState();
      this.fetchSelectedListItems(this.selectedList()!.id);
      return;
    }

    this.listSearchDebounce = setTimeout(() => this.searchSelectedListItems(trimmed), 250);
  }

  protected resetListSearch(): void {
    this.listSearchTerm = '';
    this.resetListSearchState();
    if (this.selectedList()) {
      this.fetchSelectedListItems(this.selectedList()!.id);
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

  private fetchSelectedListItems(listId: number): void {
    this.loadingSelectedList.set(true);
    this.isSearchingList = false;
    this.listSearchPage = 1;
    this.listSearchTotalPages = 1;
    this.listSearchSub?.unsubscribe();

    forkJoin({
      movies: this.mediaListsService.getListMovies(listId, this.selectedListPage),
      shows: this.mediaListsService.getListShows(listId, this.selectedListPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        this.selectedListTotalPages = Math.max(movies.totalPages, shows.totalPages);

        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
        }));

        this.selectedListItems.set([...movieItems, ...showItems]);
        this.loadingSelectedList.set(false);
      },
      error: () => {
        this.loadingSelectedList.set(false);
      }
    });
  }

  private searchSelectedListItems(query: string, page: number = 1, append: boolean = false): void {
    if (!this.selectedList()) return;

    const listId = this.selectedList()!.id;
    this.isSearchingList = true;
    if (!append) {
      this.loadingSelectedList.set(true);
      this.selectedListItems.set([]);
      this.listSearchPage = 1;
    } else {
      this.isLoadingMore = true;
    }

    this.listSearchSub?.unsubscribe();
    this.listSearchSub = this.mediaListsService.searchListItems(listId, query, page).subscribe({
      next: (response) => {
        const mapped: MediaItem[] = response.items.map((item: MediaListSearchItem) => ({
          id: item.id,
          tmdbId: item.tmdbId,
          title: item.title,
          posterPath: item.posterPath,
          releaseDate: item.releaseDate ?? null,
          voteAverage: item.voteAverage ?? null,
          type: item.mediaType,
          seen: item.seen
        }));

        this.listSearchPage = response.page;
        this.listSearchTotalPages = response.totalPages;

        if (append) {
          this.selectedListItems.set([...this.selectedListItems(), ...mapped]);
        } else {
          this.selectedListItems.set(mapped);
        }

        this.loadingSelectedList.set(false);
        this.isLoadingMore = false;
      },
      error: () => {
        if (append) {
          this.listSearchPage = Math.max(1, this.listSearchPage - 1);
        }
        this.loadingSelectedList.set(false);
        this.isLoadingMore = false;
      }
    });
  }

  private resetListSearchState(): void {
    this.isSearchingList = false;
    this.listSearchTerm = '';
    this.listSearchPage = 1;
    this.listSearchTotalPages = 1;
    clearTimeout(this.listSearchDebounce);
    this.listSearchSub?.unsubscribe();
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
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

  private loadMoreSelectedListItems(): void {
    if (this.isLoadingMore || !this.selectedList()) return;
    
    this.isLoadingMore = true;
    if (this.isSearchingList) {
      const nextPage = this.listSearchPage + 1;
      this.searchSelectedListItems(this.listSearchTerm.trim(), nextPage, true);
      return;
    }

    this.selectedListPage++;

    forkJoin({
      movies: this.mediaListsService.getListMovies(this.selectedList()!.id, this.selectedListPage),
      shows: this.mediaListsService.getListShows(this.selectedList()!.id, this.selectedListPage)
    }).subscribe({
      next: ({ movies, shows }) => {
        const movieItems: MediaItem[] = movies.items.map(movie => ({
          id: movie.id,
          tmdbId: movie.tmdbId,
          title: movie.title,
          posterPath: movie.posterPath,
          releaseDate: movie.releaseDate,
          voteAverage: movie.voteAverage,
          type: 'movie' as const,
          seen: movie.seen
        }));

        const showItems: MediaItem[] = shows.items.map(show => ({
          id: show.id,
          tmdbId: show.tmdbId,
          title: show.title,
          posterPath: show.posterPath,
          releaseDate: show.releaseDate,
          voteAverage: show.voteAverage,
          type: 'show' as const,
          seen: show.seen
        }));

        this.selectedListItems.set([...this.selectedListItems(), ...movieItems, ...showItems]);
        this.isLoadingMore = false;
      },
      error: () => {
        this.selectedListPage--;
        this.isLoadingMore = false;
      }
    });
  }
}
