/** Détail d'une personne (acteur, réalisateur…) renvoyé par TMDB. */
export interface TmdbPerson {
  id: number;
  name: string;
  biography: string;
  birthday: string | null;
  deathday: string | null;
  place_of_birth: string | null;
  profile_path: string | null;
  known_for_department: string;
}

/** Un crédit (film ou série) au sein de la filmographie d'une personne. */
export interface TmdbPersonCredit {
  id: number;
  media_type: string;
  title?: string | null;
  name?: string | null;
  poster_path: string | null;
  backdrop_path?: string | null;
  release_date?: string | null;
  first_air_date?: string | null;
  vote_average: number;
  vote_count?: number;
  popularity?: number;
  character?: string;
  job?: string;
  department?: string;
}

/** Crédits combinés (films + séries) d'une personne. */
export interface TmdbCombinedCredits {
  id: number;
  cast: TmdbPersonCredit[];
  crew: TmdbPersonCredit[];
}
