import { CommonModule } from '@angular/common';
import { Component, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CardModule } from 'primeng/card';
import { TagModule } from 'primeng/tag';
import { InputTextModule } from 'primeng/inputtext';
import { ButtonModule } from 'primeng/button';
import { TMDbSearchResult } from '../../shared/interfaces/tmdb-trending.interface';
import { SearchService } from '../../shared/services/search.service';
import { SearchResponse } from '../../shared/interfaces/search-response.interface';
import { take } from 'rxjs';
import { PosterCardComponent } from '../../shared/components/poster-card/poster-card';

@Component({
  selector: 'app-search',
  imports: [CommonModule, FormsModule, CardModule, TagModule, InputTextModule, ButtonModule, PosterCardComponent],
  templateUrl: './search.html',
  styleUrl: './search.scss',
})
export class Search {
  query = '';
  results = signal<TMDbSearchResult[]>([]);
  loading = signal(false);
  error = signal<string | undefined>(undefined);

  constructor(private readonly searchService: SearchService) {}

  protected fetchResults(): void {
    this.loading.set(true);
    this.error.set(undefined);

    this.searchService.search(this.query, 1, 10).pipe(take(1)).subscribe({
      next: (response: SearchResponse) => {
        this.results.set(response?.results ?? []);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossible de récupérer les résultats pour le moment.');
        this.results.set([]);
        this.loading.set(false);
      }
    });
  }

  typeLabel(item: TMDbSearchResult): string {
    return item.media_type === 'movie' ? 'Film' : 'Série';
  }

  posterUrl(item: TMDbSearchResult): string | undefined {
    return item.poster_path ? `https://image.tmdb.org/t/p/w342${item.poster_path}` : undefined;
  }

}
