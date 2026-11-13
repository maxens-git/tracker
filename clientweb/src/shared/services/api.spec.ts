import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { MediaItem, UserState } from '../interfaces/media';
import { Api, mediaStateKey, withUserStates } from './api';

describe('API user-state contract', () => {
  let api: Api;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(Api);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('keeps a movie and show with the same TMDB ID separate', async () => {
    const items = [item(42, 'movie'), item(42, 'tv')];
    const result = firstValueFrom(api.statesByTmdbId(items));
    http.expectOne(request => request.params.get('type') === 'movie')
      .flush([state(42, true, [1])]);
    http.expectOne(request => request.params.get('type') === 'tv')
      .flush([state(42, false, [2])]);

    const hydrated = withUserStates(items, await result);
    expect(hydrated[0]).toMatchObject({ seen: true, watchCount: 1, listIds: [1] });
    expect(hydrated[1]).toMatchObject({ seen: false, watchCount: 0, listIds: [2] });
  });

  it('retains available state if one media-type request fails', async () => {
    const movie = { ...item(42, 'movie'), seen: true, watchCount: 3, liked: true, listIds: [9] };
    const show = item(42, 'tv');
    const result = firstValueFrom(api.statesByTmdbId([movie, show]));
    http.expectOne(request => request.params.get('type') === 'movie')
      .flush('unavailable', { status: 503, statusText: 'Unavailable' });
    http.expectOne(request => request.params.get('type') === 'tv').flush([state(42, false, [2])]);

    const hydrated = withUserStates([movie, show], await result);
    expect(hydrated[0]).toMatchObject({ seen: true, watchCount: 3, liked: true, listIds: [9] });
    expect(hydrated[1]).toMatchObject({ seen: false, listIds: [2] });
  });

  it('does not send an empty or invalid ID list to the API', async () => {
    expect(await firstValueFrom(api.states([], 'movie'))).toEqual([]);
    expect(await firstValueFrom(api.states([0, -1, NaN, 1.5, 2147483648], 'tv'))).toEqual([]);
    http.expectNone('/api/Media/states');
  });

  it('deduplicates and batches large filmographies without changing result order', async () => {
    const ids = Array.from({ length: 205 }, (_, index) => index + 1);
    const result = firstValueFrom(api.states([...ids, 1, 2], 'movie'));
    const batches = http.match(request => request.url === '/api/Media/states');
    expect(batches).toHaveLength(3);
    for (const request of batches.reverse()) {
      const batch = request.request.params.get('tmdbIds')!.split(',').map(Number);
      expect(batch.length).toBeLessThanOrEqual(100);
      request.flush(batch.map(id => state(id, false, [])));
    }
    expect((await result).map(s => s.tmdbId)).toEqual(ids);
  });

  it('sends likes with the boolean JSON body and optional title/poster accepted by the API', async () => {
    const result = firstValueFrom(api.markLiked(42, 'tv', true, 'Titre', '/poster.jpg'));
    const request = http.expectOne(request => request.url === '/api/Media/42/liked');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toBe(true);
    expect(request.request.headers.get('Content-Type')).toBe('application/json');
    expect(request.request.params.get('posterPath')).toBe('/poster.jpg');
    expect(request.request.params.get('type')).toBe('tv');
    request.flush({ tmdbId: 42, liked: true });
    await result;
  });

  it('applies explicit false state instead of retaining a previously true flag', () => {
    const movie = { ...item(42, 'movie'), seen: true, watchCount: 2, liked: true };
    const states = new Map([[mediaStateKey(movie), state(42, false, [])]]);
    expect(withUserStates([movie], states)[0]).toMatchObject({ seen: false, watchCount: 0, liked: false });
  });

  it('normalizes UTC database timestamps and explicit offsets consistently for history', async () => {
    const result = firstValueFrom(api.getWatches(42, 'movie'));
    http.expectOne(request => request.url === '/api/Media/42/watches').flush([
      { id: 1, watchedAt: '2026-11-13T23:30:00' },
      { id: 2, watchedAt: '2026-11-14T00:30:00+01:00' },
      { id: 3, watchedAt: '2026-11-13T23:30:00.0000000Z' },
    ]);
    expect((await result).map(event => event.watchedAt)).toEqual(Array(3).fill('2026-11-13T23:30:00.000Z'));
  });

  it('sends an empty genre array when a watch dialog has no genre metadata', async () => {
    const result = firstValueFrom(api.addWatch(42, 'movie', { watchedAt: '2026-11-13T12:00:00Z', genres: null }));
    const request = http.expectOne(request => request.url === '/api/Media/42/watches');
    expect(request.request.body.genres).toEqual([]);
    request.flush({ id: 1, watchedAt: '2026-11-13T12:00:00Z' });
    expect((await result).watchedAt).toBe('2026-11-13T12:00:00.000Z');
  });
});

function item(id: number, media_type: string): MediaItem {
  return { id, media_type, vote_average: 0, vote_count: 0, popularity: 0, seen: false };
}

function state(tmdbId: number, seen: boolean, listIds: number[]): UserState {
  return { tmdbId, seen, watchCount: seen ? 1 : 0, liked: false, listIds };
}
