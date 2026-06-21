import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { forkJoin, of, switchMap, Observable } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, MarkShowSeenPayload, MarkSeasonSeenPayload } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import {
  TmdbMovie, TmdbShow, TmdbSeason, TmdbCredits, TmdbVideos,
  TmdbEpisode, TmdbSeasonSummary, MediaItem, UserState, TmdbCrewMember
} from '../../../shared/interfaces/media';
import { PRIORITY_CREW_JOBS, localizedJob } from '../../../shared/services/crew';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { posterUrl, backdropUrl, profileUrl, yearOf } from '../../../shared/services/tmdb-image';
import { errorMessage } from '../../../shared/services/http-error';
import { EpisodeSeenDto } from '../../../shared/interfaces/episode';
import { SYSTEM_LIST } from '../../../shared/constants';
import { MessageService } from 'primeng/api';
import { ButtonModule } from 'primeng/button';
import { DialogModule } from 'primeng/dialog';
import { InputTextModule } from 'primeng/inputtext';
import { TextareaModule } from 'primeng/textarea';

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
  tracked: boolean;
  episodesSeen?: EpisodeSeenDto[];
}

@Component({
  selector: 'app-media-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, Spinner, MediaRow, ButtonModule, DialogModule, InputTextModule, TextareaModule],
  templateUrl: './media-detail.html',
  styleUrl: './media-detail.scss',
})
export class MediaDetail implements OnInit {
  private route = inject(ActivatedRoute);
  private tmdb = inject(TmdbService);
  private api = inject(Api);
  private location = inject(Location);
  private messages = inject(MessageService);

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
  listDialogOpen = signal(false);
  creatingList = signal(false);
  listCreateError = signal<string | null>(null);
  episodePending = signal<Set<string>>(new Set());
  seasonPending = signal<Set<number>>(new Set());
  releaseTracked = signal(false);
  releasePending = signal(false);
  newListName = '';
  newListIcon = '';
  newListDescription = '';

  ngOnInit() {
    this.route.paramMap.pipe(
      switchMap(params => {
        const type = this.route.snapshot.data['type'] as MediaType;
        const tmdbId = Number(params.get('tmdbId'));
        this.resetForNavigation(type, tmdbId);
        return type === 'movie' ? this.loadMovieData$(tmdbId) : this.loadShowData$(tmdbId);
      }),
    ).subscribe({
      next: result => this.applyLoadedData(result),
      error: () => {
        this.error.set('Impossible de charger les détails');
        this.loading.set(false);
      },
    });
  }

  /** Remet tous les signaux à zéro avant de charger un nouveau média (navigation interne incluse). */
  private resetForNavigation(type: MediaType, tmdbId: number) {
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
    this.listDialogOpen.set(false);
    this.resetListForm();
    this.userState.set({ tmdbId, seen: false, liked: false, listIds: [] });
    this.releaseTracked.set(false);
    this.releasePending.set(false);
  }

  /** Charge en parallèle les données d'un film. Seul `data` est bloquant, le reste est optionnel. */
  private loadMovieData$(tmdbId: number): Observable<MediaDetailData> {
    return forkJoin({
      data: this.tmdb.movie(tmdbId),
      credits: this.tmdb.movieCredits(tmdbId).pipe(catchError(() => of(null))),
      videos: this.tmdb.movieVideos(tmdbId).pipe(catchError(() => of(null))),
      similar: this.tmdb.similarMovies(tmdbId).pipe(catchError(() => of(null))),
      state: this.userState$(tmdbId),
      lists: this.lists$(),
      tracked: this.trackedState$(tmdbId),
    });
  }

  /** Comme pour les films, avec en plus les épisodes déjà vus. */
  private loadShowData$(tmdbId: number): Observable<MediaDetailData> {
    return forkJoin({
      data: this.tmdb.show(tmdbId),
      credits: this.tmdb.showCredits(tmdbId).pipe(catchError(() => of(null))),
      videos: this.tmdb.showVideos(tmdbId).pipe(catchError(() => of(null))),
      similar: this.tmdb.similarShows(tmdbId).pipe(catchError(() => of(null))),
      state: this.userState$(tmdbId),
      lists: this.lists$(),
      tracked: this.trackedState$(tmdbId),
      episodesSeen: this.api.showEpisodes(tmdbId).pipe(catchError(() => of([]))),
    });
  }

  private userState$(tmdbId: number): Observable<UserState[]> {
    return this.api.states([tmdbId], this.mediaType()).pipe(catchError(() => of([])));
  }

  private lists$(): Observable<MediaListSummary[]> {
    return this.api.lists().pipe(catchError(() => of([])));
  }

  private trackedState$(tmdbId: number): Observable<boolean> {
    return this.api.trackedMediaState(tmdbId, this.mediaType()).pipe(
      map(state => state.tracked),
      catchError(() => of(false)),
    );
  }

  /** Déverse le résultat du chargement dans les signaux de la page. */
  private applyLoadedData(result: MediaDetailData) {
    const { data, credits, videos, similar, state, lists } = result;
    this.userState.set(state[0] ?? { tmdbId: data.id, seen: false, liked: false, listIds: [] });
    this.credits.set(credits);
    this.videos.set(videos);
    this.similar.set(similar?.results ?? []);
    this.lists.set(lists);
    this.releaseTracked.set(result.tracked);

    if (this.isMovie) {
      this.movie.set(data as TmdbMovie);
    } else {
      this.initShowState(data as TmdbShow, result.episodesSeen ?? []);
    }

    this.loading.set(false);
    window.scrollTo({ top: 0 });
  }

  toggleReleaseTracking() {
    if (this.releasePending()) return;
    this.releasePending.set(true);
    const tracked = this.releaseTracked();
    const tmdbId = this.userState().tmdbId;
    const type = this.mediaType();
    const title = this.isMovie ? (this.movie()?.title ?? 'Film') : (this.show()?.name ?? 'Série');
    const posterPath = this.currentPosterPath();

    const request = tracked
      ? this.api.removeTrackedMedia(tmdbId, type)
      : this.api.addTrackedMedia({ tmdbId, mediaType: type, title, posterPath });

    this.runOptimistic(
      () => this.releaseTracked.set(!tracked),
      () => this.releaseTracked.set(tracked),
      request,
      () => this.releasePending.set(false),
    );
  }

  /** Initialise les signaux propres aux séries : saisons réelles et map des épisodes vus. */
  private initShowState(show: TmdbShow, episodesSeen: EpisodeSeenDto[]) {
    this.show.set(show);

    const epSeenMap = new Map<string, boolean>();
    for (const ep of episodesSeen) {
      epSeenMap.set(epKey(ep.seasonNumber, ep.episodeNumber), ep.seen);
    }
    this.episodesSeen.set(epSeenMap);

    this.seasons.set(
      show.seasons
        .filter(s => s.season_number > 0)
        .map(s => ({ ...s, episodes: [], seen: false, loaded: false }))
    );
    this.refreshSeasonsSeen();
    this.syncShowSeen();
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

  get inAnyCustomList(): boolean {
    return this.customLists.some(list => this.isInList(list.id));
  }

  /** Membres clés de l'équipe technique : métiers prioritaires, sans doublon de personne. */
  get topCrew(): TmdbCrewMember[] {
    const crew = this.credits()?.crew ?? [];
    const byPerson = new Map<number, TmdbCrewMember>();
    for (const member of crew.filter(c => PRIORITY_CREW_JOBS.includes(c.job))) {
      if (!byPerson.has(member.id)) byPerson.set(member.id, member);
    }
    return [...byPerson.values()].slice(0, 10);
  }

  /** Libellé français d'un métier TMDB. */
  jobLabel(job: string): string {
    return localizedJob(job);
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

  private bumpListItemCount(listId: number, delta: number): void {
    this.lists.update(lists => lists.map(list =>
      list.id === listId
        ? { ...list, itemsCount: Math.max(0, list.itemsCount + delta) }
        : list
    ));
  }

  private currentPosterPath(): string | null | undefined {
    return this.isMovie ? this.movie()?.poster_path : this.show()?.poster_path;
  }

  /** Applique un changement optimiste, lance la requête et l'annule en cas d'erreur. */
  private runOptimistic(apply: () => void, revert: () => void, request: Observable<unknown>, done: () => void): void {
    apply();
    request.subscribe({
      complete: done,
      error: err => { revert(); done(); this.showToast(errorMessage(err)); },
    });
  }

  showToast(message: string): void {
    this.messages.add({ severity: 'error', summary: 'Action impossible', detail: message, life: 4500 });
  }

  showSuccess(message: string): void {
    this.messages.add({ severity: 'success', summary: 'Listes', detail: message, life: 3200 });
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
        this.api.markSeen(tmdbId, 'movie', {
          seen: newSeen,
          posterPath: this.currentPosterPath(),
          runtime: this.movie()?.runtime ?? null,
          genres: this.movie()?.genres ?? [],
        }),
        () => this.seenPending.set(false),
      );
    } else {
      const seasons = this.show()?.seasons.filter(s => s.season_number > 0) ?? [];
      const payload: MarkShowSeenPayload = {
        seen: newSeen,
        posterPath: this.currentPosterPath(),
        genres: this.show()?.genres ?? [],
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
        error: err => { this.patchUserState({ seen: !newSeen }); this.seenPending.set(false); this.showToast(errorMessage(err)); },
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
          genres: this.isMovie ? (this.movie()?.genres ?? []) : (this.show()?.genres ?? []),
        });

    this.runOptimistic(
      () => { if (wlId !== null) this.setListMembership(wlId, !inWatchlist); },
      () => { if (wlId !== null) this.setListMembership(wlId, inWatchlist); },
      request,
      () => this.watchlistPending.set(false),
    );
  }

  // ── Custom lists ──────────────────────────────────────────────────────────

  openListDialog() {
    this.listCreateError.set(null);
    this.listDialogOpen.set(true);
  }

  closeListDialog() {
    if (this.listPending() !== null || this.creatingList()) return;
    this.listDialogOpen.set(false);
  }

  createListAndAdd() {
    const name = this.newListName.trim();
    if (!name || this.creatingList()) return;

    const dto = {
      name,
      icon: this.newListIcon.trim(),
      description: this.newListDescription.trim(),
    };

    this.creatingList.set(true);
    this.listCreateError.set(null);

    this.api.createList(dto).pipe(
      switchMap(list =>
        this.api.addItemToList(list.id, {
          tmdbId: this.userState().tmdbId,
          mediaType: this.mediaType(),
          posterPath: this.currentPosterPath(),
        }).pipe(map(() => list))
      )
    ).subscribe({
      next: list => {
        this.creatingList.set(false);
        this.lists.update(lists => [...lists, { ...list, itemsCount: 1 }]);
        this.setListMembership(list.id, true);
        this.resetListForm();
        this.showSuccess(`Ajouté à « ${list.name} ».`);
      },
      error: err => {
        this.creatingList.set(false);
        this.listCreateError.set(errorMessage(err));
      },
    });
  }

  toggleList(listId: number) {
    if (this.listPending() !== null) return;
    this.listPending.set(listId);
    const inList = this.isInList(listId);
    const delta = inList ? -1 : 1;
    const tmdbId = this.userState().tmdbId;
    const type = this.mediaType();

    const request = inList
      ? this.api.removeItemFromList(listId, tmdbId, type)
      : this.api.addItemToList(listId, { tmdbId, mediaType: type, posterPath: this.currentPosterPath() });

    this.runOptimistic(
      () => { this.setListMembership(listId, !inList); this.bumpListItemCount(listId, delta); },
      () => { this.setListMembership(listId, inList); this.bumpListItemCount(listId, -delta); },
      request,
      () => this.listPending.set(null),
    );
  }

  private resetListForm() {
    this.newListName = '';
    this.newListIcon = '';
    this.newListDescription = '';
    this.listCreateError.set(null);
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

  /** Nombre d'épisodes vus d'une saison, dérivé de la map (sans charger les épisodes). */
  seasonSeenCount(season: SeasonView): number {
    return this.seenCountInSeason(season.season_number);
  }

  /** Saison entièrement vue, dérivé de la map + episode_count (sans charger les épisodes). */
  isSeasonSeen(season: SeasonView): boolean {
    return season.episode_count > 0 && this.seenCountInSeason(season.season_number) >= season.episode_count;
  }

  get showEpisodeCount(): number {
    return this.seasons().reduce((total, season) => total + Math.max(0, season.episode_count), 0);
  }

  get showSeenEpisodeCount(): number {
    return this.seasons().reduce((total, season) => total + this.seenCountInSeason(season.season_number), 0);
  }

  get showProgressPercent(): number {
    const total = this.showEpisodeCount;
    return total > 0 ? Math.min(100, (this.showSeenEpisodeCount / total) * 100) : 0;
  }

  /** Pourcentage de progression d'une saison, borné à 100. */
  seasonProgress(season: SeasonView): number {
    if (season.episode_count <= 0) return 0;
    return Math.min(100, (this.seenCountInSeason(season.season_number) / season.episode_count) * 100);
  }

  toggleEpisodeSeen(ep: TmdbEpisode, event: Event) {
    event.stopPropagation();
    const key = epKey(ep.season_number, ep.episode_number);
    if (this.isEpisodePending(key)) return;
    const newSeen = !ep.seen;
    const showId = this.show()!.id;

    this.episodePending.update(s => setWith(s, key));
    this.patchEpisode(ep.season_number, ep.episode_number, newSeen);

    this.api.markEpisodeSeen(showId, ep.season_number, ep.episode_number, newSeen).subscribe({
      complete: () => {
        this.episodePending.update(s => setWithout(s, key));
      },
      error: () => {
        this.patchEpisode(ep.season_number, ep.episode_number, ep.seen ?? false);
        this.episodePending.update(s => setWithout(s, key));
      },
    });
  }

  toggleSeasonSeen(season: SeasonView, event: Event) {
    event.stopPropagation();
    if (this.isSeasonPending(season.season_number)) return;
    const newSeen = !this.isSeasonSeen(season);
    const showId = this.show()!.id;
    // Si les épisodes ne sont pas chargés, on utilise 1..episode_count (comme le bouton série).
    const episodeNumbers = season.episodes.length > 0
      ? season.episodes.map(ep => ep.episode_number)
      : episodeRange(season.episode_count);

    this.seasonPending.update(s => setWith(s, season.season_number));
    this.patchSeason(season.season_number, newSeen);

    this.api.markSeasonSeen(showId, season.season_number, { seen: newSeen, episodeNumbers }).subscribe({
      complete: () => this.seasonPending.update(s => setWithout(s, season.season_number)),
      error: () => {
        this.patchSeason(season.season_number, !newSeen);
        this.seasonPending.update(s => setWithout(s, season.season_number));
      },
    });
  }

  private patchEpisode(seasonNumber: number, episodeNumber: number, seen: boolean) {
    const key = epKey(seasonNumber, episodeNumber);
    this.episodesSeen.update(m => { const n = new Map(m); n.set(key, seen); return n; });
    this.seasons.update(prev => prev.map(s => {
      if (s.season_number !== seasonNumber) return s;
      const episodes = s.episodes.map(ep =>
        ep.episode_number === episodeNumber ? { ...ep, seen } : ep
      );
      // La saison est "vue" dès que tous ses épisodes chargés le sont.
      return { ...s, episodes, seen: episodes.length > 0 && episodes.every(ep => ep.seen) };
    }));
    this.syncShowSeen();
  }

  private patchSeason(seasonNumber: number, seen: boolean) {
    const season = this.seasons().find(s => s.season_number === seasonNumber);
    const episodeNumbers = (season && season.episodes.length > 0)
      ? season.episodes.map(ep => ep.episode_number)
      : episodeRange(season?.episode_count ?? 0);
    // Garde la map des épisodes synchro pour que la dérivation série soit correcte.
    this.episodesSeen.update(m => {
      const n = new Map(m);
      for (const epNum of episodeNumbers) n.set(epKey(seasonNumber, epNum), seen);
      return n;
    });
    this.seasons.update(prev => prev.map(s =>
      s.season_number !== seasonNumber ? s : {
        ...s,
        seen,
        episodes: s.episodes.map(ep => ({ ...ep, seen }))
      }
    ));
    this.syncShowSeen();
  }

  /**
   * Recalcule l'état "vu" global de la série à partir des épisodes (une série est vue
   * quand toutes ses saisons réelles le sont) et le persiste si la valeur a changé.
   */
  private syncShowSeen() {
    const derived = this.computeShowSeen();
    if (derived === this.currentSeen) return;

    this.patchUserState({ seen: derived });
    const showId = this.userState().tmdbId;
    this.api.markSeen(showId, 'tv', {
      seen: derived,
      posterPath: this.currentPosterPath(),
      genres: this.show()?.genres ?? [],
    }).subscribe({
      error: () => { /* optimiste : réconcilié au prochain reload */ },
    });
  }

  /** Vrai si toutes les saisons réelles (hors spéciales, épisodes connus) sont vues. */
  private computeShowSeen(): boolean {
    const seasons = this.seasons().filter(s => s.episode_count > 0);
    if (seasons.length === 0) return false;
    return seasons.every(s => this.isSeasonFullySeen(s.season_number, s.episode_count));
  }

  /** Compte les épisodes vus d'une saison dans la map. */
  private seenCountInSeason(seasonNumber: number): number {
    const prefix = `${seasonNumber}-`;
    let seen = 0;
    for (const [key, val] of this.episodesSeen()) {
      if (val && key.startsWith(prefix)) seen++;
    }
    return seen;
  }

  /** Compte les épisodes vus d'une saison dans la map et compare au total TMDB. */
  private isSeasonFullySeen(seasonNumber: number, episodeCount: number): boolean {
    return episodeCount > 0 && this.seenCountInSeason(seasonNumber) >= episodeCount;
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

  /** Bandes-annonces YouTube (Trailer/Teaser), françaises d'abord puis anglaises, max 6. */
  get filteredVideos() {
    const trailers = (this.videos()?.results ?? [])
      .filter(v => v.site === 'YouTube' && ['Trailer', 'Teaser'].includes(v.type));
    const fr = trailers.filter(v => v.iso_639_1 === 'fr');
    const en = trailers.filter(v => v.iso_639_1 === 'en');
    return [...fr, ...en].slice(0, 6);
  }

  backdropStyle(path?: string | null): string | null {
    const url = backdropUrl(path, 'original');
    return url
      ? `linear-gradient(to right, rgba(20,18,16,0.98) 0%, rgba(20,18,16,0.84) 48%, rgba(20,18,16,0.48) 100%), linear-gradient(to top, rgba(20,18,16,0.96) 0%, rgba(20,18,16,0.16) 70%), url(${url})`
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

  formatNumber(value: number): string {
    return new Intl.NumberFormat('fr-FR').format(value);
  }

  genres(g: { id: number; name: string }[] | undefined): string {
    return g?.map(x => x.name).join(', ') ?? '';
  }
}

function epKey(season: number, episode: number): string {
  return `${season}-${episode}`;
}

// Les signaux comparent par référence : ces helpers renvoient toujours une nouvelle instance.
function setWith<T>(set: Set<T>, value: T): Set<T> {
  const next = new Set(set);
  next.add(value);
  return next;
}

function setWithout<T>(set: Set<T>, value: T): Set<T> {
  const next = new Set(set);
  next.delete(value);
  return next;
}

/** Numéros d'épisodes 1..count. */
function episodeRange(count: number): number[] {
  return Array.from({ length: count }, (_, i) => i + 1);
}
