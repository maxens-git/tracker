import { inject } from '@angular/core';
import { CanMatchFn, Router } from '@angular/router';
import { of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { SettingsState } from '../services/settings-state';

/**
 * Bloque l'accès à « /torrents » quand la recherche & le débridage sont
 * désactivés dans les réglages, et renvoie vers l'accueil. En cas d'erreur
 * réseau, on n'empêche pas l'accès.
 */
export const torrentsEnabledGuard: CanMatchFn = () => {
  const state = inject(SettingsState);
  const router = inject(Router);
  return state.load().pipe(
    map(settings => (settings.torrentsEnabled ? true : router.createUrlTree(['/home']))),
    catchError(() => of(true)),
  );
};
