import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { SimilarService } from '../../services/similar.service';
import { CommonModule } from '@angular/common';
import { ShowDetails } from '../../interfaces/media-details.interface';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';
import { PosterCardComponent } from '../poster-card/poster-card';

@Component({
  selector: 'app-show-details',
  standalone: true,
  imports: [CommonModule, PosterCardComponent],
  templateUrl: './show-details.html',
  styleUrl: './show-details.scss'
})
export class ShowDetailsComponent implements OnInit {
  protected showDetails = signal<ShowDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);
  protected similar = signal<TMDbSearchResult[]>([]);
  protected similarLoading = signal<boolean>(true);
  protected expandedSeasonId = signal<number | null>(null);
  protected expandedEpisodes = signal<Set<number>>(new Set());

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private mediaDetailsService: MediaDetailsService,
    private similarService: SimilarService
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
        this.loadSimilarShows(tmdbId);
      },
      error: () => {
        this.error.set('Erreur lors du chargement de la série');
        this.loading.set(false);
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

  protected onSimilarSelect(tmdbId: number): void {
    if (!tmdbId) return;
    this.router.navigate(['/shows', tmdbId]);
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
}
