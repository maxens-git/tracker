import { HttpErrorResponse } from '@angular/common/http';
import { errorMessage } from './http-error';

describe('API error messages', () => {
  it('shows field validation failures from ASP.NET ProblemDetails', () => {
    const error = new HttpErrorResponse({ status: 400, error: {
      title: 'One or more validation errors occurred.',
      errors: { TmdbId: ['ID invalide.'], Title: ['Titre trop long.', 'Titre trop long.'] },
    } });
    expect(errorMessage(error)).toBe('ID invalide. Titre trop long.');
  });

  it('shows the API conflict explanation', () => {
    expect(errorMessage(new HttpErrorResponse({ status: 409, error: 'Actualisez son état puis réessayez.' })))
      .toBe('Actualisez son état puis réessayez.');
  });

  it('supports ProblemDetails and legacy message responses', () => {
    expect(errorMessage(new HttpErrorResponse({ status: 400, error: { detail: 'Détail', title: 'Titre' } }))).toBe('Détail');
    expect(errorMessage(new HttpErrorResponse({ status: 400, error: { message: 'Message' } }))).toBe('Message');
    expect(errorMessage(new HttpErrorResponse({ status: 400, error: { errors: {}, title: 'Titre' } }))).toBe('Titre');
  });

  it('ignores malformed errors and distinguishes network failures', () => {
    expect(errorMessage(new HttpErrorResponse({ status: 400, error: { errors: { x: [null, 1, ''] } } }), 'Échec')).toBe('Échec');
    expect(errorMessage(new HttpErrorResponse({ status: 0 }))).toBe('Connexion au serveur impossible.');
    expect(errorMessage(new Error('internal'), 'Échec')).toBe('Échec');
  });
});
