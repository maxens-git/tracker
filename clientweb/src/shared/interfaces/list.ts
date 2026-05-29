export interface MediaListSummary {
  id: number;
  name: string;
  description?: string;
  icon?: string;
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
  seen: boolean;
  liked: boolean;
  addedAt: string;
}
