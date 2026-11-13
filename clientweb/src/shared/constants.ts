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
 * Les slugs donnent des liens stables aux listes système, dont "Seen"/"J'aime"
 * sont virtuelles côté backend (leurs éléments viennent des états utilisateur).
 */
export const SLUG_BY_SYSTEM_LIST: Record<string, 'watchlist' | 'seen' | 'liked'> = {
  [SYSTEM_LIST.watchlist]: 'watchlist',
  [SYSTEM_LIST.seen]: 'seen',
  [SYSTEM_LIST.liked]: 'liked',
};
