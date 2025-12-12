export interface Genre {
  id: number;
  name: string;
}

export interface MediaRatings {
  tmdbRating: number | null;
  tmdbVotes: number | null;
  imdbRating: number | null;
  imdbVotes: number | null;
  rottenTomatoesRating: number | null;
}

export interface MovieDetails {
  id: number;
  tmdbId: number;
  title: string;
  originalTitle: string | null;
  overview: string;
  posterPath: string | null;
  backdropPath: string | null;
  releaseDate: string | null;
  runtime: number | null;
  tagline: string | null;
  voteAverage: number | null;
  voteCount: number | null;
  popularity: number | null;
  ratings?: MediaRatings | null;
  liked: boolean;
  seen: boolean;
  status: string | null;
  genres: string | null;
  budget: number | null;
  revenue: number | null;
  imdbId: string | null;
  listIds?: number[];
}

export interface EpisodeSummary {
  id: number;
  name: string;
  overview: string | null;
  episodeNumber: number;
  runtime: number;
  voteAverage: number;
  airDate: string | null;
  stillPath: string | null;
  seen: boolean;
}

export interface SeasonSummary {
  id: number;
  name: string;
  posterPath: string | null;
  episodeCount: number;
  seasonNumber?: number | null;
  overview?: string | null;
  airDate?: string | null;
  seen: boolean;
  episodes?: EpisodeSummary[];
}

export interface ShowDetails {
  id: number;
  tmdbId: number;
  title: string;
  originalTitle: string | null;
  overview: string;
  posterPath: string | null;
  backdropPath: string | null;
  releaseDate: string | null;
  lastAirDate: string | null;
  tagline: string | null;
  voteAverage: number | null;
  voteCount: number | null;
  popularity: number | null;
  ratings?: MediaRatings | null;
  liked: boolean;
  seen: boolean;
  status: string | null;
  numberOfSeasons: number | null;
  numberOfEpisodes: number | null;
  genres: string | null;
  seasons: SeasonSummary[];
  listIds?: number[];
}
