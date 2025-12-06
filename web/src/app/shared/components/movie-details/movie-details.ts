
import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { SimilarService } from '../../services/similar.service';
import { MediaListsService } from '../../services/media-lists.service';
import { CommonModule } from '@angular/common';
import { MovieDetails } from '../../interfaces/media-details.interface';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';
import { PosterCardComponent } from '../poster-card/poster-card';
import { MediaListSummary } from '../../interfaces/media-list.interface';

@Component({
  selector: 'app-movie-details',
  standalone: true,
  imports: [CommonModule, PosterCardComponent],
  templateUrl: './movie-details.html',
  styleUrl: './movie-details.scss'
})
export class MovieDetailsComponent implements OnInit {
    protected listActionLoading = signal<{ [listId: number]: boolean }>({});
  protected movieDetails = signal<MovieDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected likeLoading = signal<boolean>(false);
  protected seenLoading = signal<boolean>(false);
  protected error = signal<string | null>(null);
  protected similar = signal<TMDbSearchResult[]>([]);
  protected similarLoading = signal<boolean>(true);
  protected showListModal = signal<boolean>(false);
  protected lists = signal<MediaListSummary[]>([]);
  protected listLoading = signal<boolean>(false);

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

  protected toggleSeen(): void {
    const movie = this.movieDetails();
    if (!movie) return;

    this.seenLoading.set(true);
    const next = !movie.seen;

    this.mediaListsService.setMovieSeen(movie.id, next).subscribe({
      next: (res) => {
        this.movieDetails.update((current) => current ? { ...current, seen: res.seen } : current);
        this.seenLoading.set(false);
      },
      error: () => {
        this.seenLoading.set(false);
      }
    });
  }

  protected openListModal(): void {
    this.showListModal.set(true);
    this.listLoading.set(true);
    this.mediaListsService.getAll().subscribe({
      next: (data) => {
        this.lists.set(data);
        this.listLoading.set(false);
      },
      error: () => {
        this.listLoading.set(false);
      }
    });
  }

  protected closeListModal(): void {
    this.showListModal.set(false);
  }

  protected addToList(listId: number): void {
    const movie = this.movieDetails();
    if (!movie) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.addMovieToList(listId, movie.tmdbId).subscribe({
      next: () => {
        this.movieDetails.update(current => current ? { ...current, listIds: [...(current.listIds || []), listId] } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error adding movie to list:', err);
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
        console.log(data)
      },
      error: () => {
        this.error.set('Erreur lors du chargement du film');
        this.loading.set(false);
      }
    });
  }

  protected isInList(listId: number): boolean {
    const movie = this.movieDetails();
    return !!movie?.listIds?.includes(listId);
  }

  protected removeFromList(listId: number): void {
    const movie = this.movieDetails();
    if (!movie) return;
    this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: true }));
    this.mediaListsService.removeMovieFromList(listId, movie.tmdbId).subscribe({
      next: () => {
        this.movieDetails.update(current => current ? { ...current, listIds: (current.listIds || []).filter(id => id !== listId) } : current);
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
      },
      error: (err) => {
        this.listActionLoading.update((state: { [listId: number]: boolean }) => ({ ...state, [listId]: false }));
        console.error('Error removing movie from list:', err);
      }
    });
    
  }
}
