export interface MediaListSummary {
  id: number;
  name: string;
  description?: string | null;
  icon?: string | null;
  isSystem: boolean;
  moviesCount: number;
  showsCount: number;
  createdAt?: string;
  updatedAt?: string;
}
