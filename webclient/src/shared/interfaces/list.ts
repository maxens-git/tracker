export interface MediaListSummary {
  id: number;
  name: string;
  description?: string;
  icon?: string;
  isSystem: boolean;
  moviesCount: number;
  showsCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

export interface MediaListSearchItem {
  id: number;
  tmdbId: number;
  title: string;
  posterPath?: string;
  releaseDate?: string;
  voteAverage?: number;
  popularity?: number;
  updatedAt?: string;
  addedAt?: string;
  mediaType: string;
  seen: boolean;
}
