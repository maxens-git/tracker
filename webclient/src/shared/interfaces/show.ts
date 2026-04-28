import { RatingsDto } from './movie';

export interface EpisodeModel {
  id: number;
  tmdbId: number;
  name: string;
  overview?: string;
  episodeNumber: number;
  runtime: number;
  voteAverage: number;
  airDate?: string;
  stillPath?: string;
  seen: boolean;
  seasonId: number;
}

export interface SeasonModel {
  id: number;
  tmdbId: number;
  name: string;
  overview?: string;
  seasonNumber: number;
  episodeCount: number;
  airDate?: string;
  posterPath?: string;
  seen: boolean;
  showId: number;
  episodes: EpisodeModel[];
}

export interface ShowDto {
  id: number;
  tmdbId: number;
  title: string;
  originalTitle?: string;
  overview?: string;
  status?: string;
  tagline?: string;
  posterPath?: string;
  backdropPath?: string;
  voteAverage: number;
  voteCount: number;
  popularity: number;
  liked: boolean;
  seen: boolean;
  releaseDate?: string;
  genres?: string;
  addedAt: string;
  updatedAt: string;
  numberOfSeasons: number;
  numberOfEpisodes: number;
  lastAirDate?: string;
  seasons: SeasonModel[];
  listIds: number[];
  ratings: RatingsDto;
}
