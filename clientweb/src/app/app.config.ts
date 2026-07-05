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
      light: {
        primary: {
          color: '#b87524',
          contrastColor: '#fffaf2',
          hoverColor: '#9d621d',
          activeColor: '#74451d',
        },
        surface: {
          0: '#ffffff',
          50: '#f4f2ec',
          100: '#e7e4dc',
          200: '#d3cfc5',
          300: '#b5b1a7',
          400: '#928e86',
          500: '#6d6a63',
          600: '#55524c',
          700: '#3d3b36',
          800: '#292723',
          900: '#1a1815',
          950: '#0d0c0a',
        },
      },
      dark: {
        primary: {
          color: '#e7b766',
          contrastColor: '#1c150b',
          hoverColor: '#f1c979',
          activeColor: '#d39a4a',
        },
        surface: {
          0: '#ffffff',
          50: '#f2f0ec',
          100: '#dcdad5',
          200: '#bcbab4',
          300: '#97958f',
          400: '#757370',
          500: '#5c5a57',
          600: '#45433f',
          700: '#2e2c2a',
          800: '#1d1d22',
          900: '#151519',
          950: '#08080a',
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
      translation: {
        dayNames: ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'],
        dayNamesShort: ['dim', 'lun', 'mar', 'mer', 'jeu', 'ven', 'sam'],
        dayNamesMin: ['D', 'L', 'M', 'M', 'J', 'V', 'S'],
        monthNames: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
        monthNamesShort: ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'],
        today: "Aujourd'hui",
        clear: 'Effacer',
      },
      theme: {
        preset: TrackerPreset,
        options: {
          darkModeSelector: '[data-theme="dark"]',
          cssLayer: false,
        },
      },
    }),
  ],
};
