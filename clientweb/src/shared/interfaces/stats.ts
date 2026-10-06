export interface StatsYearBucket {
  year: number;
  count: number;
}

export interface StatsMonthBucket {
  year: number;
  month: number;
  count: number;
}

export interface StatsGenreBucket {
  name: string;
  count: number;
  percentage: number;
}

export interface StatsListGenres {
  listId: number;
  name: string;
  isSystem: boolean;
  genres: StatsGenreBucket[];
}

export interface MostRewatchedItem {
  tmdbId: number;
  mediaType: string;
  title?: string | null;
  posterPath?: string | null;
  seasonNumber?: number | null;
  episodeNumber?: number | null;
  watchCount: number;
}

export interface Stats {
  moviesSeenCount: number;
  showsSeenCount: number;
  episodesSeenCount: number;
  moviesWatchCount: number;
  episodesWatchCount: number;
  totalRuntimeMinutes: number;
  moviesSeenByYear: StatsYearBucket[];
  moviesSeenByMonth: StatsMonthBucket[];
  episodesSeenByYear: StatsYearBucket[];
  episodesSeenByMonth: StatsMonthBucket[];
  favoriteGenres: StatsGenreBucket[];
  mostRewatched: MostRewatchedItem[];
}

export interface CombinedYearBucket {
  year: number;
  movies: number;
  episodes: number;
  total: number;
}

export interface CombinedMonthBucket {
  label: string;
  movies: number;
  episodes: number;
  total: number;
}
