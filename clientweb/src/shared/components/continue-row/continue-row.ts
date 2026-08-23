import { ChangeDetectionStrategy, Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TagModule } from 'primeng/tag';
import { ProgressBarModule } from 'primeng/progressbar';
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
  imports: [CommonModule, RouterLink, TagModule, ProgressBarModule],
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
    const next = this.nextEpisode(item, lastSeasonNumber, lastEpisodeNumber);
    return {
      title: displayTitle(item),
      // Format paysage : backdrop si dispo, sinon repli sur le poster.
      image: backdropUrl(item.backdrop_path, 'w780') ?? posterUrl(item.poster_path, 'w500'),
      progress: `S${next.season} · E${next.episode}`,
      percent,
      link: ['/' + item.media_type, item.id],
    };
  }

  /**
   * Prochain épisode à regarder : dernier vu + 1, ou première de la saison suivante
   * si le dernier vu clôt sa saison. On ignore la saison 0 (épisodes spéciaux).
   */
  private nextEpisode(item: MediaItem, lastSeason: number, lastEpisode: number): { season: number; episode: number } {
    const seasons = (item.seasons ?? [])
      .filter(s => s.season_number > 0)
      .sort((a, b) => a.season_number - b.season_number);

    const current = seasons.find(s => s.season_number === lastSeason);
    if (current && lastEpisode < current.episode_count) {
      return { season: lastSeason, episode: lastEpisode + 1 };
    }

    const nextSeason = seasons.find(s => s.season_number > lastSeason && s.episode_count > 0);
    if (nextSeason) {
      return { season: nextSeason.season_number, episode: 1 };
    }

    // Pas d'info de saisons fiable : on retombe sur « dernier vu + 1 ».
    return { season: lastSeason, episode: lastEpisode + 1 };
  }
}
