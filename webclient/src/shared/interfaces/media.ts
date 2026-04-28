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
  vote_average: number;
  vote_count: number;
  popularity: number;
  seen: boolean;
}

export interface TrendingHome {
  featuredItem?: MediaItem;
  trendingWeek: MediaItem[];
  popularMovies: MediaItem[];
  popularShows: MediaItem[];
  topRated: MediaItem[];
}

export interface SearchResponse {
  page: number;
  results: MediaItem[];
  total_pages: number;
  total_results: number;
}
