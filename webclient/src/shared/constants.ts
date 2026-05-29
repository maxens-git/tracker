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
