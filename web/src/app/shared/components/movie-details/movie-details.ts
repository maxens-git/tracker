import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { SimilarService } from '../../services/similar.service';
import { MediaListsService } from '../../services/media-lists.service';
import { CommonModule } from '@angular/common';
import { MovieDetails } from '../../interfaces/media-details.interface';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';
import { PosterCardComponent } from '../poster-card/poster-card';

@Component({
  selector: 'app-movie-details',
  standalone: true,
  imports: [CommonModule, PosterCardComponent],
  templateUrl: './movie-details.html',
  styleUrl: './movie-details.scss'
})
export class MovieDetailsComponent implements OnInit {
  protected movieDetails = signal<MovieDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected likeLoading = signal<boolean>(false);
  protected error = signal<string | null>(null);
  protected similar = signal<TMDbSearchResult[]>([]);
  protected similarLoading = signal<boolean>(true);

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
      this.fetchMovie(tmdbId);
    });
  }

  private loadSimilarMovies(tmdbId: number): void {
    this.similarLoading.set(true);
    this.similarService.getSimilarMovies(tmdbId).subscribe({
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
    this.router.navigate(['/movies', tmdbId]);
  }

  protected toggleLike(): void {
    const movie = this.movieDetails();
    if (!movie) return;

    this.likeLoading.set(true);
    const next = !movie.liked;

    this.mediaListsService.setMovieLiked(movie.tmdbId, next).subscribe({
      next: (res) => {
        this.movieDetails.update((current) => current ? { ...current, liked: res.liked } : current);
        this.likeLoading.set(false);
      },
      error: () => {
        this.likeLoading.set(false);
      }
    });
  }

  private fetchMovie(tmdbId: number): void {
    this.loading.set(true);
    this.error.set(null);
    this.movieDetails.set(undefined);

    this.mediaDetailsService.getMovieDetails(tmdbId).subscribe({
      next: (data) => {
        this.movieDetails.set(data);
        this.loading.set(false);
        this.loadSimilarMovies(tmdbId);
      },
      error: () => {
        this.error.set('Erreur lors du chargement du film');
        this.loading.set(false);
      }
    });
  }
}
