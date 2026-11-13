import { TestBed } from '@angular/core/testing';
import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { MessageService } from 'primeng/api';
import { Api, Settings } from '../../../shared/services/api';
import { SettingsState } from '../../../shared/services/settings-state';
import { ThemeService } from '../../../shared/services/theme';
import { SettingsPage } from './settings';

describe('SettingsPage API consistency', () => {
  const saved: Settings = {
    ntfyEnabled: false, notifyDaysAhead: 1, notificationHour: 9,
    notificationMinute: 0, torrentsEnabled: true, updatedAt: '2026-01-01T00:00:00Z',
  };
  let api: { settings: ReturnType<typeof vi.fn>; updateSettings: ReturnType<typeof vi.fn>; sendTestNotification: ReturnType<typeof vi.fn>; calendarInfo: ReturnType<typeof vi.fn> };
  let messages: { add: ReturnType<typeof vi.fn> };
  let page: SettingsPage;

  beforeEach(() => {
    api = {
      settings: vi.fn(() => of(saved)), updateSettings: vi.fn(() => of(saved)),
      sendTestNotification: vi.fn(() => of(null)), calendarInfo: vi.fn(() => of({ httpsUrl: 'https://tracker.example/calendar.ics' })),
    };
    messages = { add: vi.fn() };
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api }, { provide: MessageService, useValue: messages },
      { provide: SettingsState, useValue: { apply: vi.fn() } }, { provide: ThemeService, useValue: {} },
    ] });
    page = TestBed.runInInjectionContext(() => new SettingsPage());
  });

  it('does not overwrite saved configuration with defaults after a load failure', () => {
    api.settings.mockReturnValue(throwError(() => new Error('offline')));
    page.ngOnInit();
    page.save();
    page.sendTestNotification();
    expect(page.loadFailed()).toBe(true);
    expect(api.updateSettings).not.toHaveBeenCalled();
    api.settings.mockReturnValue(of(saved));
    page.loadSettings();
    expect(page.loadFailed()).toBe(false);
  });

  it('sends bounded integer notification values expected by the API', () => {
    page.ngOnInit();
    page.form.notifyDaysAhead = 4.8;
    page.form.notificationHour = 25;
    page.form.notificationMinute = 12.5;
    page.save();
    expect(api.updateSettings).toHaveBeenCalledWith(expect.objectContaining({
      notifyDaysAhead: 4, notificationHour: 23, notificationMinute: 12,
    }));
  });

  it('shows the API validation message when settings are rejected', () => {
    page.ngOnInit();
    api.updateSettings.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 400, error: 'URL HTTP(S) requise.' })));
    page.save();
    expect(messages.add).toHaveBeenLastCalledWith(expect.objectContaining({ severity: 'error', detail: 'URL HTTP(S) requise.' }));
  });

  it('does not claim clipboard success when the clipboard is unavailable', async () => {
    const original = Object.getOwnPropertyDescriptor(navigator, 'clipboard');
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined });
    try {
      page.copyCalendarLink();
      await Promise.resolve();
      expect(page.calendarCopied()).toBe(false);
      expect(messages.add).toHaveBeenLastCalledWith(expect.objectContaining({ severity: 'error' }));
    } finally {
      if (original) Object.defineProperty(navigator, 'clipboard', original);
      else Reflect.deleteProperty(navigator, 'clipboard');
    }
  });
});
