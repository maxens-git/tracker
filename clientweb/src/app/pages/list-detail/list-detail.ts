import { Component, inject, signal, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { of, map, switchMap } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { MediaItem } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SYSTEM_LIST_BY_SLUG } from '../../../shared/constants';

type SystemListSlug = keyof typeof SYSTEM_LIST_BY_SLUG;

@Component({
  selector: 'app-list-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, PosterCard, Spinner],
  templateUrl: './list-detail.html',
  styleUrl: './list-detail.scss',
})
export class ListDetail implements OnInit {
  private api = inject(Api);
  private tmdb = inject(TmdbService);
  private route = inject(ActivatedRoute);

  listId: number | SystemListSlug = 0;
  list = signal<MediaListSummary | null>(null);
  loadingList = signal(true);

  items = signal<MediaItem[]>([]);
  page = signal(1);
  totalPages = signal(1);
  totalCount = signal(0);
  loading = signal(false);

  query = '';

  ngOnInit() {
    const idParam = this.route.snapshot.paramMap.get('id')!;
    const numId = Number(idParam);
    this.listId = isNaN(numId) ? (idParam as SystemListSlug) : numId;

    if (typeof this.listId === 'number') {
      this.api.list(this.listId).subscribe({
        next: data => { this.list.set(data); this.loadingList.set(false); },
        error: () => this.loadingList.set(false),
      });
    } else {
      const name = SYSTEM_LIST_BY_SLUG[this.listId];
      this.api.lists().subscribe({
        next: lists => {
          this.list.set(lists.find(l => l.name === name) ?? null);
          this.loadingList.set(false);
        },
        error: () => this.loadingList.set(false),
      });
    }

    this.loadPage(1);
  }

  loadPage(p: number) {
    this.loading.set(true);
    this.api.listItems(this.listId, p).pipe(
      // La liste backend ne contient que des références (tmdbId + état) :
      // on charge les fiches TMDB correspondantes puis on recopie les états dessus.
      switchMap(result => {
        this.page.set(result.page);
        this.totalPages.set(result.totalPages);
        this.totalCount.set(result.totalCount);

        if (result.items.length === 0) return of([] as MediaItem[]);

        const refs = result.items.map(i => ({ tmdbId: i.tmdbId, mediaType: i.mediaType }));
        const stateByTmdbId = new Map(result.items.map(i => [i.tmdbId, i]));

        return this.tmdb.fetchMany(refs).pipe(
          map(tmdbItems => tmdbItems.map(item => {
            const state = stateByTmdbId.get(item.id);
            return { ...item, seen: state?.seen ?? false, liked: state?.liked ?? false };
          })),
        );
      }),
    ).subscribe({
      next: items => {
        this.items.set(items);
        this.loading.set(false);
        if (items.length > 0) window.scrollTo({ top: 0, behavior: 'smooth' });
      },
      error: () => this.loading.set(false),
    });
  }

  get filteredItems(): MediaItem[] {
    const q = this.query.trim().toLowerCase();
    if (!q) return this.items();
    return this.items().filter(i =>
      (i.title ?? i.name ?? '').toLowerCase().includes(q)
    );
  }

  listIcon(): string {
    const l = this.list();
    if (!l) return '';
    return l.icon ?? l.name.charAt(0).toUpperCase();
  }

  /**
   * Pages à afficher autour de la page courante, avec 0 comme marqueur d'ellipsis (…).
   * Ex. (courante 7 / 60) → [1, 0, 6, 7, 8, 0, 60].
   */
  pageList(): number[] {
    const total = this.totalPages();
    const current = this.page();
    const delta = 1; // nombre de pages de part et d'autre de la courante
    const left = Math.max(2, current - delta);
    const right = Math.min(total - 1, current + delta);

    const range: number[] = [1];
    if (left > 2) range.push(0);
    for (let i = left; i <= right; i++) range.push(i);
    if (right < total - 1) range.push(0);
    if (total > 1) range.push(total);
    return range;
  }
}
