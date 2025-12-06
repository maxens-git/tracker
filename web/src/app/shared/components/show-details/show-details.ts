import { Component, OnInit, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { MediaDetailsService } from '../../services/media-details.service';
import { CommonModule } from '@angular/common';
import { ShowDetails } from '../../interfaces/media-details.interface';

@Component({
  selector: 'app-show-details',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './show-details.html',
  styleUrl: './show-details.scss'
})
export class ShowDetailsComponent implements OnInit {
  protected showDetails = signal<ShowDetails | undefined>(undefined);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  constructor(
    private route: ActivatedRoute,
    private mediaDetailsService: MediaDetailsService
  ) {}

  ngOnInit(): void {
    const tmdbId = this.route.snapshot.params['id'];
    
    this.mediaDetailsService.getShowDetails(Number(tmdbId)).subscribe({
      next: (data) => {
        this.showDetails.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        console.error(err);
        this.error.set('Erreur lors du chargement de la série');
        this.loading.set(false);
      }
    });
  }
}
