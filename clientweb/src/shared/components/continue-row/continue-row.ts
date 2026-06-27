import { ChangeDetectionStrategy, Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MediaItem } from '../../interfaces/media';
import { backdropUrl, posterUrl, displayTitle } from '../../services/tmdb-image';

/** Une série « en cours » : la fiche TMDB + la progression de l'utilisateur. */
export interface ContinueItem {
  item: MediaItem;
  lastSeasonNumber: number;
  lastEpisodeNumber: number;
  seenEpisodeCount: number;
}

interface ContinueCard {
  title: string;
  image: string | null;
  progress: string;
  /** Pourcentage d'épisodes vus (0–100) pour la barre, ou null si total inconnu. */
  percent: number | null;
  link: (string | number)[];
}

@Component({
  selector: 'app-continue-row',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './continue-row.html',
  styleUrl: './continue-row.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ContinueRow {
  @Input({ required: true }) title!: string;
  @Input({ required: true }) items!: ContinueItem[];

  card(entry: ContinueItem): ContinueCard {
    const { item, lastSeasonNumber, lastEpisodeNumber, seenEpisodeCount } = entry;
    const total = item.number_of_episodes ?? 0;
    const percent = total > 0 ? Math.min(100, Math.round((seenEpisodeCount / total) * 100)) : null;
    return {
      title: displayTitle(item),
      // Format paysage : backdrop si dispo, sinon repli sur le poster.
      image: backdropUrl(item.backdrop_path, 'w780') ?? posterUrl(item.poster_path, 'w500'),
      progress: `S${lastSeasonNumber} · E${lastEpisodeNumber}`,
      percent,
      link: ['/' + item.media_type, item.id],
    };
  }
}
