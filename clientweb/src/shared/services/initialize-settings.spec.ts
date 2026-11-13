import { TestBed } from '@angular/core/testing';
import { NEVER, Subject, throwError } from 'rxjs';
import { Settings } from './api';
import { initializeSettings } from './initialize-settings';
import { SettingsState } from './settings-state';

describe('settings before initial navigation', () => {
  afterEach(() => vi.useRealTimers());

  it('waits for saved settings before completing initialization', async () => {
    const settings = new Subject<Settings>();
    TestBed.configureTestingModule({ providers: [{ provide: SettingsState, useValue: { load: () => settings } }] });
    const initialized = vi.fn();
    const result = TestBed.runInInjectionContext(initializeSettings).then(initialized);
    await Promise.resolve();
    expect(initialized).not.toHaveBeenCalled();
    settings.next({ torrentsEnabled: false } as Settings);
    await result;
    expect(initialized).toHaveBeenCalledOnce();
  });

  it('allows the application to start when settings fail', async () => {
    TestBed.configureTestingModule({ providers: [{ provide: SettingsState, useValue: { load: () => throwError(() => new Error('offline')) } }] });
    await expect(TestBed.runInInjectionContext(initializeSettings)).resolves.toBeUndefined();
  });

  it('bounds the wait for an unresponsive API', async () => {
    vi.useFakeTimers();
    TestBed.configureTestingModule({ providers: [{ provide: SettingsState, useValue: { load: () => NEVER } }] });
    const result = TestBed.runInInjectionContext(initializeSettings);
    await vi.advanceTimersByTimeAsync(5000);
    await expect(result).resolves.toBeUndefined();
  });
});
