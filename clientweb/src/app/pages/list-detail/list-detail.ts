import { Component, inject, signal, OnInit } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { of, forkJoin, from, map, switchMap, concatMap, reduce } from 'rxjs';
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
import { TooltipModule } from 'primeng/tooltip';
import { MessageService } from 'primeng/api';
import { SYSTEM_LIST_BY_SLUG } from '../../../shared/constants';

type SystemListSlug = keyof typeof SYSTEM_LIST_BY_SLUG;

/** Nombre de fiches TMDB résolues en parallèle lors de la copie des titres. */
const CHUNK_SIZE = 20;

@Component({
  selector: 'app-list-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, PosterCard, Spinner, PaginatorModule, IconFieldModule, InputIconModule, InputTextModule, ButtonModule, TagModule, MessageModule, TooltipModule],
  templateUrl: './list-detail.html',
  styleUrl: './list-detail.scss',
})
export class ListDetail implements OnInit {
  private api = inject(Api);
  private tmdb = inject(TmdbService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private messages = inject(MessageService);

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
  copying = signal(false);

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

  /**
   * Copie les titres de toute la liste — pas seulement la page affichée.
   * Le backend ne renvoie que des références (tmdbId), et sa pagination est
   * figée à 20 : on parcourt donc toutes les pages, puis on résout les fiches
   * TMDB par paquets de 20 (via concatMap) pour éviter d'envoyer des centaines
   * de requêtes simultanées sur une grande liste.
   */
  copyAllTitles() {
    if (this.copying()) return;
    this.copying.set(true);

    this.api.listItems(this.listId, 1).pipe(
      switchMap(first => {
        const rest = Array.from(
          { length: Math.max(0, first.totalPages - 1) },
          (_, i) => this.api.listItems(this.listId, i + 2),
        );
        return rest.length === 0 ? of([first]) : forkJoin([of(first), ...rest]);
      }),
      map(pages => pages.flatMap(p => p.items.map(i => ({ tmdbId: i.tmdbId, mediaType: i.mediaType })))),
      switchMap(refs => {
        if (refs.length === 0) return of([] as MediaItem[]);
        const chunks: typeof refs[] = [];
        for (let i = 0; i < refs.length; i += CHUNK_SIZE) chunks.push(refs.slice(i, i + CHUNK_SIZE));
        return from(chunks).pipe(
          concatMap(chunk => this.tmdb.fetchMany(chunk)),
          reduce((all, batch) => [...all, ...batch], [] as MediaItem[]),
        );
      }),
    ).subscribe({
      next: async items => {
        const titles = items.map(i => i.title ?? i.name ?? '').filter(t => t.length > 0);
        this.copying.set(false);

        if (titles.length === 0) {
          this.messages.add({ severity: 'info', summary: 'Listes', detail: 'Aucun titre à copier.', life: 2500 });
          return;
        }

        try {
          await navigator.clipboard?.writeText(titles.join('\n'));
          this.messages.add({
            severity: 'success',
            summary: 'Listes',
            detail: `${titles.length} titre${titles.length !== 1 ? 's' : ''} copié${titles.length !== 1 ? 's' : ''}.`,
            life: 2500,
          });
        } catch {
          this.messages.add({ severity: 'error', summary: 'Listes', detail: 'Impossible de copier les titres.', life: 3500 });
        }
      },
      error: () => {
        this.copying.set(false);
        this.messages.add({ severity: 'error', summary: 'Listes', detail: 'Impossible de récupérer les titres de la liste.', life: 3500 });
      },
    });
  }

  /** Index du premier élément de la page courante, pour <p-paginator>. */
  firstRecord(): number {
    return (this.page() - 1) * this.pageSize();
  }
}
