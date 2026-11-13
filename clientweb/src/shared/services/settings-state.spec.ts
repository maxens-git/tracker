import { TestBed } from '@angular/core/testing';
import { Subject } from 'rxjs';
import { Api, Settings } from './api';
import { SettingsState } from './settings-state';

describe('SettingsState', () => {
  it('keeps saved settings when an older GET completes afterwards', () => {
    const response = new Subject<Settings>();
    TestBed.configureTestingModule({ providers: [{ provide: Api, useValue: { settings: () => response } }] });
    const state = TestBed.inject(SettingsState);
    const received: Settings[] = [];
    state.load().subscribe(settings => received.push(settings));
    const saved = { torrentsEnabled: false, tmdbApiKey: 'new-key' } as Settings;

    state.apply(saved);
    response.next({ torrentsEnabled: true, tmdbApiKey: 'old-key' } as Settings);

    expect(state.torrentsEnabled()).toBe(false);
    expect(received).toEqual([saved]);
    state.load().subscribe(settings => expect(settings).toBe(saved));
  });
});
