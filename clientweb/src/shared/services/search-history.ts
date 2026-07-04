import { Injectable, PLATFORM_ID, inject, signal } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';

const STORAGE_KEY = 'tracker.searchHistory';
const MAX_ENTRIES = 12;

/**
 * Historique de recherche local (par navigateur), persisté dans localStorage.
 * Volontairement côté client : la recherche interroge TMDB depuis le frontend,
 * pas besoin d'aller-retour serveur.
 */
@Injectable({ providedIn: 'root' })
export class SearchHistoryService {
  private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

  /** Requêtes récentes, de la plus récente à la plus ancienne. */
  readonly recent = signal<string[]>([]);

  constructor() {
    if (this.isBrowser) this.recent.set(this.read());
  }

  /**
   * Enregistre une requête. Ignore les chaînes trop courtes et « replie » la frappe
   * incrémentale : taper « Dune » ne laisse que « Dune » (pas « D », « Du », « Dun »).
   */
  record(raw: string) {
    const query = raw.trim();
    if (query.length < 2) return;

    const lowered = query.toLowerCase();
    const next = this.recent().filter(entry => {
      const a = entry.toLowerCase();
      return !(a === lowered || a.startsWith(lowered) || lowered.startsWith(a));
    });
    next.unshift(query);
    this.recent.set(next.slice(0, MAX_ENTRIES));
    this.persist();
  }

  remove(entry: string) {
    this.recent.set(this.recent().filter(e => e !== entry));
    this.persist();
  }

  clear() {
    this.recent.set([]);
    this.persist();
  }

  private read(): string[] {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      const parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed.filter((x): x is string => typeof x === 'string') : [];
    } catch {
      return [];
    }
  }

  private persist() {
    if (!this.isBrowser) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.recent()));
    } catch {
      // L'historique reste disponible pour la session courante.
    }
  }
}
