import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Api } from '../../../shared/services/api';
import { TrendingHome } from '../../../shared/interfaces/media';
import { RouterLink } from '@angular/router';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { backdropUrl, displayTitle, displayYear } from '../../../shared/services/tmdb-image';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink, MediaRow, Spinner],
  templateUrl: './home.html',
  styleUrl: './home.scss',
})
export class Home implements OnInit {
  private api = inject(Api);

  data = signal<TrendingHome | null>(null);
  loading = signal(true);
  error = signal<string | null>(null);

  ngOnInit() {
    this.api.home().subscribe({
      next: d => { 
        this.data.set(d); this.loading.set(false); 
        console.log(d)
      },
      error: () => { 
        this.error.set('Impossible de charger les tendances'); this.loading.set(false); 
      },
    });
  }

  hero(d: TrendingHome) {
    const item = d.featuredItem;
    if (!item) return null;
    return {
      title: displayTitle(item),
      year: displayYear(item),
      overview: item.overview,
      backdrop: backdropUrl(item.backdrop_path, 'original'),
      link: ['/' + item.media_type, item.id],
    };
  }
}
