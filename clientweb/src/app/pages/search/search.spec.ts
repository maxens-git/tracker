import { TestBed } from '@angular/core/testing';
import { Location } from '@angular/common';
import { ActivatedRoute, convertToParamMap, Router } from '@angular/router';
import { of, Subject, throwError } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { SearchHistoryService } from '../../../shared/services/search-history';
import { MediaItem, UserState } from '../../../shared/interfaces/media';
import { Search } from './search';

const movie: MediaItem = {
  id: 42, media_type: 'movie', title: 'Dune', vote_average: 8,
  vote_count: 100, popularity: 100, seen: false,
};

describe('Search request lifecycle', () => {
  let component: Search;
  let tmdb: { genres: ReturnType<typeof vi.fn>; searchPages: ReturnType<typeof vi.fn> };
  let api: { statesByTmdbId: ReturnType<typeof vi.fn> };
  let record: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.useFakeTimers();
    tmdb = { genres: vi.fn(() => of([])), searchPages: vi.fn(() => of([movie])) };
    api = { statesByTmdbId: vi.fn(() => of(new Map<string, UserState>())) };
    record = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        { provide: Router, useValue: { createUrlTree: vi.fn(() => '/search'), serializeUrl: vi.fn(() => '/search') } },
        { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap({}) } } },
        { provide: Location, useValue: { replaceState: vi.fn() } },
        { provide: TmdbService, useValue: tmdb },
        { provide: Api, useValue: api },
        { provide: SearchHistoryService, useValue: { record } },
      ],
    });
    component = TestBed.runInInjectionContext(() => new Search());
    component.ngOnInit();
  });

  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
  });

  it('cancels prior API state enrichment as soon as the query changes', async () => {
    const oldStates = new Subject<Map<string, UserState>>();
    api.statesByTmdbId.mockReturnValueOnce(oldStates);
    component.query = 'Dune';
    component.onInput();
    await vi.advanceTimersByTimeAsync(300);
    expect(oldStates.observed).toBe(true);

    component.query = 'Alien';
    component.onInput();
    expect(oldStates.observed).toBe(false);
    oldStates.next(new Map());
    expect(component.loading()).toBe(true);
    expect(record).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(300);
    expect(record).toHaveBeenCalledExactlyOnceWith('Alien');
  });

  it('keeps accepting queries after an API enrichment failure', async () => {
    api.statesByTmdbId.mockReturnValueOnce(throwError(() => new Error('API unavailable')));
    component.query = 'Dune';
    component.onInput();
    await vi.advanceTimersByTimeAsync(300);
    expect(component.error()).toBe(true);
    expect(component.loading()).toBe(false);

    component.query = 'Alien';
    component.onInput();
    await vi.advanceTimersByTimeAsync(300);
    expect(component.error()).toBe(false);
    expect(component.allResults()).toHaveLength(1);
    expect(tmdb.searchPages).toHaveBeenCalledTimes(2);
  });

  it('reports a TMDB failure instead of displaying a successful empty search', async () => {
    tmdb.searchPages.mockReturnValueOnce(throwError(() => new Error('TMDB unavailable')));
    component.query = 'Dune';
    component.onInput();
    await vi.advanceTimersByTimeAsync(300);
    expect(component.error()).toBe(true);
    expect(record).not.toHaveBeenCalled();
  });

  it('clearing the query immediately cancels the previous request', async () => {
    const response = new Subject<MediaItem[]>();
    tmdb.searchPages.mockReturnValue(response);
    component.query = 'Dune';
    component.onInput();
    await vi.advanceTimersByTimeAsync(300);
    component.query = '';
    component.onInput();
    expect(response.observed).toBe(false);
    expect(component.searched()).toBe(false);
    expect(component.loading()).toBe(false);
    expect(component.allResults()).toEqual([]);
  });
});
