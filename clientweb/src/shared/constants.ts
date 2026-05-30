/**
 * Noms des listes système, alignés sur le backend (Tracker.Models.SystemLists).
 * À garder synchronisé si les noms changent côté serveur.
 */
export const SYSTEM_LIST = {
  watchlist: 'Watchlist',
  seen: 'Seen',
  liked: "J'aime",
} as const;

/** Slug d'URL (/list/:id) → nom de la liste système correspondante. */
export const SYSTEM_LIST_BY_SLUG: Record<'watchlist' | 'seen' | 'liked', string> = {
  watchlist: SYSTEM_LIST.watchlist,
  seen: SYSTEM_LIST.seen,
  liked: SYSTEM_LIST.liked,
};

/**
 * Nom de la liste système → slug d'URL.
 * Les listes système "Seen"/"J'aime" sont virtuelles côté backend (aucune ligne
 * dans MediaListItems) : il faut les router par slug, pas par id numérique,
 * sinon GET /MediaLists/{id}/items renvoie une liste vide.
 */
export const SLUG_BY_SYSTEM_LIST: Record<string, 'watchlist' | 'seen' | 'liked'> = {
  [SYSTEM_LIST.watchlist]: 'watchlist',
  [SYSTEM_LIST.seen]: 'seen',
  [SYSTEM_LIST.liked]: 'liked',
};
