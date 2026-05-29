/**
 * Aide à l'affichage de l'équipe technique (crew) renvoyée par TMDB :
 * métiers prioritaires à conserver et traduction française des libellés.
 */

/** Métiers clés affichés dans la section « Équipe technique », par ordre d'importance. */
export const PRIORITY_CREW_JOBS = [
  'Director',
  'Creator',
  'Writer',
  'Screenplay',
  'Story',
  'Producer',
  'Executive Producer',
  'Original Music Composer',
  'Composer',
  'Director of Photography',
  'Editor',
];

/** Traduction française des métiers TMDB (qui sont toujours renvoyés en anglais). */
const JOB_FR: Record<string, string> = {
  Director: 'Réalisateur',
  Creator: 'Créateur',
  Writer: 'Scénariste',
  Screenplay: 'Scénario',
  Story: 'Histoire',
  Novel: 'Roman',
  Producer: 'Producteur',
  'Executive Producer': 'Producteur exécutif',
  'Original Music Composer': 'Compositeur',
  Composer: 'Compositeur',
  'Director of Photography': 'Directeur de la photographie',
  Editor: 'Monteur',
};

/** Renvoie le métier traduit en français, ou la valeur d'origine si inconnue. */
export function localizedJob(job: string | null | undefined): string {
  if (!job) return '';
  return JOB_FR[job] ?? job;
}
