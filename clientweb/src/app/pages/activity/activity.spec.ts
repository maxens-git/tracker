import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Activity } from '../../../shared/interfaces/activity';
import { ActivityPage } from './activity';

const movieActivity: Activity = {
  id: 1, type: 'seen', tmdbId: 42, mediaType: 'movie', createdAt: '2026-01-01T12:00:00Z',
};

function setup(items: Activity[]) {
  const api = { activity: vi.fn(() => of({ items, totalPages: 1, totalCount: items.length, page: 1, pageSize: 30 })) };
  const tmdb = { fetchMany: vi.fn(() => of([
    { id: 42, media_type: 'movie', title: 'Film', poster_path: '/film.jpg' },
    { id: 42, media_type: 'tv', name: 'Série', poster_path: '/serie.jpg' },
  ])) };
  TestBed.configureTestingModule({ providers: [
    { provide: Api, useValue: api }, { provide: TmdbService, useValue: tmdb },
  ] });
  return { page: TestBed.runInInjectionContext(() => new ActivityPage()), api };
}

describe('Activity API mapping', () => {
  it('keeps movie and show metadata separate when TMDB ids collide', () => {
    const { page } = setup([movieActivity, { ...movieActivity, id: 2, mediaType: 'tv' }]);
    page.ngOnInit();
    expect(page.rows().map(row => row.title)).toEqual(['Film', 'Série']);
    expect(page.rows()[0].posterUrl).toContain('/film.jpg');
    expect(page.rows()[1].posterUrl).toContain('/serie.jpg');
  });

  it('resets the error state when a failed page is retried', () => {
    const { page, api } = setup([movieActivity]);
    api.activity.mockReturnValueOnce(throwError(() => new Error('offline')));
    page.ngOnInit();
    expect(page.error()).toBe(true);
    page.loadMore();
    expect(page.error()).toBe(false);
    expect(page.rows()).toHaveLength(1);
    page.loadMore();
    expect(api.activity).toHaveBeenCalledTimes(2);
  });

  it('renders the API unknown activity fallback without crashing', () => {
    const { page } = setup([{ ...movieActivity, type: 'unknown' as Activity['type'] }]);
    page.ngOnInit();
    expect(page.rows()[0].label).toBe('Activité');
  });
});
