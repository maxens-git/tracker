import { Injectable, inject, signal } from '@angular/core';
import { Observable, of } from 'rxjs';
import { map, shareReplay, tap } from 'rxjs/operators';
import { Api, Settings } from './api';
import { setTmdbConfig } from './tmdb.service';

/**
 * État partagé des réglages qui pilotent l'UI (visibilité de sections/pages).
 * Les réglages sont chargés une seule fois puis mis en cache : la barre de
 * navigation et le garde de route « /torrents » lisent le même signal.
 */
@Injectable({ providedIn: 'root' })
export class SettingsState {
  private api = inject(Api);

  /** Recherche & débridage activés (torrents accessibles). */
  readonly torrentsEnabled = signal(true);

  private cached$?: Observable<Settings>;
  private latest?: Settings;
  private revision = 0;

  /** Charge les réglages (mis en cache, partagé entre appelants). */
  load(): Observable<Settings> {
    const revision = this.revision;
    return (this.cached$ ??= this.api.settings().pipe(
      // Un GET démarré avant une sauvegarde peut terminer après celle-ci.
      // Ses abonnés doivent eux aussi recevoir les réglages les plus récents.
      map(settings => revision === this.revision ? settings : this.latest ?? settings),
      tap(settings => {
        this.latest = settings;
        this.applyToRuntime(settings);
      }),
      shareReplay({ bufferSize: 1, refCount: false }),
    ));
  }

  /** Applique des réglages fraîchement enregistrés et rafraîchit le cache. */
  apply(settings: Settings) {
    this.revision++;
    this.latest = settings;
    this.applyToRuntime(settings);
    this.cached$ = of(settings);
  }

  private applyToRuntime(settings: Settings) {
    this.torrentsEnabled.set(settings.torrentsEnabled);
    setTmdbConfig({
      apiKey: settings.tmdbApiKey,
      baseUrl: settings.tmdbBaseUrl,
      language: settings.tmdbLanguage,
    });
  }
}
