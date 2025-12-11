import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';

@Component({
  selector: 'app-poster-card',
  templateUrl: './poster-card.html',
  styleUrls: ['./poster-card.scss'],
  standalone: true,
  imports: [CommonModule]
})
export class PosterCardComponent {
  @Input({ required: true }) item!: TMDbSearchResult;
  @Output() select = new EventEmitter<number>();

  onSelect(): void {
    if (this.item?.id) {
      this.select.emit(this.item.id);
    }
  }

  getDisplayTitle(): string {
    return this.item?.title || this.item?.name || 'Sans titre';
  }

  getYear(): string {
    const date = this.item?.release_date || this.item?.first_air_date;
    return date ? date.slice(0, 4) : 'N/A';
  }

  getRating(): string {
    if (!this.item?.vote_average) {
      return 'N/A';
    }
    return this.item.vote_average.toFixed(1);
  }

  isSeen(): boolean | null {
    if (this.item?.seen === true) return true;
    if (this.item?.seen === false) return false;
    return null;
  }

  getSeenLabel(): string {
    return this.isSeen() === true ? 'Vu' : 'A voir';
  }
  getType(): string {
    if (this.item?.media_type === 'movie') {
      return 'Film';
    } else if (this.item?.media_type === 'tv') {
      return 'Série';
    }
    return '';
  }
}
