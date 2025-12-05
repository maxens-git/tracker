export interface TMDbSearchResult {
  id: number;
  media_type: string;
  title?: string;
  name?: string;
  original_title?: string;
  original_name?: string;
  overview?: string;
  poster_path?: string;
  backdrop_path?: string;
  release_date?: string;
  first_air_date?: string;
  vote_average: number;
  vote_count: number;
  popularity: number;
}

export interface TrendingHomeData {
  featuredItem?: TMDbSearchResult;
  trendingWeek: TMDbSearchResult[];
  popularMovies: TMDbSearchResult[];
  popularShows: TMDbSearchResult[];
  topRated: TMDbSearchResult[];
}
