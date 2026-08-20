import { MediaItem } from '../interfaces/media';

/**
 * Classement des résultats de recherche par pertinence réelle.
 *
 * TMDB trie /search/multi par une popularité pondérée : chercher « dune »
 * remontait des documentaires obscurs avant le film, et « alien » plaçait des
 * suites mineures devant l'original. On rejoue donc le tri côté client à partir
 * de la correspondance du titre, la popularité ne servant qu'à départager deux
 * titres qui matchent aussi bien.
 *
 * Les paliers de correspondance sont espacés d'au moins 10 points, alors que
 * les bonus cumulés (popularité, votes) ne peuvent bouger un résultat que de 7
 * au maximum : un titre populaire ne peut jamais doubler un titre qui
 * correspond mieux à la requête. Seule la pénalité « fiche fantôme » franchit
 * délibérément un palier.
 *
 * On ne descend jamais un résultat en dessous de ce que sa position TMDB
 * justifie (cf. `implicitScore`) : TMDB matche aussi sur les titres alternatifs
 * qu'il ne renvoie pas. Chercher « spirited away » avec l'app en français
 * remonte « Le Voyage de Chihiro », dont ni le titre localisé ni le titre
 * d'origine (japonais) ne contiennent la requête — le classement ne peut donc
 * que promouvoir sur correspondance visible, jamais enterrer.
 *
 * Cette logique est dupliquée à l'identique dans clientios
 * (`Tracker/Utilities/SearchRanking.swift`) : toute correction ici doit y être
 * reportée, sans quoi les deux clients ne classeraient plus pareil.
 */

/**
 * Minuscules, sans accents, sans ponctuation, espaces normalisés.
 * « Le Voyage de Chihiro : L'Édition » → « le voyage de chihiro l edition ».
 */
export function normalize(text: string): string {
  return text
    .normalize('NFD')
    // Retire les diacritiques isolés par la décomposition NFD.
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

/** Score de correspondance d'un titre avec la requête, de 0 (rien) à 1 (exact). */
export function titleScore(title: string, query: string): number {
  const candidate = normalize(title);
  const needle = normalize(query);
  if (!candidate || !needle) return 0;

  if (candidate === needle) return 1.0;
  // « dune » doit remonter « Dune » puis « Dune : Deuxième partie » avant
  // « Les Enfants de Dune ».
  if (candidate.startsWith(needle + ' ')) return 0.85;
  // Préfixe en cours de frappe : « dun » → « Dune ».
  if (candidate.startsWith(needle)) return 0.75;
  // La requête apparaît comme mot entier ailleurs dans le titre.
  if (candidate.includes(' ' + needle + ' ') || candidate.endsWith(' ' + needle)) return 0.65;
  if (candidate.includes(needle)) return 0.5;

  const words = candidate.split(' ').filter(Boolean);
  const needleWords = needle.split(' ').filter(Boolean);
  if (needleWords.length === 0) return 0;
  const wordSet = new Set(words);

  // Tous les mots de la requête sont présents, mais dispersés.
  const exactWordMatches = needleWords.filter(w => wordSet.has(w)).length;
  if (exactWordMatches === needleWords.length) return 0.4;
  if (exactWordMatches > 0) return (0.25 * exactWordMatches) / needleWords.length;

  // Dernier recours : un mot de la requête amorce un mot du titre
  // (« chihi » → « chihiro »).
  const prefixMatches = needleWords.filter(nw => words.some(w => w.startsWith(nw))).length;
  if (prefixMatches === 0) return 0;
  return (0.15 * prefixMatches) / needleWords.length;
}

/**
 * Correspondance implicite déduite du rang TMDB : ce que la position d'un
 * résultat garantit, même quand aucun titre visible ne matche (TMDB a reconnu
 * un titre alternatif qu'il ne nous renvoie pas). Décroît de 0,8 en tête à 0
 * au-delà du 24ᵉ résultat.
 */
export function implicitScore(tmdbIndex: number): number {
  return Math.max(0, 0.8 * (1 - tmdbIndex / 24));
}

/**
 * Score d'un résultat : palier de correspondance (×100) puis départage.
 * `tmdbIndex` est la position d'origine dans la réponse TMDB.
 */
export function score(
  titles: string[],
  query: string,
  tmdbIndex: number,
  popularity: number,
  voteCount: number,
  hasPoster: boolean,
): number {
  // Le titre localisé et le titre d'origine sont testés tous les deux : on
  // garde le meilleur des deux, sans jamais passer sous le plancher que la
  // position TMDB justifie.
  const own = titles.length ? Math.max(...titles.map(t => titleScore(t, query))) : 0;
  const best = Math.max(own, implicitScore(tmdbIndex));

  // Échelles logarithmiques : au-delà de quelques milliers de votes, la
  // différence ne dit plus rien de la pertinence.
  const popularityBoost = Math.min(Math.log10(Math.max(popularity, 0) + 1) / 3, 1);
  const votesBoost = Math.min(Math.log10(Math.max(voteCount, 0) + 1) / 5, 1);

  const base = best * 100 + popularityBoost * 4 + votesBoost * 3 - (hasPoster ? 0 : 2);

  // Ni affiche ni vote : fiche fantôme (doublon vide, brouillon jamais rempli).
  // Chercher « le parrain » en remontait une, titre exact donc au meilleur
  // palier possible, devant les vrais films. On la plafonne sous le palier des
  // correspondances faibles plutôt que de lui retrancher un malus : rien
  // d'inaffichable ne doit passer devant un vrai résultat.
  if (!hasPoster && voteCount === 0) return Math.min(base, GHOST_CEILING);
  return base;
}

/** Plafond appliqué aux fiches sans affiche ni vote (sous le palier 0,4). */
const GHOST_CEILING = 30;

/** Titres à confronter à la requête : localisé + langue d'origine. */
export function searchableTitles(item: MediaItem): string[] {
  return [item.title, item.name, item.original_title, item.original_name].filter(
    (t): t is string => !!t,
  );
}

export function scoreFor(item: MediaItem, query: string, tmdbIndex: number): number {
  return score(
    searchableTitles(item),
    query,
    tmdbIndex,
    item.popularity ?? 0,
    item.vote_count ?? 0,
    !!item.poster_path,
  );
}

/**
 * Trie les résultats par pertinence décroissante pour la requête donnée.
 * L'ordre reçu doit être celui de TMDB : il sert de plancher et de départage.
 */
export function rank(items: MediaItem[], query: string): MediaItem[] {
  return items
    .map((item, index) => ({ item, index, value: scoreFor(item, query, index) }))
    // Tri stable : à score égal on conserve l'ordre TMDB d'origine.
    .sort((a, b) => (b.value - a.value) || (a.index - b.index))
    .map(entry => entry.item);
}

/**
 * Retire les doublons (même fiche renvoyée par deux pages), premier gardé.
 * La clé combine le type : un film et une série peuvent partager le même id.
 */
export function deduplicate(items: MediaItem[]): MediaItem[] {
  const seen = new Set<string>();
  return items.filter(item => {
    const key = `${item.media_type}-${item.id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
