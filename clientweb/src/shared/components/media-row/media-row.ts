import { ChangeDetectionStrategy, Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaItem } from '../../interfaces/media';
import { PosterCard } from '../poster-card/poster-card';

@Component({
  selector: 'app-media-row',
  standalone: true,
  imports: [CommonModule, PosterCard],
  templateUrl: './media-row.html',
  styleUrl: './media-row.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MediaRow {
  @Input({ required: true }) title!: string;
  @Input({ required: true }) items!: MediaItem[];
}
