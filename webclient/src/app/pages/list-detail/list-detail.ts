import { Component, inject, signal, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged, switchMap, of, forkJoin } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { MediaListSummary, PaginatedResult, MediaListSearchItem } from '../../../shared/interfaces/list';
import { MediaItem } from '../../../shared/interfaces/media';
import { MovieDto } from '../../../shared/interfaces/movie';
import { ShowDto } from '../../../shared/interfaces/show';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';

function movieToItem(m: MovieDto): MediaItem {
  return {
    id: m.tmdbId, media_type: 'movie', title: m.title,
    poster_path: m.posterPath, release_date: m.releaseDate,
    vote_average: m.voteAverage, vote_count: m.voteCount,
    popularity: m.popularity, seen: m.seen,
  };
}

function showToItem(s: ShowDto): MediaItem {
  return {
    id: s.tmdbId, media_type: 'tv', name: s.title,
    poster_path: s.posterPath, first_air_date: s.releaseDate,
    vote_average: s.voteAverage, vote_count: s.voteCount,
    popularity: s.popularity, seen: s.seen,
  };
}

function searchItemToItem(i: MediaListSearchItem): MediaItem {
  const isMovie = i.mediaType === 'movie';
  return {
    id: i.tmdbId, media_type: isMovie ? 'movie' : 'tv',
    title: isMovie ? i.title : undefined,
    name: isMovie ? undefined : i.title,
    poster_path: i.posterPath,
    release_date: isMovie ? i.releaseDate : undefined,
    first_air_date: isMovie ? undefined : i.releaseDate,
    vote_average: i.voteAverage ?? 0, vote_count: 0,
    popularity: i.popularity ?? 0, seen: i.seen,
  };
}

@Component({
  selector: 'app-list-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, PosterCard, Spinner],
  templateUrl: './list-detail.html',
  styleUrl: './list-detail.scss',
})
export class ListDetail implements OnInit {
  private api = inject(Api);
  private route = inject(ActivatedRoute);

  listId = 0;

  list = signal<MediaListSummary | null>(null);
  loadingList = signal(true);

  movies = signal<MediaItem[]>([]);
  moviesPage = signal(1);
  moviesTotalPages = signal(1);
  moviesTotalCount = signal(0);
  loadingMovies = signal(false);

  shows = signal<MediaItem[]>([]);
  showsPage = signal(1);
  showsTotalPages = signal(1);
  showsTotalCount = signal(0);
  loadingShows = signal(false);

  query = '';
  searchResults = signal<MediaItem[]>([]);
  searchPage = signal(1);
  searchTotalPages = signal(1);
  searchTotalCount = signal(0);
  loadingSearch = signal(false);
  isSearching = signal(false);

  private search$ = new Subject<string>();

  ngOnInit() {
    this.listId = Number(this.route.snapshot.paramMap.get('id'));

    this.api.list(this.listId).subscribe({
      next: data => { this.list.set(data); this.loadingList.set(false); },
      error: () => this.loadingList.set(false),
    });

    this.loadMovies(1);
    this.loadShows(1);

    this.search$.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(q => {
        if (!q.trim()) {
          this.isSearching.set(false);
          this.searchResults.set([]);
          return of(null);
        }
        this.isSearching.set(true);
        this.loadingSearch.set(true);
        return this.api.searchList(this.listId, q, 1);
      }),
    ).subscribe({
      next: r => {
        if (!r) return;
        this.searchResults.set(r.items.map(searchItemToItem));
        this.searchPage.set(r.page);
        this.searchTotalPages.set(r.totalPages);
        this.searchTotalCount.set(r.totalCount);
        this.loadingSearch.set(false);
      },
      error: () => this.loadingSearch.set(false),
    });
  }

  onSearchInput() { this.search$.next(this.query); }

  loadMovies(page: number) {
    this.loadingMovies.set(true);
    this.api.listMovies(this.listId, page).subscribe({
      next: (r: PaginatedResult<MovieDto>) => {
        this.movies.set(r.items.map(movieToItem));
        this.moviesPage.set(r.page);
        this.moviesTotalPages.set(r.totalPages);
        this.moviesTotalCount.set(r.totalCount);
        this.loadingMovies.set(false);
      },
      error: () => this.loadingMovies.set(false),
    });
  }

  loadShows(page: number) {
    this.loadingShows.set(true);
    this.api.listShows(this.listId, page).subscribe({
      next: (r: PaginatedResult<ShowDto>) => {
        this.shows.set(r.items.map(showToItem));
        this.showsPage.set(r.page);
        this.showsTotalPages.set(r.totalPages);
        this.showsTotalCount.set(r.totalCount);
        this.loadingShows.set(false);
      },
      error: () => this.loadingShows.set(false),
    });
  }

  loadSearchPage(page: number) {
    if (!this.query.trim()) return;
    this.loadingSearch.set(true);
    this.api.searchList(this.listId, this.query, page).subscribe({
      next: r => {
        this.searchResults.set(r.items.map(searchItemToItem));
        this.searchPage.set(r.page);
        this.searchTotalPages.set(r.totalPages);
        this.loadingSearch.set(false);
      },
      error: () => this.loadingSearch.set(false),
    });
  }

  listIcon(): string {
    const l = this.list();
    if (!l) return '';
    return l.icon ?? l.name.charAt(0).toUpperCase();
  }

  pages(total: number): number[] {
    return Array.from({ length: total }, (_, i) => i + 1);
  }
}
