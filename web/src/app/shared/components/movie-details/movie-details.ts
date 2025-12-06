import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { CommonModule } from '@angular/common';
import { MovieDetails } from '../../interfaces/media-details.interface';

@Component({
  selector: 'app-movie-details',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './movie-details.html',
  styleUrl: './movie-details.scss'
})
export class MovieDetailsComponent implements OnInit {
  protected movieDetails = signal<MovieDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  constructor(
    private route: ActivatedRoute,
    private mediaDetailsService: MediaDetailsService
  ) {}

  ngOnInit(): void {
    const tmdbId = this.route.snapshot.params['id'];
    
    this.mediaDetailsService.getMovieDetails(Number(tmdbId)).subscribe({
      next: (data) => {
        this.movieDetails.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        console.error(err);
        this.error.set('Erreur lors du chargement du film');
        this.loading.set(false);
      }
    });
  }
}
