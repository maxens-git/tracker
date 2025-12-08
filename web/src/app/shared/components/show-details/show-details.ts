import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { SimilarService } from '../../services/similar.service';
import { MediaListsService } from '../../services/media-lists.service';
import { CommonModule } from '@angular/common';
import { ShowDetails } from '../../interfaces/media-details.interface';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';
import { PosterCardComponent } from '../poster-card/poster-card';
import { MediaListSummary } from '../../interfaces/media-list.interface';

@Component({
  selector: 'app-show-details',
  standalone: true,
  imports: [CommonModule, PosterCardComponent],
  templateUrl: './show-details.html',
  styleUrl: './show-details.scss'
})
export class ShowDetailsComponent implements OnInit {
  protected listActionLoading = signal<{ [listId: number]: boolean }>({});
  protected showDetails = signal<ShowDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected likeLoading = signal<boolean>(false);
  protected seenLoading = signal<boolean>(false);
  protected watchlistLoading = signal<boolean>(false);
  protected inWatchlist = signal<boolean>(false);
  protected watchlistId = signal<number | null>(null);
  protected showListModal = signal<boolean>(false);
  protected lists = signal<MediaListSummary[]>([]);
  protected listLoading = signal<boolean>(false);
  protected seasonSeenLoading = signal<Map<number, boolean>>(new Map());
  protected episodeSeenLoading = signal<Map<number, boolean>>(new Map());
  protected error = signal<string | null>(null);
  protected similar = signal<TMDbSearchResult[]>([]);
  protected similarLoading = signal<boolean>(true);
  protected expandedSeasonId = signal<number | null>(null);
  protected expandedEpisodes = signal<Set<number>>(new Set());
  protected ratingModalOpen = signal<boolean>(false);

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private mediaDetailsService: MediaDetailsService,
    private similarService: SimilarService,
    private mediaListsService: MediaListsService
  ) {}

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const tmdbId = Number(params.get('id'));
      if (!tmdbId) return;
      this.fetchShow(tmdbId);
    });
  }

  private fetchShow(tmdbId: number): void {
    this.loading.set(true);
    this.error.set(null);
    this.showDetails.set(undefined);

    this.mediaDetailsService.getShowDetails(tmdbId).subscribe({
      next: (data) => {
        this.showDetails.set(data);
        this.loading.set(false);
        this.setWatchlistState(data);
        this.loadSimilarShows(tmdbId);
      },
      error: () => {
        this.error.set('Erreur lors du chargement de la série');
        this.loading.set(false);
      }
    });
  }

  // Determine watchlist id and whether show is in it
  private setWatchlistState(show: ShowDetails): void {
    this.mediaListsService.getAll().subscribe({
      next: (lists) => {
        this.lists.set(lists);
        const watch = lists.find(l => l.isSystem && l.name === 'Watchlist');
        if (watch) {
          this.watchlistId.set(watch.id);
          this.inWatchlist.set(!!show.listIds?.includes(watch.id));
        } else {
          this.watchlistId.set(null);
          this.inWatchlist.set(false);
        }
      },
      error: () => {
        this.watchlistId.set(null);
        this.inWatchlist.set(false);
      }
    });
  }

  private loadSimilarShows(tmdbId: number): void {
    this.similarLoading.set(true);
    this.similarService.getSimilarShows(tmdbId).subscribe({
      next: (response) => {
        this.similar.set(response.results ?? []);
        this.similarLoading.set(false);
      },
      error: () => {
        this.similar.set([]);
        this.similarLoading.set(false);
      }
    });
  }

  protected openListModal(): void {
    this.showListModal.set(true);
    this.listLoading.set(true);
    this.mediaListsService.getAll().subscribe({
      next: (data) => {
        this.lists.set(data);
        this.listLoading.set(false);
      },
      error: () => {
        this.listLoading.set(false);
      }
    });
  }

  protected closeListModal(): void {
    this.showListModal.set(false);
  }

  protected addToList(listId: number): void {
    const show = this.showDetails();
    if (!show) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.addShowToList(listId, show.tmdbId).subscribe({
      next: () => {
        this.showDetails.update(current => current ? { ...current, listIds: [...(current.listIds || []), listId] } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error adding show to list:', err);
      }
    });
  }

  protected removeFromList(listId: number): void {
    const show = this.showDetails();
    if (!show) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.removeShowFromList(listId, show.tmdbId).subscribe({
      next: () => {
        this.showDetails.update(current => current ? { ...current, listIds: (current.listIds || []).filter(id => id !== listId) } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error removing show from list:', err);
      }
    });
  }

  protected isInList(listId: number): boolean {
    const show = this.showDetails();
    return !!show?.listIds?.includes(listId);
  }

  protected toggleWatchlist(): void {
    const show = this.showDetails();
    if (!show) return;

    this.watchlistLoading.set(true);
    if (this.inWatchlist()) {
      this.mediaListsService.removeShowFromWatchlist(show.tmdbId).subscribe({
        next: () => {
          this.inWatchlist.set(false);
          const wid = this.watchlistId();
          if (wid) {
            this.showDetails.update(current => current ? { ...current, listIds: (current.listIds || []).filter(id => id !== wid) } : current);
          }
          this.watchlistLoading.set(false);
        },
        error: () => {
          this.watchlistLoading.set(false);
        }
      });
    } else {
      this.mediaListsService.addShowToWatchlist(show.tmdbId).subscribe({
        next: () => {
          this.inWatchlist.set(true);
          const wid = this.watchlistId();
          if (wid) {
            this.showDetails.update(current => current ? { ...current, listIds: [...(current.listIds || []), wid] } : current);
          }
          this.watchlistLoading.set(false);
        },
        error: () => {
          this.watchlistLoading.set(false);
        }
      });
    }
  }

  protected onSimilarSelect(tmdbId: number): void {
    if (!tmdbId) return;
    this.router.navigate(['/shows', tmdbId]);
  }

  protected toggleLike(): void {
    const show = this.showDetails();
    if (!show) return;

    this.likeLoading.set(true);
    const next = !show.liked;

    this.mediaListsService.setShowLiked(show.tmdbId, next).subscribe({
      next: (res) => {
        this.showDetails.update((current) => current ? { ...current, liked: res.liked } : current);
        this.likeLoading.set(false);
      },
      error: () => {
        this.likeLoading.set(false);
      }
    });
  }

  protected toggleSeen(): void {
    const show = this.showDetails();
    if (!show) return;

    this.seenLoading.set(true);
    const next = !show.seen;

    this.mediaListsService.setShowSeen(show.id, next).subscribe({
      next: (res) => {
        this.showDetails.update((current) => {
          if (!current) return current;
          const updated = { ...current, seen: res.seen };
          updated.seasons = updated.seasons.map(s => ({ ...s, seen: res.seen, episodes: s.episodes?.map(e => ({ ...e, seen: res.seen })) }));
          return updated;
        });
        this.seenLoading.set(false);
      },
      error: () => {
        this.seenLoading.set(false);
      }
    });
  }

  protected toggleSeasonSeen(seasonId: number): void {
    const show = this.showDetails();
    if (!show) return;

    const loadingMap = new Map(this.seasonSeenLoading());
    loadingMap.set(seasonId, true);
    this.seasonSeenLoading.set(loadingMap);

    const season = show.seasons.find(s => s.id === seasonId);
    if (!season) return;

    const next = !season.seen;

    this.mediaListsService.setSeasonSeen(seasonId, next).subscribe({
      next: (res) => {
        this.showDetails.update((current) => {
          if (!current) return current;
          const updated = { ...current };
          updated.seasons = updated.seasons.map(s => 
            s.id === seasonId 
              ? { ...s, seen: res.seen, episodes: s.episodes?.map(e => ({ ...e, seen: res.seen })) }
              : s
          );
          return updated;
        });
        const newLoadingMap = new Map(this.seasonSeenLoading());
        newLoadingMap.delete(seasonId);
        this.seasonSeenLoading.set(newLoadingMap);
      },
      error: () => {
        const newLoadingMap = new Map(this.seasonSeenLoading());
        newLoadingMap.delete(seasonId);
        this.seasonSeenLoading.set(newLoadingMap);
      }
    });
  }

  protected toggleEpisodeSeen(episodeId: number): void {
    const show = this.showDetails();
    if (!show) return;

    const loadingMap = new Map(this.episodeSeenLoading());
    loadingMap.set(episodeId, true);
    this.episodeSeenLoading.set(loadingMap);

    let episode: any = null;
    for (const season of show.seasons) {
      episode = season.episodes?.find(e => e.id === episodeId);
      if (episode) break;
    }

    if (!episode) return;

    const next = !episode.seen;

    this.mediaListsService.setEpisodeSeen(episodeId, next).subscribe({
      next: (res) => {
        this.showDetails.update((current) => {
          if (!current) return current;
          const updated = { ...current };
          updated.seasons = updated.seasons.map(s => ({
            ...s,
            episodes: s.episodes?.map(e => 
              e.id === episodeId ? { ...e, seen: res.seen } : e
            )
          }));
          return updated;
        });
        const newLoadingMap = new Map(this.episodeSeenLoading());
        newLoadingMap.delete(episodeId);
        this.episodeSeenLoading.set(newLoadingMap);
      },
      error: () => {
        const newLoadingMap = new Map(this.episodeSeenLoading());
        newLoadingMap.delete(episodeId);
        this.episodeSeenLoading.set(newLoadingMap);
      }
    });
  }

  protected toggleSeason(seasonId: number): void {
    if (!seasonId) return;
    const nextSeason = this.expandedSeasonId() === seasonId ? null : seasonId;
    this.expandedSeasonId.set(nextSeason);
    this.expandedEpisodes.set(new Set());
  }

  protected expandedSeason() {
    const show = this.showDetails();
    const id = this.expandedSeasonId();
    if (!show || id === null) return undefined;
    return show.seasons.find(s => s.id === id);
  }

  protected isEpisodeExpanded(episodeId: number): boolean {
    return this.expandedEpisodes().has(episodeId);
  }

  protected toggleEpisode(episodeId: number): void {
    if (!episodeId) return;
    const next = new Set(this.expandedEpisodes());
    if (next.has(episodeId)) {
      next.delete(episodeId);
    } else {
      next.add(episodeId);
    }
    this.expandedEpisodes.set(next);
  }

  protected openRatingModal(): void {
    if (!this.showDetails()) return;
    this.ratingModalOpen.set(true);
  }

  protected closeRatingModal(): void {
    this.ratingModalOpen.set(false);
  }

  protected ratingSeasons() {
    const show = this.showDetails();
    if (!show) return [];

    return [...show.seasons]
      .sort((a, b) => (a.seasonNumber ?? 0) - (b.seasonNumber ?? 0))
      .map((season) => ({
        ...season,
        episodes: [...(season.episodes ?? [])].sort((a, b) => a.episodeNumber - b.episodeNumber)
      }));
  }

  protected ratingTableRows() {
    const seasons = this.ratingSeasons();
    if (!seasons.length) return [];

    const maxEpisodes = Math.max(...seasons.map((s) => s.episodes.length));
    const rows: { episodeNumber: number; scores: (number | null)[] }[] = [];

    for (let ep = 1; ep <= maxEpisodes; ep++) {
      const scores = seasons.map((season) => {
        const match = season.episodes.find((e) => e.episodeNumber === ep);
        return match?.voteAverage ?? null;
      });
      rows.push({ episodeNumber: ep, scores });
    }

    return rows;
  }

  protected ratingClass(score: number | null): string {
    if (score === null) return 'score-none';
    if (score >= 8.5) return 'score-elite';
    if (score >= 7.5) return 'score-strong';
    if (score >= 6.5) return 'score-good';
    if (score >= 5.5) return 'score-ok';
    if (score >= 4.5) return 'score-weak';
    return 'score-bad';
  }
}
