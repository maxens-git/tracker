import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { PosterCardComponent } from '../../../shared/components/poster-card/poster-card';
import { TMDbSearchResult } from '../../../shared/interfaces/tmdb-trending.interface';

export interface MediaItem {
  id: number;
  tmdbId: number;
  title: string;
  posterPath: string | null;
  releaseDate?: string | null;
  voteAverage?: number | null;
  type: 'movie' | 'show';
}

@Component({
  selector: 'app-media-grid',
  standalone: true,
  imports: [CommonModule, RouterModule, PosterCardComponent],
  templateUrl: './media-grid.html',
  styleUrl: './media-grid.scss',
})
export class MediaGrid {
  @Input() items: MediaItem[] = [];
  @Input() loading: boolean = false;
  @Input() emptyMessage: string = 'Aucun contenu pour le moment.';

  protected filterType: 'all' | 'movie' | 'show' = 'all';

  constructor(private router: Router) {}

  protected get filteredItems(): MediaItem[] {
    return this.filterType === 'all'
      ? this.items
      : this.items.filter(item => item.type === this.filterType);
  }

  protected changeFilterType(type: 'all' | 'movie' | 'show'): void {
    this.filterType = type;
  }

  protected convertToTMDbResult(item: MediaItem): TMDbSearchResult {
    return {
      id: item.tmdbId,
      media_type: item.type === 'movie' ? 'movie' : 'tv',
      title: item.type === 'movie' ? item.title : undefined,
      name: item.type === 'show' ? item.title : undefined,
      poster_path: item.posterPath || undefined,
      release_date: item.type === 'movie' ? item.releaseDate || undefined : undefined,
      first_air_date: item.type === 'show' ? item.releaseDate || undefined : undefined,
      vote_average: item.voteAverage || 0,
      vote_count: 0,
      popularity: 0
    };
  }

  protected onMediaSelect(tmdbId: number, mediaType: string): void {
    const route = mediaType === 'movie' ? '/movies' : '/shows';
    this.router.navigate([route, tmdbId.toString()]);
  }
}
