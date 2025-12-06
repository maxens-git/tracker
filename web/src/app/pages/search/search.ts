import { CommonModule } from '@angular/common';
import { Component, OnDestroy, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { InputTextModule } from 'primeng/inputtext';
import { TMDbSearchResult } from '../../shared/interfaces/tmdb-trending.interface';
import { SearchService } from '../../shared/services/search.service';
import { SearchResponse } from '../../shared/interfaces/search-response.interface';
import { PosterCardComponent } from '../../shared/components/poster-card/poster-card';
import { Subscription, take } from 'rxjs';

@Component({
  selector: 'app-search',
  imports: [CommonModule, FormsModule, InputTextModule, PosterCardComponent],
  templateUrl: './search.html',
  styleUrl: './search.scss',
})
export class Search implements OnDestroy {
  query = '';
  readonly pageSize = 12;
  results = signal<TMDbSearchResult[]>([]);
  loading = signal(false);
  loadingMore = signal(false);
  error = signal<string | undefined>(undefined);
  currentPage = signal(1);
  totalPages = signal(1);
  totalResults = signal(0);

  private debounceHandle?: ReturnType<typeof setTimeout>;
  private searchSub?: Subscription;

  constructor(private readonly searchService: SearchService) {}

  ngOnDestroy(): void {
    clearTimeout(this.debounceHandle);
    this.searchSub?.unsubscribe();
  }

  protected onQueryChange(value: string): void {
    this.query = value ?? '';
    const trimmed = this.query.trim();

    clearTimeout(this.debounceHandle);

    if (!trimmed) {
      this.searchSub?.unsubscribe();
      this.loading.set(false);
      this.loadingMore.set(false);
      this.error.set(undefined);
      this.results.set([]);
      this.currentPage.set(1);
      this.totalPages.set(1);
      this.totalResults.set(0);
      return;
    }

    this.debounceHandle = setTimeout(() => this.fetchResults(trimmed), 250);
    this.currentPage.set(1);
    this.totalPages.set(1);
    this.totalResults.set(0);
  }

  loadMore(): void {
    const nextPage = this.currentPage() + 1;
    if (nextPage <= this.totalPages()) {
      this.fetchResults(this.query.trim(), nextPage, true);
    }
  }

  hasMore(): boolean {
    return this.currentPage() < this.totalPages();
  }

  private fetchResults(query: string, page: number = 1, append = false): void {
    const isAppend = append === true;
    if (isAppend) {
      this.loadingMore.set(true);
    } else {
      this.loading.set(true);
      this.results.set([]);
    }

    this.error.set(undefined);

    this.searchSub?.unsubscribe();
    this.searchSub = this.searchService.search(query, page, this.pageSize).pipe(take(1)).subscribe({
      next: (response: SearchResponse) => {
        const incoming = response?.results ?? [];
        this.totalPages.set(response?.total_pages ?? 1);
        this.totalResults.set(response?.total_results ?? incoming.length);
        this.currentPage.set(response?.page ?? page);

        if (isAppend) {
          this.results.set([...this.results(), ...incoming]);
        } else {
          this.results.set(incoming);
        }

        this.loading.set(false);
        this.loadingMore.set(false);
      },
      error: () => {
        this.error.set('Impossible de récupérer les résultats pour le moment.');
        if (!isAppend) {
          this.results.set([]);
          this.totalPages.set(1);
          this.totalResults.set(0);
          this.currentPage.set(1);
        }
        this.loading.set(false);
        this.loadingMore.set(false);
      }
    });
  }


}
