import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Api } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { MediaRow } from '../../../shared/components/media-row/media-row';
import { MovieDto, CreditsDto, TrailersDto } from '../../../shared/interfaces/movie';
import { ShowDto } from '../../../shared/interfaces/show';
import { MediaItem } from '../../../shared/interfaces/media';
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
  expandedSeason = signal<number | null>(null);
  seenPending = signal(false);

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

        if (type === 'movie') {
          return forkJoin({
            data: this.api.movie(tmdbId),
            credits: this.api.movieCredits(tmdbId).pipe(catchError(() => of(null))),
            trailers: this.api.movieTrailers(tmdbId).pipe(catchError(() => of(null))),
            similar: this.api.similarMovies(tmdbId).pipe(catchError(() => of(null))),
          });
        } else {
          return forkJoin({
            data: this.api.show(tmdbId),
            credits: this.api.showCredits(tmdbId).pipe(catchError(() => of(null))),
            trailers: this.api.showTrailers(tmdbId).pipe(catchError(() => of(null))),
            similar: this.api.similarShows(tmdbId).pipe(catchError(() => of(null))),
          });
        }
      }),
    ).subscribe({
      next: ({ data, credits, trailers, similar }) => {
        if (this.isMovie) {
          this.movie.set(data as MovieDto);
        } else {
          this.show.set(data as ShowDto);
        }
        this.credits.set(credits);
        this.trailers.set(trailers);
        this.similar.set(similar?.results ?? []);
        this.loading.set(false);
        window.scrollTo({ top: 0 });
      },
      error: () => {
        this.error.set('Impossible de charger les détails');
        this.loading.set(false);
      },
    });
  }

  goBack() { this.location.back(); }

  get isMovie() { return this.mediaType() === 'movie'; }

  get currentSeen(): boolean {
    return this.isMovie ? (this.movie()?.seen ?? false) : (this.show()?.seen ?? false);
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

  toggleSeason(id: number) {
    this.expandedSeason.set(this.expandedSeason() === id ? null : id);
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
