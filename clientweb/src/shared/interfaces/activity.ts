export type ActivityType =
  | 'seen'
  | 'unseen'
  | 'liked'
  | 'unliked'
  | 'addedToList'
  | 'removedFromList'
  | 'seasonSeen'
  | 'seasonUnseen'
  | 'episodeSeen'
  | 'episodeUnseen';

/** Entrée du journal d'activité renvoyée par le backend. */
export interface Activity {
  id: number;
  type: ActivityType;
  tmdbId: number;
  mediaType: string;
  posterPath?: string | null;
  listId?: number | null;
  listName?: string | null;
  seasonNumber?: number | null;
  episodeNumber?: number | null;
  createdAt: string;
}
