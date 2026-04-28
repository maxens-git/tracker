import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged, switchMap } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { MediaItem } from '../../../shared/interfaces/media';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [CommonModule, FormsModule, PosterCard, Spinner],
  templateUrl: './search.html',
  styleUrl: './search.scss',
})
export class Search {
  private api = inject(Api);
  private query$ = new Subject<string>();

  query = '';
  results = signal<MediaItem[]>([]);
  loading = signal(false);
  searched = signal(false);

  constructor() {
    this.query$.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(q => {
        if (!q.trim()) {
          this.results.set([]);
          this.searched.set(false);
          this.loading.set(false);
          return [];
        }
        this.loading.set(true);
        this.searched.set(true);
        return this.api.search(q);
      }),
    ).subscribe({
      next: r => { this.results.set(r.results); this.loading.set(false); },
      error: () => { this.loading.set(false); },
    });
  }

  onInput() { this.query$.next(this.query); }
}
