import { TestBed } from '@angular/core/testing';
import { Location } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { MessageService } from 'primeng/api';
import { of, Subject } from 'rxjs';
import { Api } from '../../../shared/services/api';
import { MediaListItem, PaginatedResult } from '../../../shared/interfaces/list';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { ListDetail } from './list-detail';

describe('ListDetail API consistency', () => {
  let page: ListDetail;
  let api: { listItems: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    api = { listItems: vi.fn(() => of(result(1, []))) };
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api }, { provide: MessageService, useValue: { add: vi.fn() } },
      { provide: ActivatedRoute, useValue: {} },
      { provide: Router, useValue: { createUrlTree: vi.fn(), serializeUrl: () => '/lists/1' } },
      { provide: Location, useValue: { replaceState: vi.fn() } },
      { provide: TmdbService, useValue: { fetchMany: (refs: { tmdbId: number; mediaType: string }[]) => of(refs.map(ref => ({
        id: ref.tmdbId, media_type: ref.mediaType, seen: false, vote_average: 0, vote_count: 0, popularity: 0,
      }))) } },
    ] });
    vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
    page = TestBed.runInInjectionContext(() => new ListDetail());
    page.listId = 1;
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
    expect(api.listItems).toHaveBeenLastCalledWith(1, 2);
    expect(page.page()).toBe(2);
    expect(page.items()).toHaveLength(1);
  });
});

function item(mediaType: string, watchCount: number): MediaListItem {
  return { tmdbId: 42, mediaType, watchCount, seen: true, liked: false, addedAt: '' };
}

function result(page: number, items: MediaListItem[]): PaginatedResult<MediaListItem> {
  return { page, items, pageSize: 30, totalCount: 31, totalPages: 2 };
}
