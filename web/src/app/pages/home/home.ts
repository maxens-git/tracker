import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { InputTextModule } from 'primeng/inputtext';
import { TrendingHomeData, TMDbSearchResult } from '../../shared/interfaces/tmdb-trending.interface';
import { TrendsService } from '../../shared/services/trends.service';
import { PosterCardComponent } from '../../shared/components/poster-card/poster-card';

@Component({
  selector: 'app-home',
  templateUrl: './home.html',
  styleUrls: ['./home.scss'],
  standalone: true,
  imports: [
    InputTextModule,
    FormsModule,
    CommonModule,
    PosterCardComponent
]
})
export class Home implements OnInit {
  protected searchValue: string = "";
  protected trends = signal<TrendingHomeData | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  protected readonly skeletonTiles = Array.from({ length: 12 }, (_, index) => index);

  constructor(private trendsService: TrendsService, private router: Router) {}

  ngOnInit(): void {
    this.loading.set(true);
    this.error.set(null);

    this.trendsService.getHomeData().subscribe({
      next: (data: TrendingHomeData) => {
        this.trends.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        console.log(err);
        this.error.set('Impossible de charger les tendances pour le moment.');
        this.loading.set(false);
      }
    });
  }

  protected navigateToSearch(): void {
    this.router.navigate(['/search']);
  }

  protected onSelect(item?: TMDbSearchResult): void {
    if (!item?.id) return;
    const target = item.media_type === 'tv' ? '/shows' : '/movies';
    this.router.navigate([target, item.id]);
  }

  protected getTitle(item?: TMDbSearchResult): string {
    return item?.title || item?.name || 'Titre indisponible';
  }

  protected getYear(item?: TMDbSearchResult): string {
    const date = item?.release_date || item?.first_air_date;
    return date ? date.slice(0, 4) : 'N/A';
  }

  protected getTypeLabel(item?: TMDbSearchResult): string {
    if (item?.media_type === 'movie') return 'Film';
    if (item?.media_type === 'tv') return 'Série';
    return 'Titre';
  }

  protected scrollRow(row: HTMLElement | null | undefined, direction: number): void {
    if (!row) return;
    const delta = 320 * direction;
    row.scrollBy({ left: delta, behavior: 'smooth' });
  }
}
