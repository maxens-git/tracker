import { Component, inject, signal, OnInit, WritableSignal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable } from 'rxjs';
import { ButtonModule } from 'primeng/button';
import { TableModule } from 'primeng/table';
import { DialogModule } from 'primeng/dialog';
import { MultiSelectModule } from 'primeng/multiselect';
import { InputTextModule } from 'primeng/inputtext';
import { IconFieldModule } from 'primeng/iconfield';
import { InputIconModule } from 'primeng/inputicon';
import { Ripple } from 'primeng/ripple';
import { MessageService } from 'primeng/api';
import { Api, TorrentResult, DebridFile, Indexer, TorrentCategory } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';

@Component({
  selector: 'app-torrents',
  standalone: true,
  imports: [CommonModule, FormsModule, ButtonModule, TableModule, DialogModule, MultiSelectModule, InputTextModule, IconFieldModule, InputIconModule, Ripple, Spinner],
  templateUrl: './torrents.html',
  styleUrl: './torrents.scss',
})
export class Torrents implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  query = '';
  results = signal<TorrentResult[]>([]);
  loading = signal(false);
  searched = signal(false);

  // Indexeurs Prowlarr disponibles + ceux sélectionnés (vide = tous).
  indexers = signal<Indexer[]>([]);
  selectedIndexers: number[] = [];

  // Catégories Prowlarr disponibles + celle sélectionnée (null = toutes).
  categories = signal<TorrentCategory[]>([]);
  selectedCategory: number | null = null;

  // Magnet en cours de débridage (pour le spinner de la ligne).
  debriding = signal<string | null>(null);
  // Popup des liens débridés : visibilité, titre du torrent, fichiers.
  dialogVisible = signal(false);
  debridTitle = signal('');
  debridFiles = signal<DebridFile[]>([]);

  // Unlock à la demande : lien AllDebrid verrouillé en cours de résolution,
  // et liens directs déjà résolus (clé = lien verrouillé du fichier).
  unlockingLink = signal<string | null>(null);
  private resolved = signal<Record<string, string>>({});

  ngOnInit() {
    // Silencieux en cas d'échec : on peut toujours chercher sur « tous / toutes ».
    this.loadInto(this.api.torrentIndexers(), this.indexers);
    this.loadInto(this.api.torrentCategories(), this.categories);

    // Restaure l'état depuis l'URL (partage/rechargement) et relance la recherche.
    const params = this.route.snapshot.queryParamMap;
    this.query = params.get('q') ?? '';
    this.selectedIndexers = this.parseIdList(params.get('indexer'));
    this.selectedCategory = this.parseIdParam(params.get('category'));
    if (this.query.trim()) this.search();
  }

  private parseIdParam(raw: string | null): number | null {
    const id = Number(raw);
    return raw !== null && Number.isFinite(id) ? id : null;
  }

  private parseIdList(raw: string | null): number[] {
    if (!raw) return [];
    return raw.split(',').map(Number).filter(Number.isFinite);
  }

  private loadInto<T>(source$: Observable<T[]>, target: WritableSignal<T[]>) {
    source$.subscribe({
      next: items => target.set(items),
      error: () => target.set([]),
    });
  }

  // Relance la recherche quand on change d'indexeur ou de catégorie, si une requête est saisie.
  onFilterChange() {
    if (this.query.trim()) this.search();
  }

  // Reflète la requête et les filtres dans l'URL (sans empiler d'entrée d'historique).
  private syncQueryParams(q: string) {
    this.router.navigate([], {
      queryParams: {
        q,
        indexer: this.selectedIndexers.length ? this.selectedIndexers.join(',') : null,
        category: this.selectedCategory ?? null,
      },
      replaceUrl: true,
    });
  }

  search() {
    const q = this.query.trim();
    if (!q || this.loading()) return;

    this.loading.set(true);
    this.searched.set(true);
    this.debridFiles.set([]);
    this.syncQueryParams(q);

    this.api.searchTorrents(q, this.selectedIndexers, this.selectedCategory).subscribe({
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

    this.debriding.set(torrent.magnetUrl);

    this.api.debridMagnet(torrent.magnetUrl).subscribe({
      next: result => {
        this.debriding.set(null);
        if (result.files.length === 0) {
          this.showError('Aucun fichier débridable dans ce torrent.');
          return;
        }
        this.debridTitle.set(torrent.title);
        this.debridFiles.set(result.files);
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

  // Lien direct déjà résolu pour ce fichier (undefined tant qu'on n'a pas cliqué « Obtenir le lien »).
  resolvedLink(file: DebridFile): string | undefined {
    return this.resolved()[file.link];
  }

  // Débride un fichier précis à la demande (1 appel AllDebrid).
  resolve(file: DebridFile) {
    if (this.unlockingLink() || this.resolvedLink(file)) return;

    this.unlockingLink.set(file.link);
    this.api.unlockLink(file.link).subscribe({
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

  async copyLink(link: string) {
    try {
      await navigator.clipboard?.writeText(link);
      this.messages.add({ severity: 'success', summary: 'Torrents', detail: 'Lien copié.', life: 2500 });
    } catch {
      this.showError('Impossible de copier le lien.');
    }
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

  private messageFor(err: HttpErrorResponse, fallback: string): string {
    return typeof err.error === 'string' && err.error.trim() ? err.error : fallback;
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Torrents', detail, life: 5000 });
  }
}
