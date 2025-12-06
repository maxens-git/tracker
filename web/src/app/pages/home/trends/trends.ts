import { Component, input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TrendingHomeData, TMDbSearchResult } from '../../../shared/interfaces/tmdb-trending.interface';

@Component({
  selector: 'app-trends',
  templateUrl: './trends.html',
  styleUrls: ['./trends.scss'],
  standalone: true,
  imports: [CommonModule],
})
export class Trends {
  trends = input<TrendingHomeData | undefined>();
  private router = inject(Router);

  navigateToMovie(id: number): void {
    this.router.navigate(['/movies', id]);
  }

  navigateToShow(id: number): void {
    this.router.navigate(['/shows', id]);
  }

  navigateToMedia(item: TMDbSearchResult): void {
    if (item.media_type === 'movie') {
      this.router.navigate(['/movies', item.id]);
    } else if (item.media_type === 'tv') {
      this.router.navigate(['/shows', item.id]);
    }
  }

  getDisplayTitle(item: TMDbSearchResult): string {
    return item.title || item.name || 'Sans titre';
  }

  getYear(item: TMDbSearchResult): string {
    const date = item.release_date || item.first_air_date;
    return date ? date.slice(0, 4) : 'N/A';
  }

  getRating(item: TMDbSearchResult): string {
    if (!item.vote_average) {
      return 'N/A';
    }
    return item.vote_average.toFixed(1);
  }

  getMediaTypeLabel(item: TMDbSearchResult): string {
    if (item.media_type === 'movie') {
      return 'Film';
    }
    if (item.media_type === 'tv') {
      return 'Serie';
    }
    return 'Media';
  }
}
