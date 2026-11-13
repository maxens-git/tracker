import { Component, DestroyRef, inject, signal, computed, OnInit, WritableSignal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, Subscription, from, of, concatMap, tap, catchError, finalize } from 'rxjs';
import { ButtonModule } from 'primeng/button';
import { TableModule } from 'primeng/table';
import { DialogModule } from 'primeng/dialog';
import { MultiSelectModule } from 'primeng/multiselect';
import { CheckboxModule } from 'primeng/checkbox';
import { InputTextModule } from 'primeng/inputtext';
import { IconFieldModule } from 'primeng/iconfield';
import { InputIconModule } from 'primeng/inputicon';
import { MessageService } from 'primeng/api';
import { Api, TorrentResult, TorrentBookmark, DebridFile, Indexer, TorrentCategory } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SelectModule } from 'primeng/select';
import { SelectButtonModule } from 'primeng/selectbutton';
import { TagModule } from 'primeng/tag';
import { ChipModule } from 'primeng/chip';
import { MessageModule } from 'primeng/message';
import { errorMessage } from '../../../shared/services/http-error';

@Component({
  selector: 'app-torrents',
  standalone: true,
  imports: [
    CommonModule, FormsModule, ButtonModule, TableModule, DialogModule, MultiSelectModule,
    CheckboxModule, InputTextModule, IconFieldModule, InputIconModule, Spinner,
    SelectModule, SelectButtonModule, TagModule, ChipModule, MessageModule,
  ],
  templateUrl: './torrents.html',
  styleUrl: './torrents.scss',
})
export class Torrents implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private destroyRef = inject(DestroyRef);
  private unlockRequest?: Subscription;
  private resolveAllRequest?: Subscription;

  query = '';
  results = signal<TorrentResult[]>([]);
  loading = signal(false);
  searched = signal(false);

  // Vue courante : marque-pages mis de côté par défaut (affichés à l'ouverture),
  // puis « résultats » dès qu'une recherche est lancée.
  view = signal<'results' | 'bookmarks'>('bookmarks');
  /** Onglets Résultats / Marque-pages du <p-selectButton>. */
  viewOptions = computed(() => [
    { label: 'Résultats', value: 'results' as const },
    { label: `Marque-pages (${this.bookmarks().length})`, value: 'bookmarks' as const },
  ]);
  // Marque-pages persistés en base (les plus récents en tête).
  bookmarks = signal<TorrentBookmark[]>([]);
  // Chargement initial des marque-pages (évite d'afficher « aucun marque-page »
  // avant que la réponse n'arrive, puis de basculer brutalement sur le tableau).
  bookmarksLoading = signal(true);
  // Marque-page en cours d'ajout/retrait (clé = magnetUrl) pour désactiver le bouton.
  bookmarking = signal<string | null>(null);
  // Torrents affichés dans le tableau selon la vue.
  displayed = computed<TorrentResult[]>(() =>
    this.view() === 'bookmarks' ? this.bookmarks() : this.results());

  // Indexeurs Prowlarr disponibles + ceux sélectionnés (vide = tous).
  indexers = signal<Indexer[]>([]);
  selectedIndexers: number[] = [];

  // Catégories Prowlarr disponibles + celle sélectionnée (null = toutes).
  categories = signal<TorrentCategory[]>([]);
  selectedCategory: number | null = null;

  // Magnet en cours de débridage (pour le spinner de la ligne).
  debriding = signal<string | null>(null);
  // Popup des liens débridés : visibilité, torrent source, fichiers.
  dialogVisible = signal(false);
  debridTorrent = signal<TorrentResult | null>(null);
  debridFiles = signal<DebridFile[]>([]);
  // Fichiers cochés (clé = lien verrouillé) sur lesquels portent les actions groupées.
  selectedFiles = signal<Set<string>>(new Set());

  // Taille totale des fichiers débridés (somme des tailles connues).
  totalDebridSize = computed(() => this.debridFiles().reduce((sum, f) => sum + (f.size || 0), 0));

  // Unlock à la demande : lien AllDebrid verrouillé en cours de résolution,
  // et liens directs déjà résolus (clé = lien verrouillé du fichier).
  unlockingLink = signal<string | null>(null);
  resolvingAll = signal(false);
  private resolved = signal<Record<string, string>>({});

  // Nombre de fichiers cochés (dénominateur de la progression « tout obtenir »).
  selectedCount = computed(() => this.debridFiles().filter(f => this.selectedFiles().has(f.link)).length);
  // Reste-t-il un fichier coché dont le lien n'a pas encore été obtenu ?
  hasUnresolved = computed(() =>
    this.debridFiles().some(f => this.selectedFiles().has(f.link) && !this.resolved()[f.link]));
  // Nombre de fichiers cochés déjà résolus (pour la progression du bouton « tout obtenir »).
  resolvedCount = computed(() =>
    this.debridFiles().filter(f => this.selectedFiles().has(f.link) && this.resolved()[f.link]).length);

  ngOnInit() {
    // Silencieux en cas d'échec : on peut toujours chercher sur « tous / toutes ».
    this.loadInto(this.api.torrentIndexers(), this.indexers);
    this.loadInto(this.api.torrentCategories(), this.categories);
    this.api.torrentBookmarks().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: bookmarks => {
        this.bookmarks.set(bookmarks);
        this.bookmarksLoading.set(false);
      },
      error: err => {
        this.bookmarks.set([]);
        this.bookmarksLoading.set(false);
        this.showError(errorMessage(err, 'Impossible de charger les marque-pages.'));
      },
    });

    // Restaure l'état depuis l'URL (partage/rechargement) et relance la recherche.
    const params = this.route.snapshot.queryParamMap;
    this.query = params.get('q') ?? '';
    this.selectedIndexers = this.parseIdList(params.get('indexer'));
    this.selectedCategory = this.parseIdParam(params.get('category'));
    if (this.query.trim()) this.search();
  }

  private parseIdParam(raw: string | null): number | null {
    const id = Number(raw);
    return raw !== null && raw.trim() !== '' && Number.isInteger(id) && id > 0 && id <= 2147483647 ? id : null;
  }

  private parseIdList(raw: string | null): number[] {
    if (!raw) return [];
    return [...new Set(raw.split(',').map(value => this.parseIdParam(value)).filter((id): id is number => id !== null))];
  }

  private loadInto<T>(source$: Observable<T[]>, target: WritableSignal<T[]>) {
    source$.pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: items => target.set(items),
      error: () => target.set([]),
    });
  }

  // Relance la recherche quand on change d'indexeur ou de catégorie, si une requête est saisie.
  onFilterChange() {
    if (this.query.trim()) this.search();
  }

  // Reflète la requête et les filtres dans l'URL (sans empiler d'entrée d'historique).
  // On met à jour l'URL via Location.replaceState plutôt que router.navigate : une
  // navigation relancerait le cycle du routeur, or ReloadRouteReuseStrategy
  // (shouldReuseRoute=false) + onSameUrlNavigation:'reload' détruiraient puis recréeraient
  // ce composant → nouvel ngOnInit → search → syncQueryParams → … boucle infinie d'appels API.
  private syncQueryParams(q: string) {
    const urlTree = this.router.createUrlTree([], {
      relativeTo: this.route,
      queryParams: {
        q,
        indexer: this.selectedIndexers.length ? this.selectedIndexers.join(',') : null,
        category: this.selectedCategory ?? null,
      },
    });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  search() {
    const q = this.query.trim();
    if (!q || this.loading()) return;

    this.loading.set(true);
    this.searched.set(true);
    this.view.set('results');
    this.debridFiles.set([]);
    this.syncQueryParams(q);

    this.api.searchTorrents(q, this.selectedIndexers, this.selectedCategory).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: results => {
        this.results.set(results);
        this.loading.set(false);
      },
      error: (err: HttpErrorResponse) => {
        this.results.set([]);
        this.loading.set(false);
        this.showError(this.messageFor(err, 'Recherche impossible.'));
      },
    });
  }

  debrid(torrent: TorrentResult) {
    if (this.debriding()) return;

    this.cancelLinkRequests();
    this.debriding.set(torrent.magnetUrl);

    this.api.debridMagnet(torrent.magnetUrl).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: result => {
        this.debriding.set(null);
        if (result.files.length === 0) {
          this.showError('Aucun fichier débridable dans ce torrent.');
          return;
        }
        this.debridTorrent.set(torrent);
        this.debridFiles.set(result.files);
        // Pré-sélection : tous les fichiers sauf les .nfo (métadonnées inutiles au téléchargement).
        this.selectedFiles.set(new Set(
          result.files.filter(f => this.fileExt(f.filename) !== 'NFO').map(f => f.link)));
        this.resolved.set({});
        this.unlockingLink.set(null);
        this.dialogVisible.set(true);
      },
      error: (err: HttpErrorResponse) => {
        this.debriding.set(null);
        // Le backend renvoie un message explicite (ex. 409 « non caché »), sinon message générique.
        this.showError(this.messageFor(err, 'Débridage impossible.'));
      },
    });
  }

  // ── Marque-pages ───────────────────────────────────────────────────────
  bookmarkFor(magnetUrl: string): TorrentBookmark | undefined {
    const key = this.magnetKey(magnetUrl);
    return this.bookmarks().find(b => this.magnetKey(b.magnetUrl) === key);
  }

  isBookmarked(magnetUrl: string): boolean {
    return this.bookmarkFor(magnetUrl) !== undefined;
  }

  // Même identité que l'API : xt/BTIH décodé, sans dépendre du nom ni des trackers.
  // Les liens sans hash reconnu ne sont équivalents que si leur texte est identique.
  private magnetKey(value: string): string {
    const magnet = value.trim();
    try {
      const url = new URL(magnet);
      for (const [name, topic] of url.searchParams) {
        if (name.toLowerCase() !== 'xt' || !/^urn:btih:/i.test(topic)) continue;
        const hash = topic.slice(9);
        if (/^[a-z0-9]{1,64}$/i.test(hash)) return `btih:${hash.toLowerCase()}`;
      }
    } catch { /* Un lien non standard reste identifié par son texte. */ }
    return `magnet:${magnet}`;
  }

  // Ajoute ou retire le torrent des marque-pages (mise à jour optimiste + rollback si échec).
  toggleBookmark(torrent: TorrentResult) {
    if (this.bookmarking() || this.bookmarksLoading()) return;
    this.bookmarking.set(torrent.magnetUrl);

    const existing = this.bookmarkFor(torrent.magnetUrl);
    if (existing) {
      this.bookmarks.update(list => list.filter(b => b.id !== existing.id));
      this.api.removeTorrentBookmark(existing.id).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: () => this.bookmarking.set(null),
        error: (err: HttpErrorResponse) => {
          this.bookmarks.update(list => [existing, ...list]); // rollback
          this.bookmarking.set(null);
          this.showError(this.messageFor(err, 'Impossible de retirer le marque-page.'));
        },
      });
    } else {
      this.api.addTorrentBookmark(torrent).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: saved => {
          // Dédup : le backend est idempotent, on n'ajoute pas deux fois le même.
          this.bookmarks.update(list =>
            list.some(b => b.id === saved.id) ? list : [saved, ...list]);
          this.bookmarking.set(null);
        },
        error: (err: HttpErrorResponse) => {
          this.bookmarking.set(null);
          this.showError(this.messageFor(err, 'Impossible d’ajouter le marque-page.'));
        },
      });
    }
  }

  // Retrait direct depuis la liste des marque-pages (sans passer par le dialog).
  removeBookmark(bookmark: TorrentBookmark) {
    if (this.bookmarking()) return;
    this.bookmarking.set(bookmark.magnetUrl);

    const index = this.bookmarks().findIndex(b => b.id === bookmark.id);
    this.bookmarks.update(list => list.filter(b => b.id !== bookmark.id));
    this.api.removeTorrentBookmark(bookmark.id).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: () => this.bookmarking.set(null),
      error: (err: HttpErrorResponse) => {
        this.bookmarks.update(list => {
          const next = [...list];
          next.splice(index < 0 ? next.length : index, 0, bookmark); // rollback à la position d'origine
          return next;
        });
        this.bookmarking.set(null);
        this.showError(this.messageFor(err, 'Impossible de retirer le marque-page.'));
      },
    });
  }

  // ── Sélection des fichiers (checkbox) ──────────────────────────────────
  isSelected(file: DebridFile): boolean {
    return this.selectedFiles().has(file.link);
  }

  toggleSelection(file: DebridFile, checked: boolean) {
    this.selectedFiles.update(set => {
      const next = new Set(set);
      if (checked) next.add(file.link); else next.delete(file.link);
      return next;
    });
  }

  // Lien direct déjà résolu pour ce fichier (undefined tant qu'on n'a pas cliqué « Obtenir le lien »).
  resolvedLink(file: DebridFile): string | undefined {
    return this.resolved()[file.link];
  }

  // Débride un fichier précis à la demande (1 appel AllDebrid).
  resolve(file: DebridFile) {
    if (this.unlockingLink() || this.resolvedLink(file)) return;

    this.unlockingLink.set(file.link);
    this.unlockRequest = this.api.unlockLink(file.link).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: ({ directLink }) => {
        this.resolved.update(map => ({ ...map, [file.link]: directLink }));
        this.unlockingLink.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.unlockingLink.set(null);
        this.showError(this.messageFor(err, 'Impossible d’obtenir le lien de téléchargement.'));
      },
    });
  }

  // Obtient le lien direct de tous les fichiers restants, séquentiellement
  // (un appel AllDebrid après l'autre, pour ne pas saturer l'API).
  resolveAll() {
    if (this.unlockingLink() || this.resolvingAll()) return;

    const pending = this.debridFiles().filter(f => this.isSelected(f) && !this.resolvedLink(f));
    if (pending.length === 0) return;

    this.resolvingAll.set(true);
    let failed = false;
    this.resolveAllRequest = from(pending).pipe(
      concatMap(file => {
        this.unlockingLink.set(file.link);
        return this.api.unlockLink(file.link).pipe(
          tap(({ directLink }) => this.resolved.update(map => ({ ...map, [file.link]: directLink }))),
          catchError(() => { failed = true; return of(null); }),
        );
      }),
      takeUntilDestroyed(this.destroyRef),
      finalize(() => {
        this.unlockingLink.set(null);
        this.resolvingAll.set(false);
      }),
    ).subscribe({
      complete: () => {
        if (failed && !this.destroyRef.destroyed) this.showError('Certains liens n’ont pas pu être obtenus.');
      },
    });
  }

  cancelLinkRequests() {
    this.unlockRequest?.unsubscribe();
    this.resolveAllRequest?.unsubscribe();
    this.unlockingLink.set(null);
    this.resolvingAll.set(false);
  }

  // Copie tous les liens directs déjà obtenus, un par ligne.
  async copyAll() {
    const links = this.debridFiles()
      .filter(f => this.isSelected(f))
      .map(f => this.resolvedLink(f))
      .filter((l): l is string => !!l);
    if (links.length === 0) return;

    try {
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(links.join('\n'));
      this.messages.add({ severity: 'success', summary: 'Torrents', detail: `${links.length} lien(s) copié(s).`, life: 2500 });
    } catch {
      this.showError('Impossible de copier les liens.');
    }
  }

  async copyLink(link: string) {
    try {
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(link);
      this.messages.add({ severity: 'success', summary: 'Torrents', detail: 'Lien copié.', life: 2500 });
    } catch {
      this.showError('Impossible de copier le lien.');
    }
  }

  // Copie le lien magnet brut : toujours disponible, même quand le débridage échoue.
  async copyMagnet(torrent: TorrentResult) {
    try {
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(torrent.magnetUrl);
      this.messages.add({ severity: 'success', summary: 'Torrents', detail: 'Lien magnet copié.', life: 2500 });
    } catch {
      this.showError('Impossible de copier le lien magnet.');
    }
  }

  // Les noms de release n'ont aucune espace : sans point de coupure, le navigateur
  // les tronque au milieu d'un mot. On insère des espaces de largeur nulle après les
  // séparateurs usuels (. _ - + ] )) pour que le retour à la ligne tombe entre deux
  // segments. Le texte reste identique visuellement, et l'attribut title garde l'original.
  breakable(text: string): string {
    return (text || '').replace(/[._\-+\])]/g, '$&\u200B');
  }

  // Extension de fichier en majuscules (ex. « MKV »), vide si aucune.
  fileExt(filename: string): string {
    const dot = filename.lastIndexOf('.');
    return dot > 0 && dot < filename.length - 1 ? filename.slice(dot + 1).toUpperCase() : '';
  }

  formatSize(bytes: number): string {
    if (!bytes || bytes < 0) return '—';
    const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
    let value = bytes;
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return `${value.toFixed(value >= 10 || unit === 0 ? 0 : 1)} ${units[unit]}`;
  }

  // Âge lisible et compact d'un torrent depuis sa date de publication (ex. « 3 j », « 5 mois »).
  formatAge(publishDate: string | null): string {
    if (!publishDate) return '—';
    const published = new Date(publishDate).getTime();
    if (Number.isNaN(published)) return '—';

    const hours = Math.floor((Date.now() - published) / 3_600_000);
    if (hours < 1) return '< 1 h';
    if (hours < 24) return `${hours} h`;

    const days = Math.floor(hours / 24);
    if (days < 30) return `${days} j`;
    if (days < 365) return `${Math.floor(days / 30)} mois`;

    const years = Math.floor(days / 365);
    return `${years} an${years > 1 ? 's' : ''}`;
  }

  private messageFor(err: HttpErrorResponse, fallback: string): string {
    return errorMessage(err, fallback);
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Torrents', detail, life: 5000 });
  }
}
