export interface StatsYearBucket {
  year: number;
  count: number;
}

export interface StatsMonthBucket {
  year: number;
  month: number;
  count: number;
}

export interface StatsDto {
  moviesSeenCount: number;
  showsSeenCount: number;
  episodesSeenCount: number;
  totalRuntimeMinutes: number;
  totalRuntimeHours: number;
  moviesSeenByYear: StatsYearBucket[];
  moviesSeenByMonth: StatsMonthBucket[];
  showsSeenByYear: StatsYearBucket[];
  showsSeenByMonth: StatsMonthBucket[];
}
