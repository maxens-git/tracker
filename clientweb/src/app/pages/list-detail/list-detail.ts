import { Component, inject, signal, OnInit } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { of, map, switchMap } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { MediaItem } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { PaginatorModule } from 'primeng/paginator';
import { IconFieldModule } from 'primeng/iconfield';
import { InputIconModule } from 'primeng/inputicon';
import { InputTextModule } from 'primeng/inputtext';
import { ButtonModule } from 'primeng/button';
import { TagModule } from 'primeng/tag';
import { MessageModule } from 'primeng/message';
import { SYSTEM_LIST_BY_SLUG } from '../../../shared/constants';

type SystemListSlug = keyof typeof SYSTEM_LIST_BY_SLUG;

@Component({
  selector: 'app-list-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, PosterCard, Spinner, PaginatorModule, IconFieldModule, InputIconModule, InputTextModule, ButtonModule, TagModule, MessageModule],
  templateUrl: './list-detail.html',
  styleUrl: './list-detail.scss',
})
export class ListDetail implements OnInit {
  private api = inject(Api);
  private tmdb = inject(TmdbService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);

  listId: number | SystemListSlug = 0;
  list = signal<MediaListSummary | null>(null);
  loadingList = signal(true);

  items = signal<MediaItem[]>([]);
  page = signal(1);
  pageSize = signal(20);
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

    // Restaure la page depuis l'URL (partage/rechargement), 1 par défaut.
    const initialPage = Number(this.route.snapshot.queryParamMap.get('page')) || 1;
    this.loadPage(initialPage);
  }

  loadPage(p: number) {
    this.loading.set(true);
    this.api.listItems(this.listId, p).pipe(
      // La liste backend ne contient que des références (tmdbId + état) :
      // on charge les fiches TMDB correspondantes puis on recopie les états dessus.
      switchMap(result => {
        this.page.set(result.page);
        this.pageSize.set(result.pageSize);
        this.totalPages.set(result.totalPages);
        this.totalCount.set(result.totalCount);
        this.syncPageParam(result.page);

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

  // Reflète la page courante dans l'URL (page 1 → param retiré), sans empiler d'historique.
  // On met à jour l'URL via Location.replaceState plutôt que router.navigate : une
  // navigation relancerait le cycle du routeur, or ReloadRouteReuseStrategy
  // (shouldReuseRoute=false) détruirait puis recréerait ce composant → nouvel ngOnInit
  // → loadPage → syncPageParam → … boucle infinie d'appels API.
  private syncPageParam(p: number) {
    const urlTree = this.router.createUrlTree([], {
      relativeTo: this.route,
      queryParams: { page: p > 1 ? p : null },
      queryParamsHandling: 'merge',
    });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  get filteredItems(): MediaItem[] {
    const q = this.query.trim().toLowerCase();
    if (!q) return this.items();
    return this.items().filter(i =>
      (i.title ?? i.name ?? '').toLowerCase().includes(q)
    );
  }

  /** Index du premier élément de la page courante, pour <p-paginator>. */
  firstRecord(): number {
    return (this.page() - 1) * this.pageSize();
  }
}
