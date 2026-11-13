import { TestBed } from '@angular/core/testing';
import { Subject } from 'rxjs';
import { MessageService } from 'primeng/api';
import { Api, SystemLog } from '../../../shared/services/api';
import { PaginatedResult } from '../../../shared/interfaces/list';
import { LogsPage } from './logs';

describe('LogsPage filters', () => {
  it('cancels old requests when filters change and retains submitted filters for later pages', () => {
    const first = new Subject<PaginatedResult<SystemLog>>();
    const filtered = new Subject<PaginatedResult<SystemLog>>();
    const more = new Subject<PaginatedResult<SystemLog>>();
    const logs = vi.fn().mockReturnValueOnce(first).mockReturnValueOnce(filtered).mockReturnValueOnce(more);
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: { logs } }, { provide: MessageService, useValue: { add: vi.fn() } },
    ] });
    const page = TestBed.runInInjectionContext(() => new LogsPage());
    page.ngOnInit();
    page.level = 'Error';
    page.search = 'failed';
    page.refresh();
    first.next({ items: [{ id: 1 } as SystemLog], page: 1, pageSize: 100, totalPages: 1, totalCount: 1 });
    filtered.next({ items: [{ id: 2 } as SystemLog], page: 1, pageSize: 100, totalPages: 2, totalCount: 101 });
    filtered.complete();
    expect(page.logs().map(log => log.id)).toEqual([2]);
    page.search = 'not submitted';
    page.loadMore();
    expect(logs).toHaveBeenLastCalledWith(2, 'Error', 'failed');
  });
});
