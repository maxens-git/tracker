import { TestBed } from '@angular/core/testing';
import { Location } from '@angular/common';
import { ActivatedRoute, convertToParamMap, ParamMap, Router } from '@angular/router';
import { MessageService } from 'primeng/api';
import { of, Subject, throwError } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { MediaListItem, PaginatedResult } from '../../../shared/interfaces/list';
import { MediaItem } from '../../../shared/interfaces/media';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { ListDetail } from './list-detail';

describe('ListDetail API consistency', () => {
  let page: ListDetail;
  let api: { listItems: ReturnType<typeof vi.fn>; list: ReturnType<typeof vi.fn> };
  let tmdb: { fetchMany: ReturnType<typeof vi.fn> };
  let route: { snapshot: { paramMap: ParamMap; queryParamMap: ParamMap } };

  beforeEach(() => {
    vi.useFakeTimers();
    api = { listItems: vi.fn(() => of(result(1, []))), list: vi.fn(() => of({ id: 1, name: 'Test' })) };
    tmdb = { fetchMany: vi.fn((refs: { tmdbId: number; mediaType: string }[]) => of(refs.map(ref => ({
      id: ref.tmdbId, media_type: ref.mediaType, seen: false, vote_average: 0, vote_count: 0, popularity: 0,
    })))) };
    route = { snapshot: { paramMap: convertToParamMap({ id: '1' }), queryParamMap: convertToParamMap({}) } };
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api }, { provide: MessageService, useValue: { add: vi.fn() } },
      { provide: ActivatedRoute, useValue: route },
      { provide: Router, useValue: { createUrlTree: vi.fn(), serializeUrl: () => '/lists/1' } },
      { provide: Location, useValue: { replaceState: vi.fn() } },
      { provide: TmdbService, useValue: tmdb },
    ] });
    vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
    page = TestBed.runInInjectionContext(() => new ListDetail());
    page.listId = 1;
  });

  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
  });

  it('keeps movie and show watch counts separate when their IDs overlap', () => {
    api.listItems.mockReturnValue(of(result(1, [item('movie', 1), item('tv', 3)])));
    page.loadPage(1);
    expect(page.items().map(item => item.watchCount)).toEqual([1, 3]);
  });

  it('ignores old pages that complete after a newer page was requested', () => {
    const old = new Subject<PaginatedResult<MediaListItem>>();
    api.listItems.mockReturnValueOnce(old).mockReturnValueOnce(of(result(2, [item('tv', 3)])));
    page.loadPage(1);
    page.loadPage(2);
    old.next(result(1, [item('movie', 1)]));
    expect(page.page()).toBe(2);
    expect(page.items()[0].media_type).toBe('tv');
  });

  it('loads the last available page when the bookmarked page no longer exists', () => {
    api.listItems.mockReturnValueOnce(of(result(9, []))).mockReturnValueOnce(of(result(2, [item('movie', 1)])));
    page.loadPage(9);
    expect(api.listItems).toHaveBeenLastCalledWith(1, 2, 'all', '');
    expect(page.page()).toBe(2);
    expect(page.items()).toHaveLength(1);
  });

  it('debounces typing and searches the whole list from page one', async () => {
    page.page.set(8);
    page.onQueryChange('Du');
    await vi.advanceTimersByTimeAsync(200);
    page.onQueryChange('  Dune  ');
    await vi.advanceTimersByTimeAsync(299);
    expect(api.listItems).not.toHaveBeenCalled();
    expect(page.page()).toBe(1);
    expect(page.loading()).toBe(true);

    api.listItems.mockReturnValueOnce(of(result(1, [item('movie', 1)])));
    await vi.advanceTimersByTimeAsync(1);
    expect(api.listItems).toHaveBeenCalledExactlyOnceWith(1, 1, 'all', 'Dune');
    expect(page.items()).toHaveLength(1);
    expect(page.totalCount()).toBe(31);
    expect(page.totalPages()).toBe(2);
    expect(page.loading()).toBe(false);
    expect(TestBed.inject(Router).createUrlTree).toHaveBeenLastCalledWith([], expect.objectContaining({
      queryParams: { page: null, search: 'Dune' },
    }));
  });

  it('retains the query when paging and correcting an out-of-range result page', () => {
    page.query = 'Alien';
    api.listItems.mockReturnValueOnce(of(result(9, []))).mockReturnValueOnce(of(result(2, [item('movie', 1)])));
    page.loadPage(9);
    expect(api.listItems).toHaveBeenNthCalledWith(1, 1, 9, 'all', 'Alien');
    expect(api.listItems).toHaveBeenLastCalledWith(1, 2, 'all', 'Alien');
    expect(page.page()).toBe(2);
    expect(page.totalCount()).toBe(31);
  });

  it('cancels stale results immediately when typing, before the debounce expires', async () => {
    const old = new Subject<PaginatedResult<MediaListItem>>();
    api.listItems.mockReturnValueOnce(old);
    page.loadPage(4);
    page.onQueryChange('Dune');
    expect(old.observed).toBe(false);
    old.next(result(4, [item('tv', 3)]));
    expect(page.items()).toEqual([]);
    expect(page.page()).toBe(1);
    expect(page.loading()).toBe(true);
    await vi.advanceTimersByTimeAsync(300);
    expect(api.listItems).toHaveBeenLastCalledWith(1, 1, 'all', 'Dune');
  });

  it('also cancels stale TMDB enrichment when changing the query', async () => {
    const old = new Subject<MediaItem[]>();
    tmdb.fetchMany.mockReturnValueOnce(old);
    api.listItems.mockReturnValueOnce(of(result(1, [item('movie', 1)])));
    page.loadPage(1);
    page.onQueryChange('Alien');
    expect(old.observed).toBe(false);
    old.next([{ id: 99, media_type: 'movie', seen: false, vote_average: 0, vote_count: 0, popularity: 0 }]);
    expect(page.items()).toEqual([]);
    await vi.advanceTimersByTimeAsync(300);
    expect(api.listItems).toHaveBeenLastCalledWith(1, 1, 'all', 'Alien');
  });

  it('clearing a search restores the unfiltered first page and removes it from the URL', async () => {
    page.query = 'Alien';
    page.page.set(2);
    page.onQueryChange('   ');
    await vi.advanceTimersByTimeAsync(300);
    expect(api.listItems).toHaveBeenCalledExactlyOnceWith(1, 1, 'all', '');
    expect(TestBed.inject(Router).createUrlTree).toHaveBeenLastCalledWith([], expect.objectContaining({
      queryParams: { page: null, search: null },
    }));
  });

  it('restores the query and result page together on reload', () => {
    route.snapshot.queryParamMap = convertToParamMap({ search: ' Dune ', page: '2' });
    api.listItems.mockReturnValueOnce(of(result(2, [item('movie', 1)])));
    page.ngOnInit();
    expect(page.query).toBe('Dune');
    expect(api.listItems).toHaveBeenCalledExactlyOnceWith(1, 2, 'all', 'Dune');
  });

  it('can search again after a request fails or returns no matches', async () => {
    api.listItems.mockReturnValueOnce(throwError(() => new Error('Unavailable')));
    page.onQueryChange('Dune');
    await vi.advanceTimersByTimeAsync(300);
    expect(page.pageError()).toBeTruthy();
    expect(page.loading()).toBe(false);

    api.listItems.mockReturnValueOnce(of({ ...result(1, []), totalCount: 0, totalPages: 0 }));
    page.onQueryChange('Unknown');
    await vi.advanceTimersByTimeAsync(300);
    expect(page.pageError()).toBeNull();
    expect(page.items()).toEqual([]);
    expect(page.totalCount()).toBe(0);

    api.listItems.mockReturnValueOnce(of(result(1, [item('movie', 1)])));
    page.onQueryChange('Alien');
    await vi.advanceTimersByTimeAsync(300);
    expect(page.items()).toHaveLength(1);
  });

  it('does not issue pending searches after leaving the page', async () => {
    page.onQueryChange('Dune');
    TestBed.resetTestingModule();
    await vi.advanceTimersByTimeAsync(300);
    expect(api.listItems).not.toHaveBeenCalled();
  });
});

function item(mediaType: string, watchCount: number): MediaListItem {
  return { tmdbId: 42, mediaType, watchCount, seen: true, liked: false, addedAt: '' };
}

function result(page: number, items: MediaListItem[]): PaginatedResult<MediaListItem> {
  return { page, items, pageSize: 30, totalCount: 31, totalPages: 2 };
}
