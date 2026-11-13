import { inject } from '@angular/core';
import { firstValueFrom, of } from 'rxjs';
import { catchError, timeout } from 'rxjs/operators';
import { SettingsState } from './settings-state';

/** Les premières requêtes TMDB doivent utiliser les réglages sauvegardés. */
export function initializeSettings(): Promise<unknown> {
  return firstValueFrom(inject(SettingsState).load().pipe(
    timeout(5000),
    // Une API indisponible ne doit pas empêcher l'application d'afficher ses erreurs.
    catchError(() => of(undefined)),
  ));
}
