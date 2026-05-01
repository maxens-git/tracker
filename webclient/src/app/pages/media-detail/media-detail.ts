import { Component, OnInit, inject, signal, HostListener } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Api } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import { MovieDto, CreditsDto, TrailersDto } from '../../../shared/interfaces/movie';
import { ShowDto, SeasonModel, EpisodeModel } from '../../../shared/interfaces/show';
import { MediaItem } from '../../../shared/interfaces/media';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { posterUrl, backdropUrl } from '../../../shared/services/tmdb-image';

type MediaType = 'movie' | 'tv';

@Component({
  selector: 'app-media-detail',
  standalone: true,
  imports: [CommonModule, Spinner, MediaRow],
  templateUrl: './media-detail.html',
  styleUrl: './media-detail.scss',
})
export class MediaDetail implements OnInit {
  private route = inject(ActivatedRoute);
  private api = inject(Api);
  private location = inject(Location);

  loading = signal(true);
  error = signal<string | null>(null);
  mediaType = signal<MediaType>('movie');
  movie = signal<MovieDto | null>(null);
  show = signal<ShowDto | null>(null);
  credits = signal<CreditsDto | null>(null);
  trailers = signal<TrailersDto | null>(null);
  similar = signal<MediaItem[]>([]);
  lists = signal<MediaListSummary[]>([]);
  expandedSeason = signal<number | null>(null);
  seenPending = signal(false);
  likedPending = signal(false);
  watchlistPending = signal(false);
  listPending = signal<number | null>(null);
  showListPicker = signal(false);
  episodePending = signal<Set<number>>(new Set());
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
        this.credits.set(null);
        this.trailers.set(null);
        this.similar.set([]);
        this.expandedSeason.set(null);
        this.showListPicker.set(false);

        if (type === 'movie') {
          return forkJoin({
            data: this.api.movie(tmdbId),
            credits: this.api.movieCredits(tmdbId).pipe(catchError(() => of(null))),
            trailers: this.api.movieTrailers(tmdbId).pipe(catchError(() => of(null))),
            similar: this.api.similarMovies(tmdbId).pipe(catchError(() => of(null))),
            lists: this.api.lists().pipe(catchError(() => of([]))),
          });
        } else {
          return forkJoin({
            data: this.api.show(tmdbId),
            credits: this.api.showCredits(tmdbId).pipe(catchError(() => of(null))),
            trailers: this.api.showTrailers(tmdbId).pipe(catchError(() => of(null))),
            similar: this.api.similarShows(tmdbId).pipe(catchError(() => of(null))),
            lists: this.api.lists().pipe(catchError(() => of([]))),
          });
        }
      }),
    ).subscribe({
      next: ({ data, credits, trailers, similar, lists }) => {
        if (this.isMovie) {
          this.movie.set(data as MovieDto);
        } else {
          this.show.set(data as ShowDto);
        }
        this.credits.set(credits);
        this.trailers.set(trailers);
        this.similar.set(similar?.results ?? []);
        this.lists.set(lists as MediaListSummary[]);
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

  get currentMedia(): MovieDto | ShowDto | null {
    return this.isMovie ? this.movie() : this.show();
  }

  get currentSeen(): boolean {
    return this.currentMedia?.seen ?? false;
  }

  get currentLiked(): boolean {
    return this.currentMedia?.liked ?? false;
  }

  get currentListIds(): number[] {
    return this.currentMedia?.listIds ?? [];
  }

  get watchlistId(): number | null {
    return this.lists().find(l => l.isSystem && l.name === 'Watchlist')?.id ?? null;
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

  toggleSeen() {
    if (this.seenPending()) return;
    this.seenPending.set(true);

    if (this.isMovie) {
      const m = this.movie();
      if (!m) return;
      const newSeen = !m.seen;
      this.movie.set({ ...m, seen: newSeen });
      this.api.markMovieSeen(m.id, newSeen).subscribe({
        complete: () => this.seenPending.set(false),
        error: () => {
          this.movie.set({ ...m, seen: m.seen });
          this.seenPending.set(false);
        },
      });
    } else {
      const s = this.show();
      if (!s) return;
      const newSeen = !s.seen;
      this.show.set({ ...s, seen: newSeen });
      this.api.markShowSeen(s.id, newSeen).subscribe({
        complete: () => this.seenPending.set(false),
        error: () => {
          this.show.set({ ...s, seen: s.seen });
          this.seenPending.set(false);
        },
      });
    }
  }

  toggleLiked() {
    if (this.likedPending()) return;
    this.likedPending.set(true);

    if (this.isMovie) {
      const m = this.movie();
      if (!m) return;
      const newLiked = !m.liked;
      this.movie.set({ ...m, liked: newLiked });
      this.api.likeMovie(m.tmdbId, newLiked).subscribe({
        complete: () => this.likedPending.set(false),
        error: () => {
          this.movie.set({ ...m, liked: m.liked });
          this.likedPending.set(false);
        },
      });
    } else {
      const s = this.show();
      if (!s) return;
      const newLiked = !s.liked;
      this.show.set({ ...s, liked: newLiked });
      this.api.likeShow(s.tmdbId, newLiked).subscribe({
        complete: () => this.likedPending.set(false),
        error: () => {
          this.show.set({ ...s, liked: s.liked });
          this.likedPending.set(false);
        },
      });
    }
  }

  toggleWatchlist() {
    if (this.watchlistPending()) return;
    this.watchlistPending.set(true);
    const inWatchlist = this.currentInWatchlist;

    const updateListIds = (media: MovieDto | ShowDto, wlId: number, add: boolean) => {
      const ids = add
        ? [...media.listIds, wlId]
        : media.listIds.filter(id => id !== wlId);
      return { ...media, listIds: ids };
    };

    if (this.isMovie) {
      const m = this.movie();
      if (!m) return;
      const wlId = this.watchlistId;
      if (wlId !== null) this.movie.set(updateListIds(m, wlId, !inWatchlist) as MovieDto);
      const req = inWatchlist
        ? this.api.removeMovieFromWatchlist(m.tmdbId)
        : this.api.addMovieToWatchlist(m.tmdbId);
      req.subscribe({
        complete: () => this.watchlistPending.set(false),
        error: () => {
          if (wlId !== null) this.movie.set(updateListIds(m, wlId, inWatchlist) as MovieDto);
          this.watchlistPending.set(false);
        },
      });
    } else {
      const s = this.show();
      if (!s) return;
      const wlId = this.watchlistId;
      if (wlId !== null) this.show.set(updateListIds(s, wlId, !inWatchlist) as ShowDto);
      const req = inWatchlist
        ? this.api.removeShowFromWatchlist(s.tmdbId)
        : this.api.addShowToWatchlist(s.tmdbId);
      req.subscribe({
        complete: () => this.watchlistPending.set(false),
        error: () => {
          if (wlId !== null) this.show.set(updateListIds(s, wlId, inWatchlist) as ShowDto);
          this.watchlistPending.set(false);
        },
      });
    }
  }

  toggleList(listId: number) {
    if (this.listPending() !== null) return;
    this.listPending.set(listId);
    const inList = this.isInList(listId);

    const updateListIds = (media: MovieDto | ShowDto, id: number, add: boolean) => {
      const ids = add
        ? [...media.listIds, id]
        : media.listIds.filter(x => x !== id);
      return { ...media, listIds: ids };
    };

    if (this.isMovie) {
      const m = this.movie();
      if (!m) return;
      this.movie.set(updateListIds(m, listId, !inList) as MovieDto);
      const req = inList
        ? this.api.removeMovieFromList(listId, m.tmdbId)
        : this.api.addMovieToList(listId, m.tmdbId);
      req.subscribe({
        complete: () => this.listPending.set(null),
        error: () => {
          this.movie.set(updateListIds(m, listId, inList) as MovieDto);
          this.listPending.set(null);
        },
      });
    } else {
      const s = this.show();
      if (!s) return;
      this.show.set(updateListIds(s, listId, !inList) as ShowDto);
      const req = inList
        ? this.api.removeShowFromList(listId, s.tmdbId)
        : this.api.addShowToList(listId, s.tmdbId);
      req.subscribe({
        complete: () => this.listPending.set(null),
        error: () => {
          this.show.set(updateListIds(s, listId, inList) as ShowDto);
          this.listPending.set(null);
        },
      });
    }
  }

  toggleSeason(id: number) {
    this.expandedSeason.set(this.expandedSeason() === id ? null : id);
  }

  seasonSeenCount(season: SeasonModel): number {
    return season.episodes.filter(ep => ep.seen).length;
  }

  isEpisodePending(id: number): boolean {
    return this.episodePending().has(id);
  }

  isSeasonPending(id: number): boolean {
    return this.seasonPending().has(id);
  }

  private patchEpisode(episodeId: number, seen: boolean) {
    const s = this.show();
    if (!s) return;
    this.show.set({
      ...s,
      seasons: s.seasons.map(season => ({
        ...season,
        episodes: season.episodes.map(ep => ep.id === episodeId ? { ...ep, seen } : ep),
      })),
    });
  }

  private patchSeason(seasonId: number, seen: boolean) {
    const s = this.show();
    if (!s) return;
    this.show.set({
      ...s,
      seasons: s.seasons.map(season =>
        season.id === seasonId
          ? { ...season, seen, episodes: season.episodes.map(ep => ({ ...ep, seen })) }
          : season
      ),
    });
  }

  toggleEpisodeSeen(ep: EpisodeModel, event: Event) {
    event.stopPropagation();
    if (this.isEpisodePending(ep.id)) return;
    const newSeen = !ep.seen;
    this.episodePending.set(new Set([...this.episodePending(), ep.id]));
    this.patchEpisode(ep.id, newSeen);
    this.api.markEpisodeSeen(ep.id, newSeen).subscribe({
      complete: () => {
        const s = new Set(this.episodePending());
        s.delete(ep.id);
        this.episodePending.set(s);
      },
      error: () => {
        this.patchEpisode(ep.id, ep.seen);
        const s = new Set(this.episodePending());
        s.delete(ep.id);
        this.episodePending.set(s);
      },
    });
  }

  toggleSeasonSeen(season: SeasonModel, event: Event) {
    event.stopPropagation();
    if (this.isSeasonPending(season.id)) return;
    const newSeen = !season.seen;
    this.seasonPending.set(new Set([...this.seasonPending(), season.id]));
    this.patchSeason(season.id, newSeen);
    this.api.markSeasonSeen(season.id, newSeen).subscribe({
      complete: () => {
        const s = new Set(this.seasonPending());
        s.delete(season.id);
        this.seasonPending.set(s);
      },
      error: () => {
        this.patchSeason(season.id, season.seen);
        const s = new Set(this.seasonPending());
        s.delete(season.id);
        this.seasonPending.set(s);
      },
    });
  }

  backdropStyle(path?: string | null): string | null {
    const url = backdropUrl(path, 'original');
    return url
      ? `linear-gradient(to bottom, rgba(14,20,24,0.35) 0%, rgba(14,20,24,0.95) 85%, rgba(14,20,24,1) 100%), url(${url})`
      : null;
  }

  poster(path?: string | null): string | null {
    return posterUrl(path, 'w500');
  }

  profileUrl(path?: string | null): string | null {
    return path ? `https://image.tmdb.org/t/p/w185${path}` : null;
  }

  trailerThumb(key: string): string {
    return `https://img.youtube.com/vi/${key}/mqdefault.jpg`;
  }

  trailerLink(key: string): string {
    return `https://www.youtube.com/watch?v=${key}`;
  }

  year(date?: string | null): string {
    return date ? date.slice(0, 4) : '';
  }

  formatRuntime(min: number): string {
    if (!min) return '';
    const h = Math.floor(min / 60);
    const m = min % 60;
    return h > 0 ? `${h}h${m > 0 ? String(m).padStart(2, '0') + 'min' : ''}` : `${m}min`;
  }

  formatMoney(amount: number): string | null {
    if (!amount) return null;
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency', currency: 'USD', maximumFractionDigits: 0,
    }).format(amount);
  }
}
