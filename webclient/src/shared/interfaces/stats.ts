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
  showsSeenByYear: StatsYearBucket[];
  showsSeenByMonth: StatsMonthBucket[];
}

export interface CombinedYearBucket {
  year: number;
  movies: number;
  shows: number;
  total: number;
}

export interface CombinedMonthBucket {
  label: string;
  movies: number;
  shows: number;
  total: number;
}
