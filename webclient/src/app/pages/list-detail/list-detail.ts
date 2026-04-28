import { Component, inject, signal, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged, switchMap } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { MediaListSummary, MediaListSearchItem } from '../../../shared/interfaces/list';
import { MediaItem } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';

function toMediaItem(i: MediaListSearchItem): MediaItem {
  const isMovie = i.mediaType === 'movie';
  return {
    id: i.tmdbId,
    media_type: isMovie ? 'movie' : 'tv',
    title: isMovie ? i.title : undefined,
    name: isMovie ? undefined : i.title,
    poster_path: i.posterPath,
    release_date: isMovie ? i.releaseDate : undefined,
    first_air_date: isMovie ? undefined : i.releaseDate,
    vote_average: i.voteAverage ?? 0,
    vote_count: 0,
    popularity: i.popularity ?? 0,
    seen: i.seen,
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

  items = signal<MediaItem[]>([]);
  page = signal(1);
  totalPages = signal(1);
  totalCount = signal(0);
  loading = signal(false);

  query = '';
  private search$ = new Subject<string>();

  ngOnInit() {
    this.listId = Number(this.route.snapshot.paramMap.get('id'));

    this.api.list(this.listId).subscribe({
      next: data => { this.list.set(data); this.loadingList.set(false); },
      error: () => this.loadingList.set(false),
    });

    this.search$.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(q => {
        this.loading.set(true);
        return this.api.searchList(this.listId, q, 1);
      }),
    ).subscribe({
      next: r => {
        this.items.set(r.items.map(toMediaItem));
        this.page.set(r.page);
        this.totalPages.set(r.totalPages);
        this.totalCount.set(r.totalCount);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    this.search$.next('');
  }

  onSearchInput() { this.search$.next(this.query); }

  loadPage(p: number) {
    this.loading.set(true);
    this.api.searchList(this.listId, this.query, p).subscribe({
      next: r => {
        this.items.set(r.items.map(toMediaItem));
        this.page.set(r.page);
        this.totalPages.set(r.totalPages);
        this.loading.set(false);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      },
      error: () => this.loading.set(false),
    });
  }

  listIcon(): string {
    const l = this.list();
    if (!l) return '';
    return l.icon ?? l.name.charAt(0).toUpperCase();
  }

  pages(): number[] {
    return Array.from({ length: this.totalPages() }, (_, i) => i + 1);
  }
}
