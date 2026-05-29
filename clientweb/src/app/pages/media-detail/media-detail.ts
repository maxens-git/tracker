import { Component, OnInit, inject, signal, HostListener } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { forkJoin, of, switchMap, Observable } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, MarkShowSeenPayload, MarkSeasonSeenPayload } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import {
  TmdbMovie, TmdbShow, TmdbSeason, TmdbCredits, TmdbVideos,
  TmdbEpisode, TmdbSeasonSummary, MediaItem, UserState
} from '../../../shared/interfaces/media';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { posterUrl, backdropUrl, profileUrl, yearOf } from '../../../shared/services/tmdb-image';
import { EpisodeSeenDto } from '../../../shared/interfaces/movie';
import { SYSTEM_LIST } from '../../../shared/constants';

type MediaType = 'movie' | 'tv';

interface SeasonView extends TmdbSeasonSummary {
  episodes: TmdbEpisode[];
  seen: boolean;
  loaded: boolean;
}

/** Résultat agrégé du forkJoin de chargement initial (films ou séries). */
interface MediaDetailData {
  data: TmdbMovie | TmdbShow;
  credits: TmdbCredits | null;
  videos: TmdbVideos | null;
  similar: { results: MediaItem[] } | null;
  state: UserState[];
  lists: MediaListSummary[];
  episodesSeen?: EpisodeSeenDto[];
}

@Component({
  selector: 'app-media-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, Spinner, MediaRow],
  templateUrl: './media-detail.html',
  styleUrl: './media-detail.scss',
})
export class MediaDetail implements OnInit {
  private route = inject(ActivatedRoute);
  private tmdb = inject(TmdbService);
  private api = inject(Api);
  private location = inject(Location);

  loading = signal(true);
  error = signal<string | null>(null);
  mediaType = signal<MediaType>('movie');

  movie = signal<TmdbMovie | null>(null);
  show = signal<TmdbShow | null>(null);
  seasons = signal<SeasonView[]>([]);
  episodesSeen = signal<Map<string, boolean>>(new Map());

  credits = signal<TmdbCredits | null>(null);
  videos = signal<TmdbVideos | null>(null);
  similar = signal<MediaItem[]>([]);
  lists = signal<MediaListSummary[]>([]);

  userState = signal<UserState>({ tmdbId: 0, seen: false, liked: false, listIds: [] });

  expandedSeason = signal<number | null>(null);
  seenPending = signal(false);
  likedPending = signal(false);
  watchlistPending = signal(false);
  listPending = signal<number | null>(null);
  showListPicker = signal(false);
  episodePending = signal<Set<string>>(new Set());
  seasonPending = signal<Set<number>>(new Set());

  ngOnInit() {
    this.route.paramMap.pipe(
      switchMap(params => {
        const type = this.route.snapshot.data['type'] as MediaType;
        const tmdbId = Number(params.get('tmdbId'));
        this.mediaType.set(type);
        this.loading.set(true);
        this.error.set(null);
        this.movie.set(null);
        this.show.set(null);
        this.seasons.set([]);
        this.episodesSeen.set(new Map());
        this.credits.set(null);
        this.videos.set(null);
        this.similar.set([]);
        this.expandedSeason.set(null);
        this.showListPicker.set(false);
        this.userState.set({ tmdbId, seen: false, liked: false, listIds: [] });

        const state$ = this.api.states([tmdbId], type).pipe(catchError(() => of([])));
        const lists$ = this.api.lists().pipe(catchError(() => of([])));

        if (type === 'movie') {
          return forkJoin({
            data: this.tmdb.movie(tmdbId),
            credits: this.tmdb.movieCredits(tmdbId).pipe(catchError(() => of(null))),
            videos: this.tmdb.movieVideos(tmdbId).pipe(catchError(() => of(null))),
            similar: this.tmdb.similarMovies(tmdbId).pipe(catchError(() => of(null))),
            state: state$,
            lists: lists$,
          });
        } else {
          return forkJoin({
            data: this.tmdb.show(tmdbId),
            credits: this.tmdb.showCredits(tmdbId).pipe(catchError(() => of(null))),
            videos: this.tmdb.showVideos(tmdbId).pipe(catchError(() => of(null))),
            similar: this.tmdb.similarShows(tmdbId).pipe(catchError(() => of(null))),
            state: state$,
            lists: lists$,
            episodesSeen: this.api.showEpisodes(tmdbId).pipe(catchError(() => of([]))),
          });
        }
      }),
    ).subscribe({
      next: (result: MediaDetailData) => {
        const { data, credits, videos, similar, state, lists } = result;
        const st: UserState = state[0] ?? { tmdbId: data.id, seen: false, liked: false, listIds: [] };
        this.userState.set(st);
        this.credits.set(credits);
        this.videos.set(videos);
        this.similar.set(similar?.results ?? []);
        this.lists.set(lists);

        if (this.isMovie) {
          this.movie.set(data as TmdbMovie);
        } else {
          const show = data as TmdbShow;
          this.show.set(show);
          const epSeenMap = new Map<string, boolean>();
          for (const ep of (result.episodesSeen ?? [])) {
            epSeenMap.set(epKey(ep.seasonNumber, ep.episodeNumber), ep.seen);
          }
          this.episodesSeen.set(epSeenMap);
          this.seasons.set(
            show.seasons
              .filter(s => s.season_number > 0)
              .map(s => ({ ...s, episodes: [], seen: false, loaded: false }))
          );
          this.refreshSeasonsSeen();
        }

        this.loading.set(false);
        window.scrollTo({ top: 0 });
      },
      error: () => {
        this.error.set('Impossible de charger les détails');
        this.loading.set(false);
      },
    });
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent) {
    const target = event.target as HTMLElement;
    if (!target.closest('.list-picker-wrap')) {
      this.showListPicker.set(false);
    }
  }

  goBack() { this.location.back(); }

  get isMovie() { return this.mediaType() === 'movie'; }
  get currentSeen() { return this.userState().seen; }
  get currentLiked() { return this.userState().liked; }
  get currentListIds() { return this.userState().listIds; }

  get watchlistId(): number | null {
    return this.lists().find(l => l.isSystem && l.name === SYSTEM_LIST.watchlist)?.id ?? null;
  }

  get currentInWatchlist(): boolean {
    const id = this.watchlistId;
    return id !== null && this.currentListIds.includes(id);
  }

  get customLists(): MediaListSummary[] {
    return this.lists().filter(l => !l.isSystem);
  }

  isInList(listId: number): boolean {
    return this.currentListIds.includes(listId);
  }

  // ── Optimistic update helpers ─────────────────────────────────────────────

  private patchUserState(patch: Partial<UserState>): void {
    this.userState.update(s => ({ ...s, ...patch }));
  }

  /** Ajoute (member=true) ou retire l'appartenance à une liste dans l'état local. */
  private setListMembership(listId: number, member: boolean): void {
    this.patchUserState({
      listIds: member
        ? [...this.currentListIds, listId]
        : this.currentListIds.filter(id => id !== listId),
    });
  }

  private currentPosterPath(): string | null | undefined {
    return this.isMovie ? this.movie()?.poster_path : this.show()?.poster_path;
  }

  /** Applique un changement optimiste, lance la requête et l'annule en cas d'erreur. */
  private runOptimistic(apply: () => void, revert: () => void, request: Observable<unknown>, done: () => void): void {
    apply();
    request.subscribe({
      complete: done,
      error: () => { revert(); done(); },
    });
  }

  // ── Seen ─────────────────────────────────────────────────────────────────

  toggleSeen() {
    if (this.seenPending()) return;
    this.seenPending.set(true);
    const newSeen = !this.currentSeen;
    const tmdbId = this.userState().tmdbId;

    this.patchUserState({ seen: newSeen });

    if (this.isMovie) {
      this.runOptimistic(
        () => {},
        () => this.patchUserState({ seen: !newSeen }),
        this.api.markSeen(tmdbId, 'movie', { seen: newSeen, runtime: this.movie()?.runtime ?? null }),
        () => this.seenPending.set(false),
      );
    } else {
      const seasons = this.show()?.seasons.filter(s => s.season_number > 0) ?? [];
      const payload: MarkShowSeenPayload = {
        seen: newSeen,
        seasons: seasons.map(s => ({ seasonNumber: s.season_number, episodeNumbers: episodeRange(s.episode_count) }))
      };
      this.api.markShowSeen(tmdbId, payload).subscribe({
        next: () => {
          const newMap = new Map<string, boolean>();
          for (const s of seasons) {
            for (const ep of episodeRange(s.episode_count)) {
              newMap.set(epKey(s.season_number, ep), newSeen);
            }
          }
          this.episodesSeen.set(newMap);
          this.refreshSeasonsSeen();
          this.seenPending.set(false);
        },
        error: () => { this.patchUserState({ seen: !newSeen }); this.seenPending.set(false); },
      });
    }
  }

  // ── Liked ─────────────────────────────────────────────────────────────────

  toggleLiked() {
    if (this.likedPending()) return;
    this.likedPending.set(true);
    const newLiked = !this.currentLiked;
    const tmdbId = this.userState().tmdbId;

    this.runOptimistic(
      () => this.patchUserState({ liked: newLiked }),
      () => this.patchUserState({ liked: !newLiked }),
      this.api.markLiked(tmdbId, this.mediaType(), newLiked),
      () => this.likedPending.set(false),
    );
  }

  // ── Watchlist ─────────────────────────────────────────────────────────────

  toggleWatchlist() {
    if (this.watchlistPending()) return;
    this.watchlistPending.set(true);
    const inWatchlist = this.currentInWatchlist;
    const tmdbId = this.userState().tmdbId;
    const type = this.mediaType();
    const wlId = this.watchlistId;

    const request = inWatchlist
      ? this.api.removeFromWatchlist(tmdbId, type)
      : this.api.addToWatchlist(tmdbId, type, {
          posterPath: this.currentPosterPath(),
          runtime: this.isMovie ? (this.movie()?.runtime ?? null) : null,
        });

    this.runOptimistic(
      () => { if (wlId !== null) this.setListMembership(wlId, !inWatchlist); },
      () => { if (wlId !== null) this.setListMembership(wlId, inWatchlist); },
      request,
      () => this.watchlistPending.set(false),
    );
  }

  // ── Custom lists ──────────────────────────────────────────────────────────

  toggleList(listId: number) {
    if (this.listPending() !== null) return;
    this.listPending.set(listId);
    const inList = this.isInList(listId);
    const tmdbId = this.userState().tmdbId;
    const type = this.mediaType();

    const request = inList
      ? this.api.removeItemFromList(listId, tmdbId, type)
      : this.api.addItemToList(listId, { tmdbId, mediaType: type, posterPath: this.currentPosterPath() });

    this.runOptimistic(
      () => this.setListMembership(listId, !inList),
      () => this.setListMembership(listId, inList),
      request,
      () => this.listPending.set(null),
    );
  }

  // ── Seasons & episodes ────────────────────────────────────────────────────

  toggleSeason(seasonNumber: number) {
    const current = this.expandedSeason();
    if (current === seasonNumber) {
      this.expandedSeason.set(null);
      return;
    }
    this.expandedSeason.set(seasonNumber);
    this.loadSeasonIfNeeded(seasonNumber);
  }

  private loadSeasonIfNeeded(seasonNumber: number) {
    const seasons = this.seasons();
    const idx = seasons.findIndex(s => s.season_number === seasonNumber);
    if (idx === -1 || seasons[idx].loaded) return;

    const showId = this.show()!.id;
    this.tmdb.season(showId, seasonNumber).subscribe({
      next: season => {
        const epMap = this.episodesSeen();
        const episodes = season.episodes.map(ep => ({
          ...ep,
          seen: epMap.get(epKey(ep.season_number, ep.episode_number)) ?? false
        }));
        const allSeen = episodes.every(ep => ep.seen);
        this.seasons.update(prev => prev.map((s, i) =>
          i === idx ? { ...s, episodes, seen: allSeen, loaded: true } : s
        ));
      }
    });
  }

  isSeasonExpanded(seasonNumber: number): boolean {
    return this.expandedSeason() === seasonNumber;
  }

  isEpisodePending(key: string): boolean {
    return this.episodePending().has(key);
  }

  isSeasonPending(seasonNumber: number): boolean {
    return this.seasonPending().has(seasonNumber);
  }

  seasonSeenCount(season: SeasonView): number {
    return season.episodes.filter(ep => ep.seen).length;
  }

  toggleEpisodeSeen(ep: TmdbEpisode, event: Event) {
    event.stopPropagation();
    const key = epKey(ep.season_number, ep.episode_number);
    if (this.isEpisodePending(key)) return;
    const newSeen = !ep.seen;
    const showId = this.show()!.id;

    this.episodePending.update(s => new Set([...s, key]));
    this.patchEpisode(ep.season_number, ep.episode_number, newSeen);

    this.api.markEpisodeSeen(showId, ep.season_number, ep.episode_number, newSeen).subscribe({
      complete: () => {
        this.episodePending.update(s => { const n = new Set(s); n.delete(key); return n; });
      },
      error: () => {
        this.patchEpisode(ep.season_number, ep.episode_number, ep.seen ?? false);
        this.episodePending.update(s => { const n = new Set(s); n.delete(key); return n; });
      },
    });
  }

  toggleSeasonSeen(season: SeasonView, event: Event) {
    event.stopPropagation();
    if (this.isSeasonPending(season.season_number)) return;
    const newSeen = !season.seen;
    const showId = this.show()!.id;
    const episodeNumbers = season.episodes.map(ep => ep.episode_number);

    this.seasonPending.update(s => new Set([...s, season.season_number]));
    this.patchSeason(season.season_number, newSeen);

    this.api.markSeasonSeen(showId, season.season_number, { seen: newSeen, episodeNumbers }).subscribe({
      complete: () => this.seasonPending.update(s => { const n = new Set(s); n.delete(season.season_number); return n; }),
      error: () => {
        this.patchSeason(season.season_number, !newSeen);
        this.seasonPending.update(s => { const n = new Set(s); n.delete(season.season_number); return n; });
      },
    });
  }

  private patchEpisode(seasonNumber: number, episodeNumber: number, seen: boolean) {
    const key = epKey(seasonNumber, episodeNumber);
    this.episodesSeen.update(m => { const n = new Map(m); n.set(key, seen); return n; });
    this.seasons.update(prev => prev.map(s =>
      s.season_number !== seasonNumber ? s : {
        ...s,
        episodes: s.episodes.map(ep =>
          ep.episode_number === episodeNumber ? { ...ep, seen } : ep
        ),
      }
    ));
  }

  private patchSeason(seasonNumber: number, seen: boolean) {
    this.seasons.update(prev => prev.map(s =>
      s.season_number !== seasonNumber ? s : {
        ...s,
        seen,
        episodes: s.episodes.map(ep => ({ ...ep, seen }))
      }
    ));
  }

  private refreshSeasonsSeen() {
    const epMap = this.episodesSeen();
    this.seasons.update(prev => prev.map(s => ({
      ...s,
      seen: s.loaded && s.episodes.length > 0 && s.episodes.every(ep => ep.seen),
      episodes: s.episodes.map(ep => ({
        ...ep,
        seen: epMap.get(epKey(s.season_number, ep.episode_number)) ?? false
      }))
    })));
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  get filteredVideos() {
    const all = this.videos()?.results ?? [];
    const fr = all.filter(v => v.iso_639_1 === 'fr' && v.site === 'YouTube' && ['Trailer', 'Teaser'].includes(v.type));
    const en = all.filter(v => v.iso_639_1 === 'en' && v.site === 'YouTube' && ['Trailer', 'Teaser'].includes(v.type));
    return [...fr, ...en].slice(0, 6);
  }

  backdropStyle(path?: string | null): string | null {
    const url = backdropUrl(path, 'original');
    return url
      ? `linear-gradient(to bottom, rgba(14,20,24,0.35) 0%, rgba(14,20,24,0.95) 85%, rgba(14,20,24,1) 100%), url(${url})`
      : null;
  }

  poster(path?: string | null): string | null { return posterUrl(path, 'w500'); }

  profileUrl(path?: string | null): string | null { return profileUrl(path); }

  trailerThumb(key: string): string { return `https://img.youtube.com/vi/${key}/mqdefault.jpg`; }
  trailerLink(key: string): string { return `https://www.youtube.com/watch?v=${key}`; }

  year(date?: string | null): string { return yearOf(date); }

  formatRuntime(min: number): string {
    if (!min) return '';
    const h = Math.floor(min / 60);
    const m = min % 60;
    return h > 0 ? `${h}h${m > 0 ? String(m).padStart(2, '0') + 'min' : ''}` : `${m}min`;
  }

  formatMoney(amount: number): string | null {
    if (!amount) return null;
    return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amount);
  }

  genres(g: { id: number; name: string }[] | undefined): string {
    return g?.map(x => x.name).join(', ') ?? '';
  }
}

function epKey(season: number, episode: number): string {
  return `${season}-${episode}`;
}

/** Numéros d'épisodes 1..count. */
function episodeRange(count: number): number[] {
  return Array.from({ length: count }, (_, i) => i + 1);
}
