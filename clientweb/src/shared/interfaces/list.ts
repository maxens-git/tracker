export interface MediaListSummary {
  id: number;
  name: string;
  description?: string;
  isSystem: boolean;
  itemsCount: number;
  createdAt: string;
  updatedAt?: string;
}

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

export interface MediaListItem {
  tmdbId: number;
  mediaType: string;
  posterPath?: string | null;
  title?: string | null;
  seen: boolean;
  watchCount: number;
  liked: boolean;
  addedAt: string;
}
