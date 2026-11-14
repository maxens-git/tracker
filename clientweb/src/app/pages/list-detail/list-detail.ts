import { Component, DestroyRef, inject, signal, OnInit } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { errorMessage } from '../../../shared/services/http-error';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { of, from, map, switchMap, concatMap, reduce, firstValueFrom, Subscription, Subject, debounceTime } from 'rxjs';
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
import { MessageService } from 'primeng/api';
import { SYSTEM_LIST_BY_SLUG } from '../../../shared/constants';

type SystemListSlug = keyof typeof SYSTEM_LIST_BY_SLUG;

/** Nombre de fiches TMDB résolues en parallèle lors de la copie des titres. */
const CHUNK_SIZE = 20;

@Component({
  selector: 'app-list-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, PosterCard, Spinner, PaginatorModule, IconFieldModule, InputIconModule, InputTextModule, ButtonModule, TagModule, MessageModule],
  templateUrl: './list-detail.html',
  styleUrl: './list-detail.scss',
})
export class ListDetail implements OnInit {
  private api = inject(Api);
  private destroyRef = inject(DestroyRef);
  private pageRequest?: Subscription;
  private searchChanges = new Subject<void>();
  private tmdb = inject(TmdbService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private messages = inject(MessageService);

  listId: number | SystemListSlug = 0;
  list = signal<MediaListSummary | null>(null);
  loadingList = signal(true);
  listError = signal<string | null>(null);
  pageError = signal<string | null>(null);

  items = signal<MediaItem[]>([]);
  page = signal(1);
  pageSize = signal(20);
  totalPages = signal(1);
  totalCount = signal(0);
  loading = signal(false);

  query = '';
  copying = signal(false);

  constructor() {
    this.searchChanges.pipe(
      debounceTime(300),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe(() => this.loadPage(1));
  }

  ngOnInit() {
    const idParam = this.route.snapshot.paramMap.get('id')!;
    const numId = Number(idParam);
    const systemSlug = Object.hasOwn(SYSTEM_LIST_BY_SLUG, idParam);
    if (!systemSlug && (!Number.isInteger(numId) || numId < 1 || numId > 2147483647)) {
      this.loadingList.set(false);
      this.listError.set('Liste introuvable.');
      return;
    }
    this.listId = systemSlug ? idParam as SystemListSlug : numId;

    if (typeof this.listId === 'number') {
      this.api.list(this.listId).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: data => { this.list.set(data); this.loadingList.set(false); },
        error: err => { this.listError.set(errorMessage(err, 'Impossible de charger la liste.')); this.loadingList.set(false); },
      });
    } else {
      const name = SYSTEM_LIST_BY_SLUG[this.listId];
      this.api.lists().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: lists => {
          this.list.set(lists.find(l => l.isSystem && l.name === name) ?? null);
          this.loadingList.set(false);
          if (!this.list()) this.listError.set('Liste introuvable.');
        },
        error: err => { this.listError.set(errorMessage(err, 'Impossible de charger la liste.')); this.loadingList.set(false); },
      });
    }

    // Restaure la recherche et sa page depuis l'URL (partage/rechargement).
    this.query = (this.route.snapshot.queryParamMap.get('search') ?? '').trim();
    const initialPage = Number(this.route.snapshot.queryParamMap.get('page')) || 1;
    this.loadPage(initialPage);
  }

  onQueryChange(value: string) {
    const previous = this.query.trim();
    this.query = value;
    if (value.trim() === previous) return;

    // Annule aussi l'enrichissement TMDB en cours dès la saisie, avant le délai.
    this.pageRequest?.unsubscribe();
    this.page.set(1);
    this.loading.set(true);
    this.pageError.set(null);
    this.searchChanges.next();
  }

  loadPage(p: number) {
    this.pageRequest?.unsubscribe();
    p = Number.isFinite(p) ? Math.min(2147483647, Math.max(1, Math.trunc(p))) : 1;
    const search = this.query.trim();
    this.loading.set(true);
    this.pageError.set(null);
    this.pageRequest = this.api.listItems(this.listId, p, 'all', search).pipe(
      switchMap(result => result.totalPages > 0 && result.page > result.totalPages
        ? this.api.listItems(this.listId, result.totalPages, 'all', search)
        : of(result)),
      // La liste backend ne contient que des références (tmdbId + état) :
      // on charge les fiches TMDB correspondantes puis on recopie les états dessus.
      switchMap(result => {
        this.page.set(result.page);
        this.pageSize.set(result.pageSize);
        this.totalPages.set(result.totalPages);
        this.totalCount.set(result.totalCount);
        this.syncPageParam(result.page, search);

        if (result.items.length === 0) return of([] as MediaItem[]);

        const refs = result.items.map(i => ({ tmdbId: i.tmdbId, mediaType: i.mediaType }));
        const stateByTmdbId = new Map(result.items.map(i => [`${i.mediaType === 'movie' ? 'movie' : 'tv'}:${i.tmdbId}`, i]));

        return this.tmdb.fetchMany(refs).pipe(
          map(tmdbItems => tmdbItems.map(item => {
            const state = stateByTmdbId.get(`${item.media_type}:${item.id}`);
            return { ...item, seen: state?.seen ?? false, watchCount: state?.watchCount ?? 0, liked: state?.liked ?? false };
          })),
        );
      }),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe({
      next: items => {
        this.items.set(items);
        this.loading.set(false);
        if (items.length > 0) window.scrollTo({ top: 0, behavior: 'smooth' });
      },
      error: err => { this.items.set([]); this.pageError.set(errorMessage(err, 'Impossible de charger les éléments.')); this.loading.set(false); },
    });
  }

  // Reflète la recherche et sa page dans l'URL, sans empiler d'historique.
  // On met à jour l'URL via Location.replaceState plutôt que router.navigate : une
  // navigation relancerait le cycle du routeur, or ReloadRouteReuseStrategy
  // (shouldReuseRoute=false) détruirait puis recréerait ce composant → nouvel ngOnInit
  // → loadPage → syncPageParam → … boucle infinie d'appels API.
  private syncPageParam(p: number, search: string) {
    const urlTree = this.router.createUrlTree([], {
      relativeTo: this.route,
      queryParams: { page: p > 1 ? p : null, search: search || null },
      queryParamsHandling: 'merge',
    });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  /**
   * Copie les titres de toute la liste — pas seulement la page affichée.
   * Le backend stocke désormais le titre à l'ajout (voir MediaListItem.Title),
   * donc la plupart des items n'ont besoin d'aucun appel TMDB. Seuls les items
   * ajoutés avant l'introduction de ce champ (titre manquant côté backend) sont
   * résolus via TMDB, par paquets de 20 (concatMap) pour ne pas envoyer des
   * centaines de requêtes simultanées sur une grande liste ancienne.
   * Les pages backend sont elles aussi parcourues séquentiellement (concatMap).
   */
  copyAllTitles() {
    if (this.copying()) return;
    this.copying.set(true);

    const titles$ = this.api.listItems(this.listId, 1).pipe(
      switchMap(first => {
        const remainingPages = Array.from(
          { length: Math.max(0, first.totalPages - 1) },
          (_, i) => i + 2,
        );
        if (remainingPages.length === 0) return of([first]);
        return from(remainingPages).pipe(
          concatMap(p => this.api.listItems(this.listId, p)),
          reduce((all, page) => [...all, page], [first]),
        );
      }),
      map(pages => pages.flatMap(p => p.items)),
      switchMap(items => {
        const known = items.map(i => (i.title ?? '').trim()).filter(t => t.length > 0);
        const missing = items.filter(i => !i.title?.trim());

        if (missing.length === 0) return of(known);

        const refs = missing.map(i => ({ tmdbId: i.tmdbId, mediaType: i.mediaType }));
        const chunks: typeof refs[] = [];
        for (let i = 0; i < refs.length; i += CHUNK_SIZE) chunks.push(refs.slice(i, i + CHUNK_SIZE));
        return from(chunks).pipe(
          concatMap(chunk => this.tmdb.fetchMany(chunk)),
          reduce((all, batch) => [...all, ...batch], [] as MediaItem[]),
          map(resolved => [...known, ...resolved.map(i => i.title ?? i.name ?? '').filter(t => t.length > 0)]),
        );
      }),
    );

    const titlesPromise = firstValueFrom(titles$);

    // Sur une grande liste, réunir toutes les pages + résoudre les titres manquants peut
    // prendre plusieurs secondes — largement au-delà de la fenêtre d'« activation
    // utilisateur » que les navigateurs exigent pour un clipboard.writeText() tardif
    // (sinon : NotAllowedError, capté plus bas par "Impossible de copier les titres").
    // Pour rester dans le geste de clic, on écrit tout de suite un ClipboardItem dont le
    // contenu est une promesse : le navigateur valide la permission maintenant et ne
    // résout le contenu réel qu'une fois les titres prêts.
    const supportsAsyncClipboardItem =
      typeof ClipboardItem !== 'undefined' && typeof navigator.clipboard?.write === 'function';

    let clipboardPromise: Promise<void>;
    try {
      clipboardPromise = supportsAsyncClipboardItem
        ? navigator.clipboard.write([
            new ClipboardItem({
              'text/plain': titlesPromise.then(titles => new Blob([titles.join('\n')], { type: 'text/plain' })),
            }),
          ])
        : titlesPromise.then(titles => navigator.clipboard.writeText(titles.join('\n')));
    } catch {
      titlesPromise.catch(() => {});
      this.copying.set(false);
      this.messages.add({ severity: 'error', summary: 'Listes', detail: 'Impossible de copier les titres.', life: 3500 });
      return;
    }
    clipboardPromise.catch(() => {}); // géré via titlesPromise ci-dessous ; évite un rejet non capté si le fetch échoue.

    titlesPromise.then(
      titles => {
        clipboardPromise.then(
          () => {
            this.copying.set(false);

            if (titles.length === 0) {
              this.messages.add({ severity: 'info', summary: 'Listes', detail: 'Aucun titre à copier.', life: 2500 });
              return;
            }

            this.messages.add({
              severity: 'success',
              summary: 'Listes',
              detail: `${titles.length} titre${titles.length !== 1 ? 's' : ''} copié${titles.length !== 1 ? 's' : ''}.`,
              life: 2500,
            });
          },
          () => {
            this.copying.set(false);
            this.messages.add({ severity: 'error', summary: 'Listes', detail: 'Impossible de copier les titres.', life: 3500 });
          },
        );
      },
      () => {
        this.copying.set(false);
        this.messages.add({ severity: 'error', summary: 'Listes', detail: 'Impossible de récupérer les titres de la liste.', life: 3500 });
      },
    );
  }

  /** Index du premier élément de la page courante, pour <p-paginator>. */
  firstRecord(): number {
    return (this.page() - 1) * this.pageSize();
  }
}
