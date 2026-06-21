import { DOCUMENT, isPlatformBrowser } from '@angular/common';
import { DestroyRef, Injectable, PLATFORM_ID, inject, signal } from '@angular/core';

export type ThemeMode = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

const THEME_STORAGE_KEY = 'tracker.theme';
const DARK_QUERY = '(prefers-color-scheme: dark)';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly document = inject(DOCUMENT);
  private readonly platformId = inject(PLATFORM_ID);
  private readonly destroyRef = inject(DestroyRef);
  private readonly isBrowser = isPlatformBrowser(this.platformId);
  private readonly mediaQuery = this.isBrowser ? window.matchMedia(DARK_QUERY) : null;

  readonly mode = signal<ThemeMode>('system');
  readonly resolvedTheme = signal<ResolvedTheme>('dark');

  constructor() {
    if (!this.isBrowser) return;

    this.mode.set(this.readStoredMode());
    this.applyTheme();

    const onSystemThemeChange = () => {
      if (this.mode() === 'system') {
        this.applyTheme();
      }
    };

    this.mediaQuery?.addEventListener('change', onSystemThemeChange);
    this.destroyRef.onDestroy(() => this.mediaQuery?.removeEventListener('change', onSystemThemeChange));
  }

  setMode(mode: ThemeMode) {
    this.mode.set(mode);
    try {
      localStorage.setItem(THEME_STORAGE_KEY, mode);
    } catch {
      // Le thème reste appliqué pour la session courante.
    }
    this.applyTheme();
  }

  private readStoredMode(): ThemeMode {
    try {
      const value = localStorage.getItem(THEME_STORAGE_KEY);
      return value === 'light' || value === 'dark' || value === 'system' ? value : 'system';
    } catch {
      return 'system';
    }
  }

  private resolveTheme(): ResolvedTheme {
    const mode = this.mode();

    if (mode === 'system') {
      return this.mediaQuery?.matches ? 'dark' : 'light';
    }

    return mode;
  }

  private applyTheme() {
    const theme = this.resolveTheme();
    const root = this.document.documentElement;

    this.resolvedTheme.set(theme);
    root.dataset['theme'] = theme;
    root.dataset['themeMode'] = this.mode();
    root.style.colorScheme = theme;

    this.document
      .querySelector<HTMLMetaElement>('meta[name="theme-color"]')
      ?.setAttribute('content', theme === 'dark' ? '#141210' : '#f8f3ea');
  }
}
