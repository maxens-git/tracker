import { TMDbSearchResult } from './tmdb-trending.interface';

export interface SearchResponse {
  page: number;
  results: TMDbSearchResult[];
  total_pages: number;
  total_results: number;
}
