import { TestBed } from '@angular/core/testing';
import { SimpleChange } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { MessageService } from 'primeng/api';
import { of, Subject, throwError } from 'rxjs';
import { Api } from '../../services/api';
import { WatchEvent } from '../../interfaces/watch-event';
import { WatchHistoryDialog } from './watch-history-dialog';

describe('WatchHistoryDialog consistency', () => {
  let component: WatchHistoryDialog;
  let api: ReturnType<typeof apiMock>;
  function apiMock() {
    return {
      getWatches: vi.fn(() => of<WatchEvent[]>([])),
      addWatch: vi.fn(() => of<WatchEvent>({ id: 1, watchedAt: '2026-01-01T00:00:00Z' })),
      deleteWatch: vi.fn(() => of({})),
    };
  }
  function open() {
    component.visible = true;
    component.ngOnChanges({ visible: new SimpleChange(false, true, false) });
  }
  beforeEach(() => {
    api = apiMock();
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api },
      { provide: MessageService, useValue: { add: vi.fn() } },
    ] });
    component = TestBed.runInInjectionContext(() => new WatchHistoryDialog());
    component.tmdbId = 42;
    component.mediaType = 'movie';
  });

  it('blocks additions until the history is loaded', () => {
    api.getWatches.mockReturnValue(new Subject());
    open();
    component.addWatch();
    expect(api.addWatch).not.toHaveBeenCalled();
  });

  it('does not present failed history as an empty writable history', () => {
    api.getWatches.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 500 })));
    open();
    component.addWatch();
    expect(component.historyError()).toBeTruthy();
    expect(api.addWatch).not.toHaveBeenCalled();
  });

  it('rejects invalid dates without throwing or sending a request', () => {
    open();
    component.newDate = new Date(NaN);
    expect(() => component.addWatch()).not.toThrow();
    component.newDate = null;
    component.addWatch();
    expect(api.addWatch).not.toHaveBeenCalled();
    expect(component.adding()).toBe(false);
  });

  it('ignores old target responses when opening a different media', () => {
    const oldRequest = new Subject<WatchEvent[]>();
    api.getWatches.mockReturnValueOnce(oldRequest).mockReturnValueOnce(of([{ id: 2, watchedAt: '2026-02-01' }]));
    open();
    component.tmdbId = 43;
    component.ngOnChanges({ tmdbId: new SimpleChange(42, 43, false) });
    oldRequest.next([{ id: 1, watchedAt: '2026-01-01' }]);
    expect(component.events().map(event => event.id)).toEqual([2]);
  });

  it('reloads the server history after a conflict', () => {
    open();
    api.getWatches.mockReturnValue(of([{ id: 2, watchedAt: '2026-02-01' }]));
    api.addWatch.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 409 })));
    component.addWatch();
    expect(component.events().map(event => event.id)).toEqual([2]);
    expect(component.adding()).toBe(false);
  });
});
