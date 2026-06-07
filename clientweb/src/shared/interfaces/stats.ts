export interface StatsYearBucket {
  year: number;
  count: number;
}

export interface StatsMonthBucket {
  year: number;
  month: number;
  count: number;
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
