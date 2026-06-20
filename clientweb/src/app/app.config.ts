import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { providePrimeNG } from 'primeng/config';
import { MessageService } from 'primeng/api';
import Aura from '@primeuix/themes/aura';
import { definePreset } from '@primeuix/themes';

import { routes } from './app.routes';

const TrackerPreset = definePreset(Aura, {
  semantic: {
    primary: {
      50: '#fff7e4',
      100: '#ffedc2',
      200: '#f8d48c',
      300: '#e7b766',
      400: '#d39a4a',
      500: '#bd7d33',
      600: '#9a5f25',
      700: '#74451d',
      800: '#503017',
      900: '#2f1f12',
      950: '#1a1109',
    },
    colorScheme: {
      dark: {
        primary: {
          color: '#e7b766',
          contrastColor: '#1c150b',
          hoverColor: '#f1c979',
          activeColor: '#d39a4a',
        },
        surface: {
          0: '#ffffff',
          50: '#f8f3ea',
          100: '#e7ded0',
          200: '#c9bead',
          300: '#a99c8a',
          400: '#857c6f',
          500: '#6d6458',
          600: '#524b43',
          700: '#37312b',
          800: '#1b1814',
          900: '#141210',
          950: '#0e0c0a',
        },
      },
    },
  },
});

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(),
    provideAnimationsAsync(),
    MessageService,
    providePrimeNG({
      ripple: true,
      inputVariant: 'filled',
      theme: {
        preset: TrackerPreset,
        options: {
          darkModeSelector: ':root',
          cssLayer: false,
        },
      },
    }),
  ],
};
