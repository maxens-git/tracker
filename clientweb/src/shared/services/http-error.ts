import { HttpErrorResponse } from '@angular/common/http';

/**
 * Message lisible à partir d'une erreur HTTP : utilise le corps renvoyé par le
 * backend (ex. « Une liste portant ce nom existe déjà. ») quand il est présent.
 */
export function errorMessage(err: unknown, fallback = 'Une erreur est survenue. Réessayez.'): string {
  if (err instanceof HttpErrorResponse) {
    const body = err.error;
    if (typeof body === 'string' && body.trim()) return body;
    if (body && typeof body === 'object') {
      // ASP.NET renvoie un ValidationProblemDetails pour les DTO invalides.
      if (body.errors && typeof body.errors === 'object') {
        const messages = Object.values(body.errors).flatMap(value =>
          Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && !!entry.trim()) : []);
        if (messages.length) return [...new Set(messages)].join(' ');
      }
      for (const field of ['detail', 'message', 'title']) {
        if (typeof body[field] === 'string' && body[field].trim()) return body[field];
      }
    }
    if (err.status === 0) return 'Connexion au serveur impossible.';
  }
  return fallback;
}
