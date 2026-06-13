import { HttpErrorResponse } from '@angular/common/http';

/**
 * Message lisible à partir d'une erreur HTTP : utilise le corps renvoyé par le
 * backend (ex. « Une liste portant ce nom existe déjà. ») quand il est présent.
 */
export function errorMessage(err: unknown, fallback = 'Une erreur est survenue. Réessayez.'): string {
  if (err instanceof HttpErrorResponse) {
    const body = err.error;
    if (typeof body === 'string' && body.trim()) return body;
    if (body && typeof body === 'object' && typeof body.message === 'string') return body.message;
    if (err.status === 0) return 'Connexion au serveur impossible.';
  }
  return fallback;
}
