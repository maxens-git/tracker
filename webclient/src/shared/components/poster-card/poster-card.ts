import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaItem } from '../../interfaces/media';
import { posterUrl, displayTitle, displayYear } from '../../services/tmdb-image';

@Component({
  selector: 'app-poster-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './poster-card.html',
  styleUrl: './poster-card.scss',
})
export class PosterCard {
  @Input({ required: true }) item!: MediaItem;

  get poster() { return posterUrl(this.item.poster_path); }
  get title() { return displayTitle(this.item); }
  get year() { return displayYear(this.item); }
  get rating() { return this.item.vote_average ? this.item.vote_average.toFixed(1) : null; }
}
