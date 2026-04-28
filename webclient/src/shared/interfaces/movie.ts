export interface MovieDto {
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
  runtime: number;
  budget: number;
  revenue: number;
  imdbId?: string;
  listIds: number[];
  ratings: RatingsDto;
}

export interface RatingsDto {
  tmdbRating?: number;
  tmdbVotes?: number;
  imdbRating?: number;
  imdbVotes?: number;
  rottenTomatoesRating?: number;
}

export interface CastMemberDto {
  id: number;
  name: string;
  character?: string;
  profilePath?: string;
  order: number;
  knownForDepartment?: string;
}

export interface CrewMemberDto {
  id: number;
  name: string;
  job?: string;
  department?: string;
  profilePath?: string;
}

export interface CreditsDto {
  tmdbId: number;
  cast: CastMemberDto[];
  crew: CrewMemberDto[];
}

export interface TrailerDto {
  id: string;
  name: string;
  key: string;
  site: string;
  type: string;
  official: boolean;
  language?: string;
  publishedAt?: string;
}

export interface TrailersDto {
  tmdbId: number;
  trailers: TrailerDto[];
}
