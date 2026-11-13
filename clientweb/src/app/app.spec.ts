import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { MessageService } from 'primeng/api';
import { of } from 'rxjs';
import { SettingsState } from '../shared/services/settings-state';
import { ThemeService } from '../shared/services/theme';
import { App } from './app';

@Component({ template: 'Page chargée' })
class TestPage {}

describe('App', () => {
  let allowNavigation: ((value: boolean) => void) | undefined;

  beforeEach(async () => {
    allowNavigation = undefined;
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [
        provideRouter([{ path: 'delayed', component: TestPage,
          canActivate: [() => new Promise<boolean>(resolve => { allowNavigation = resolve; })] }]),
        MessageService,
        { provide: ThemeService, useValue: {} },
        { provide: SettingsState, useValue: { load: () => of({ torrentsEnabled: false }), torrentsEnabled: signal(false) } },
      ],
    }).compileComponents();
  });

  it('renders the application navigation and route content', async () => {
    const fixture = TestBed.createComponent(App);
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    expect(element.querySelector('main router-outlet')).not.toBeNull();
    expect(element.querySelector('a.brand')?.textContent).toContain('Tracker');
    expect(element.querySelector('a[href="/torrents"]')).toBeNull();
  });

  it('clears the loading state when navigation is cancelled', async () => {
    const fixture = TestBed.createComponent(App);
    const router = TestBed.inject(Router);
    const navigation = router.navigateByUrl('/delayed');
    await vi.waitFor(() => expect(allowNavigation).toBeDefined());
    expect(fixture.componentInstance.navigating()).toBe(true);
    allowNavigation!(false);
    expect(await navigation).toBe(false);
    expect(fixture.componentInstance.navigating()).toBe(false);
  });
});
