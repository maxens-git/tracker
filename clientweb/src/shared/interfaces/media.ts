// ── User state ──────────────────────────────────────────────────────────────

export interface UserState {
  tmdbId: number;
  seen: boolean;
  liked: boolean;
  listIds: number[];
}

// ── TMDB raw responses ───────────────────────────────────────────────────────

export interface TmdbGenre { id: number; name: string; }

export interface TmdbMovie {
  id: number;
  title: string;
  original_title: string;
  overview: string;
  poster_path: string | null;
  backdrop_path: string | null;
  release_date: string;
  vote_average: number;
  vote_count: number;
  popularity: number;
  runtime: number;
  budget: number;
  revenue: number;
  status: string;
  tagline: string;
  imdb_id: string | null;
  genres: TmdbGenre[];
}

export interface TmdbShow {
  id: number;
  name: string;
  original_name: string;
  overview: string;
  poster_path: string | null;
  backdrop_path: string | null;
  first_air_date: string;
  last_air_date: string;
  vote_average: number;
  vote_count: number;
  popularity: number;
  status: string;
  tagline: string;
  number_of_seasons: number;
  number_of_episodes: number;
  genres: TmdbGenre[];
  seasons: TmdbSeasonSummary[];
}

export interface TmdbSeasonSummary {
  id: number;
  season_number: number;
  name: string;
  episode_count: number;
  air_date: string | null;
  poster_path: string | null;
  overview: string;
}

export interface TmdbSeason {
  id: number;
  season_number: number;
  name: string;
  overview: string;
  air_date: string | null;
  poster_path: string | null;
  episodes: TmdbEpisode[];
}

export interface TmdbEpisode {
  id: number;
  episode_number: number;
  season_number: number;
  name: string;
  overview: string;
  runtime: number | null;
  vote_average: number;
  air_date: string | null;
  still_path: string | null;
  seen?: boolean;
}

export interface TmdbCastMember {
  id: number;
  name: string;
  character: string;
  profile_path: string | null;
  order: number;
  known_for_department: string;
}

export interface TmdbCrewMember {
  id: number;
  name: string;
  job: string;
  department: string;
  profile_path: string | null;
}

export interface TmdbCredits {
  cast: TmdbCastMember[];
  crew: TmdbCrewMember[];
}

export interface TmdbVideo {
  id: string;
  name: string;
  key: string;
  site: string;
  type: string;
  official: boolean;
  iso_639_1: string;
  published_at: string;
}

export interface TmdbVideos {
  results: TmdbVideo[];
}

export interface TmdbSearchResponse {
  page: number;
  results: MediaItem[];
  total_pages: number;
  total_results: number;
}

export interface TmdbTrendingResult {
  page: number;
  results: MediaItem[];
  total_pages: number;
  total_results: number;
}

// ── Display model (used in UI components) ───────────────────────────────────

export interface MediaItem {
  id: number;
  media_type: string;
  title?: string | null;
  name?: string | null;
  original_title?: string | null;
  original_name?: string | null;
  overview?: string | null;
  poster_path?: string | null;
  backdrop_path?: string | null;
  release_date?: string | null;
  first_air_date?: string | null;
  genre_ids?: number[];
  vote_average: number;
  vote_count: number;
  popularity: number;
  seen: boolean;
  liked?: boolean;
  listIds?: number[];
}
