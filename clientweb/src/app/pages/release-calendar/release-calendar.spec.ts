import { TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';
import { Api, TrackedMedia } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { TmdbEpisode, TmdbMovie, TmdbSeason, TmdbShow } from '../../../shared/interfaces/media';
import { ReleaseCalendar } from './release-calendar';

const tracked: TrackedMedia = { id: 1, tmdbId: 42, mediaType: 'tv', title: 'Série', posterPath: null, addedAt: '2026-01-01' };
const episode = { id: 10, season_number: 1, episode_number: 10, name: 'Dix', air_date: '2099-01-02' } as TmdbEpisode;
const show = {
  id: 42, name: 'Série', in_production: true,
  seasons: [{ id: 1, season_number: 1, air_date: '2000-01-01', name: 'Saison 1', episode_count: 20 }],
  next_episode_to_air: episode,
} as TmdbShow;

function setup() {
  const api = {
    trackedMedia: vi.fn(() => of([tracked])),
    removeTrackedMedia: vi.fn(() => of(undefined)),
  };
  const tmdb = {
    show: vi.fn(() => of(show)),
    movie: vi.fn(() => of({ id: 42, title: 'Film', release_date: '2099-01-02' } as TmdbMovie)),
    season: vi.fn(() => of({ episodes: [episode, { ...episode, id: 11, episode_number: 11, name: 'Onze', air_date: '2099-01-09' }] } as TmdbSeason)),
  };
  TestBed.configureTestingModule({ providers: [
    { provide: Api, useValue: api }, { provide: TmdbService, useValue: tmdb },
  ] });
  return { calendar: TestBed.runInInjectionContext(() => new ReleaseCalendar()), api, tmdb };
}

describe('Release calendar consistency', () => {
  it('includes later episodes of an ongoing season older than ninety days', () => {
    const { calendar, tmdb } = setup();
    calendar.load();
    expect(tmdb.season).toHaveBeenCalledWith(42, 1);
    expect(calendar.items()).toHaveLength(2);
    expect(calendar.items().map(item => item.subtitle)).toEqual(['S01E10 - Dix', 'S01E11 - Onze']);
    expect(calendar.pendingItems()).toEqual([]);
  });

  it('shows an error when TMDB fails instead of asserting there are no upcoming releases', () => {
    const { calendar, tmdb } = setup();
    tmdb.show.mockReturnValue(throwError(() => new Error('TMDB unavailable')));
    calendar.load();
    expect(calendar.error()).toBe(true);
    expect(calendar.loading()).toBe(false);
  });

  it('does not turn a failed season request into a made-up next-season placeholder', () => {
    const { calendar, tmdb } = setup();
    tmdb.season.mockReturnValue(throwError(() => new Error('Season unavailable')));
    calendar.load();
    expect(calendar.error()).toBe(true);
    expect(calendar.pendingItems()).toEqual([]);
  });

  it('cancels a previous load so a slow response cannot restore removed releases', () => {
    const { calendar, api } = setup();
    const oldTracked = new Subject<TrackedMedia[]>();
    api.trackedMedia.mockReturnValueOnce(oldTracked).mockReturnValueOnce(of([]));
    calendar.load();
    calendar.load();
    expect(oldTracked.observed).toBe(false);
    oldTracked.next([tracked]);
    expect(calendar.tracked()).toEqual([]);
    expect(calendar.items()).toEqual([]);
    expect(calendar.selectedKey()).toBe('');
  });

  it('keeps displayed releases and reports a failed unfollow request', () => {
    const { calendar, api } = setup();
    calendar.load();
    api.removeTrackedMedia.mockReturnValue(throwError(() => new Error('API unavailable')));
    calendar.remove(calendar.items()[0], new Event('click'));
    expect(calendar.removeError()).toBe(true);
    expect(calendar.items()).toHaveLength(2);
    expect(calendar.removing().size).toBe(0);
  });
});
