import { TestBed } from '@angular/core/testing';
import { HttpErrorResponse } from '@angular/common/http';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { Location } from '@angular/common';
import { MessageService } from 'primeng/api';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { TmdbShow, TmdbSeason } from '../../../shared/interfaces/media';
import { MediaDetail } from './media-detail';

const show: TmdbShow = {
  id: 42, name: 'Série', original_name: 'Série', overview: '', poster_path: null,
  backdrop_path: null, first_air_date: '', last_air_date: '', vote_average: 0,
  vote_count: 0, popularity: 0, status: 'Returning Series', in_production: true,
  tagline: '', number_of_seasons: 1, number_of_episodes: 2, genres: [],
  seasons: [{ id: 1, season_number: 1, episode_count: 2, name: 'Saison 1',
    air_date: null, poster_path: null, overview: '' }],
};
const season = { id: 1, season_number: 1, episodes: [
  { id: 1, season_number: 1, episode_number: 1, name: 'Premier' },
  { id: 2, season_number: 1, episode_number: 2, name: 'Second' },
] } as TmdbSeason;

describe('MediaDetail API consistency', () => {
  let routeParams: BehaviorSubject<ReturnType<typeof convertToParamMap>>;
  let api: ReturnType<typeof apiMock>;
  let component: MediaDetail;

  function apiMock() {
    return {
      states: vi.fn(() => of([{ tmdbId: 42, seen: true, watchCount: 3, liked: false, listIds: [] }])),
      lists: vi.fn(() => of([])),
      trackedMediaState: vi.fn(() => of({ tracked: false })),
      showEpisodes: vi.fn(() => of([{ seasonNumber: 1, episodeNumber: 1, seen: true, watchCount: 2 }])),
      markSeen: vi.fn(() => of({})),
      markSeasonSeen: vi.fn(() => of({})),
      markEpisodeSeen: vi.fn(() => of({})),
      addWatch: vi.fn(() => of({ id: 9, watchedAt: '2026-01-01T00:00:00Z' })),
    };
  }

  beforeEach(() => {
    routeParams = new BehaviorSubject(convertToParamMap({ tmdbId: '42' }));
    api = apiMock();
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api },
      { provide: ActivatedRoute, useValue: { paramMap: routeParams, snapshot: { data: { type: 'tv' } } } },
      { provide: Location, useValue: { back: vi.fn() } },
      { provide: MessageService, useValue: { add: vi.fn() } },
      { provide: TmdbService, useValue: {
        show: vi.fn((id: number) => of({ ...show, id })), season: vi.fn(() => of(season)),
        showCredits: vi.fn(() => of(null)), showVideos: vi.fn(() => of(null)),
        similarShows: vi.fn(() => of({ results: [] })),
      } },
    ] });
    vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
    component = TestBed.runInInjectionContext(() => new MediaDetail());
  });

  it('does not erase explicit show watches when loading partial episode progress', () => {
    component.ngOnInit();
    expect(api.markSeen).not.toHaveBeenCalled();
    expect(component.currentSeen).toBe(true);
    expect(component.currentWatchCount).toBe(3);
    expect(component.currentSeason()?.episodes[0].watchCount).toBe(2);
  });

  it('fails visibly instead of treating failed episode reads as an unseen show', () => {
    api.showEpisodes.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 503 })));
    component.ngOnInit();
    expect(component.error()).toBeTruthy();
    expect(api.markSeen).not.toHaveBeenCalled();
  });

  it('restores each episode and its count when marking a mixed season fails', () => {
    component.ngOnInit();
    api.markSeasonSeen.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 500 })));
    component.toggleSeasonSeen(component.currentSeason()!, new Event('click'));
    expect(component.currentSeason()?.episodes.map(ep => ep.seen)).toEqual([true, false]);
    expect(component.currentSeason()?.episodes.map(ep => ep.watchCount)).toEqual([2, 0]);
    expect(api.markSeen).not.toHaveBeenCalled();
  });

  it('ignores a previous media mutation after navigating to a different media', () => {
    const pending = new Subject<{ id: number; watchedAt: string }>();
    api.addWatch.mockReturnValue(pending);
    component.ngOnInit();
    component.quickAddWatch();
    api.states.mockReturnValue(of([{ tmdbId: 43, seen: false, watchCount: 0, liked: false, listIds: [] }]));
    routeParams.next(convertToParamMap({ tmdbId: '43' }));
    pending.next({ id: 9, watchedAt: '2026-01-01T00:00:00Z' });
    expect(component.userState().tmdbId).toBe(43);
    expect(component.currentWatchCount).toBe(0);
    expect(component.quickAddPending()).toBe(false);
  });

  it('reloads authoritative state after a concurrency conflict', () => {
    component.ngOnInit();
    api.states.mockReturnValue(of([{ tmdbId: 42, seen: true, watchCount: 5, liked: false, listIds: [] }]));
    api.addWatch.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 409, error: 'Conflit' })));
    component.quickAddWatch();
    expect(component.currentWatchCount).toBe(5);
    expect(component.reconcilingState()).toBe(false);
  });

  it('does not overlap add-watch and mark-seen requests', () => {
    component.ngOnInit();
    api.addWatch.mockReturnValue(new Subject());
    component.quickAddWatch();
    component.toggleSeen();
    expect(api.markSeen).not.toHaveBeenCalled();
  });
});
