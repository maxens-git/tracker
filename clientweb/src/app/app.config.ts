import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter, withRouterConfig, RouteReuseStrategy } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { ReloadRouteReuseStrategy } from '../shared/reload-route-reuse-strategy';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { providePrimeNG } from 'primeng/config';
import { MessageService } from 'primeng/api';
import Aura from '@primeuix/themes/aura';
import { definePreset } from '@primeuix/themes';

import { routes } from './app.routes';

/**
 * Aura, mais avec la palette primary d'origine (emerald) remplacée par une rampe
 * construite autour de l'accent doré de clientios — Color.appAccent, #E7B766
 * (H 38°, S 73%). En thème clair on descend à primary.800 : le doré plein ne
 * tient pas le contraste, ni en texte sur blanc ni en blanc sur aplat.
 */
const TrackerPreset = definePreset(Aura, {
  semantic: {
    primary: {
      50: '#fcf7ed',
      100: '#f9edd7',
      200: '#f3dcb4',
      300: '#eecc91',
      400: '#eac17b',
      500: '#e7b766',
      600: '#e0a338',
      700: '#c7891f',
      800: '#9a6b18',
      900: '#775213',
      950: '#47310b',
    },
    colorScheme: {
      light: {
        primary: {
          color: '{primary.800}',
          contrastColor: '#ffffff',
          hoverColor: '{primary.900}',
          activeColor: '{primary.950}',
        },
      },
      dark: {
        primary: {
          color: '{primary.500}',
          contrastColor: '{primary.950}',
          hoverColor: '{primary.400}',
          activeColor: '{primary.300}',
        },
      },
    },
  },
});

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes, withRouterConfig({ onSameUrlNavigation: 'reload' })),
    { provide: RouteReuseStrategy, useClass: ReloadRouteReuseStrategy },
    provideHttpClient(),
    provideAnimationsAsync(),
    MessageService,
    providePrimeNG({
      ripple: true,
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
