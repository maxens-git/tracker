export interface Genre {
  id: number;
  name: string;
}

export interface MovieDetails {
  id: number;
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
  status: string | null;
  genres: string | null;
  budget: number | null;
  revenue: number | null;
  imdbId: string | null;
}

export interface SeasonSummary {
  id: number;
  name: string;
  posterPath: string | null;
  episodeCount: number;
}

export interface ShowDetails {
  id: number;
  name: string;
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
  status: string | null;
  numberOfSeasons: number | null;
  numberOfEpisodes: number | null;
  genres: string | null;
  seasons: SeasonSummary[];
}
