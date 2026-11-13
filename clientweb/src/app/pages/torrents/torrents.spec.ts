import { TestBed } from '@angular/core/testing';
import { Location } from '@angular/common';
import { ActivatedRoute, Router, convertToParamMap } from '@angular/router';
import { MessageService } from 'primeng/api';
import { of, Subject } from 'rxjs';
import { Api, TorrentBookmark, TorrentResult } from '../../../shared/services/api';
import { Torrents } from './torrents';

describe('Torrent bookmark API identity', () => {
  let page: Torrents;
  let api: { removeTorrentBookmark: ReturnType<typeof vi.fn>; addTorrentBookmark: ReturnType<typeof vi.fn>; unlockLink: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    api = { removeTorrentBookmark: vi.fn(() => of(null)), addTorrentBookmark: vi.fn(), unlockLink: vi.fn() };
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api }, { provide: MessageService, useValue: { add: vi.fn() } },
      { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap({}) } } },
      { provide: Router, useValue: {} }, { provide: Location, useValue: {} },
    ] });
    page = TestBed.runInInjectionContext(() => new Torrents());
    page.bookmarksLoading.set(false);
  });

  it('recognizes and removes the saved torrent when the magnet metadata differs', () => {
    const bookmark: TorrentBookmark = { ...torrent('magnet:?xt=urn:btih:ABC123&dn=first'), id: 7, addedAt: '' };
    page.bookmarks.set([bookmark]);
    const sameTorrent = torrent('magnet:?dn=second&xt=urn%3Abtih%3Aabc123&tr=https%3A%2F%2Ftracker.example');
    expect(page.isBookmarked(sameTorrent.magnetUrl)).toBe(true);
    page.toggleBookmark(sameTorrent);
    expect(api.removeTorrentBookmark).toHaveBeenCalledWith(7);
    expect(api.addTorrentBookmark).not.toHaveBeenCalled();
  });

  it('does not interpret an infohash inside the display name as torrent identity', () => {
    page.bookmarks.set([{ ...torrent('magnet:?xt=urn:btih:ABC123'), id: 7, addedAt: '' }]);
    expect(page.isBookmarked('magnet:?dn=urn:btih:ABC123')).toBe(false);
  });

  it('ignores a stale unlock response after its dialog is closed', () => {
    const pending = new Subject<{ directLink: string }>();
    api.unlockLink.mockReturnValue(pending);
    const file = { filename: 'film.mkv', size: 1, link: 'locked' };
    page.resolve(file);
    page.cancelLinkRequests();
    pending.next({ directLink: 'https://download.example/stale' });
    expect(page.resolvedLink(file)).toBeFalsy();
    expect(page.unlockingLink()).toBeNull();
  });
});

function torrent(magnetUrl: string): TorrentResult {
  return { magnetUrl, title: 'Torrent', indexer: 'Indexer', size: 1, seeders: 1, leechers: 0, category: null, publishDate: null };
}
