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
  icon?: string;
  isSystem: boolean;
  genres: StatsGenreBucket[];
}

export interface Stats {
  moviesSeenCount: number;
  showsSeenCount: number;
  episodesSeenCount: number;
  totalRuntimeMinutes: number;
  moviesSeenByYear: StatsYearBucket[];
  moviesSeenByMonth: StatsMonthBucket[];
  episodesSeenByYear: StatsYearBucket[];
  episodesSeenByMonth: StatsMonthBucket[];
  favoriteGenres: StatsGenreBucket[];
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
