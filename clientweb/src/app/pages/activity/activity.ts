import { Component, inject, signal, OnInit } from '@angular/core';
import { Ripple } from 'primeng/ripple';
import { RouterLink } from '@angular/router';
import { of, map, switchMap } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Activity, ActivityType } from '../../../shared/interfaces/activity';
import { MediaItem } from '../../../shared/interfaces/media';
import { posterUrl } from '../../../shared/services/tmdb-image';
import { Spinner } from '../../../shared/components/spinner/spinner';

/** Icône et couleur de pastille pour chaque type d'action. */
const TYPE_STYLE: Record<ActivityType, { icon: string; tone: string }> = {
  seen:            { icon: '✓', tone: 'tone-seen' },
  unseen:          { icon: '↺', tone: 'tone-muted' },
  liked:           { icon: '♥', tone: 'tone-like' },
  unliked:         { icon: '♡', tone: 'tone-like' },
  addedToList:     { icon: '＋', tone: 'tone-add' },
  removedFromList: { icon: '−', tone: 'tone-remove' },
  seasonSeen:      { icon: '✓', tone: 'tone-seen' },
  seasonUnseen:    { icon: '↺', tone: 'tone-muted' },
  episodeSeen:     { icon: '✓', tone: 'tone-seen' },
  episodeUnseen:   { icon: '↺', tone: 'tone-muted' },
};

function actionLabel(a: Activity): string {
  switch (a.type) {
    case 'seen':            return 'Marqué comme vu';
    case 'unseen':          return 'Marqué comme non vu';
    case 'liked':           return 'Ajouté aux j\'aime';
    case 'unliked':         return 'Retiré des j\'aime';
    case 'addedToList':     return `Ajouté à « ${a.listName ?? 'une liste'} »`;
    case 'removedFromList': return `Retiré de « ${a.listName ?? 'une liste'} »`;
    case 'seasonSeen':      return `Saison ${a.seasonNumber} vue`;
    case 'seasonUnseen':    return `Saison ${a.seasonNumber} non vue`;
    case 'episodeSeen':     return `Épisode S${a.seasonNumber}E${a.episodeNumber} vu`;
    case 'episodeUnseen':   return `Épisode S${a.seasonNumber}E${a.episodeNumber} non vu`;
  }
}

/** Médias uniques d'une page (un même titre peut revenir plusieurs fois). */
function uniqueRefs(items: Activity[]): { tmdbId: number; mediaType: string }[] {
  const byKey = new Map(items.map(i => [`${i.tmdbId}-${i.mediaType}`, i]));
  return [...byKey.values()].map(i => ({ tmdbId: i.tmdbId, mediaType: i.mediaType }));
}

/** Horodatage ASP.NET : force UTC quand le fuseau est absent. */
function parseUtc(iso: string): number {
  const hasZone = iso.endsWith('Z') || /[+-]\d\d:\d\d$/.test(iso);
  return new Date(hasZone ? iso : iso + 'Z').getTime();
}

/** Ligne du flux, prête à afficher (titre TMDB + présentation résolus). */
interface ActivityRow {
  id: number;
  posterUrl: string | null;
  title: string;
  label: string;
  icon: string;
  tone: string;
  link: (string | number)[];
  createdAt: string;
}

@Component({
  selector: 'app-activity',
  standalone: true,
  imports: [Ripple, RouterLink, Spinner],
  templateUrl: './activity.html',
  styleUrl: './activity.scss',
})
export class ActivityPage implements OnInit {
  private api = inject(Api);
  private tmdb = inject(TmdbService);

  rows = signal<ActivityRow[]>([]);
  page = signal(0);
  totalPages = signal(1);
  totalCount = signal(0);
  loading = signal(false);
  error = signal(false);

  ngOnInit() {
    this.loadMore();
  }

  get hasMore(): boolean {
    return this.page() < this.totalPages();
  }

  loadMore() {
    if (this.loading()) return;
    const next = this.page() + 1;
    this.loading.set(true);

    this.api.activity(next).pipe(
      switchMap(result => {
        this.totalPages.set(result.totalPages);
        this.totalCount.set(result.totalCount);

        if (result.items.length === 0) return of([] as ActivityRow[]);

        // Titre et affiche résolus via TMDB (métadonnées côté frontend) : indispensable
        // pour les actions sans poster stocké (série/saison/épisode vus).
        return this.tmdb.fetchMany(uniqueRefs(result.items)).pipe(
          map(media => {
            const mediaById = new Map(media.map(m => [m.id, m]));
            return result.items.map(a => this.toRow(a, mediaById.get(a.tmdbId)));
          }),
        );
      }),
    ).subscribe({
      next: rows => {
        this.rows.update(list => [...list, ...rows]);
        this.page.set(next);
        this.loading.set(false);
      },
      error: () => { this.error.set(true); this.loading.set(false); },
    });
  }

  private toRow(a: Activity, media?: MediaItem): ActivityRow {
    const type = a.mediaType === 'tv' ? 'tv' : 'movie';
    const style = TYPE_STYLE[a.type];
    const title = media?.title ?? media?.name ?? '';
    return {
      id: a.id,
      posterUrl: posterUrl(a.posterPath ?? media?.poster_path, 'w185'),
      title: title || (type === 'tv' ? 'Série' : 'Film'),
      label: actionLabel(a),
      icon: style.icon,
      tone: style.tone,
      link: ['/', type, a.tmdbId],
      createdAt: a.createdAt,
    };
  }

  relativeTime(iso: string): string {
    const diff = Math.max(0, Date.now() - parseUtc(iso));
    const min = Math.floor(diff / 60000);
    if (min < 1) return 'À l\'instant';
    if (min < 60) return `Il y a ${min} min`;
    const h = Math.floor(min / 60);
    if (h < 24) return `Il y a ${h} h`;
    const d = Math.floor(h / 24);
    if (d < 7) return `Il y a ${d} j`;
    return new Date(parseUtc(iso)).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
  }
}
