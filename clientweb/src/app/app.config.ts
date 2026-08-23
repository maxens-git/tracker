import { ApplicationConfig, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import { provideRouter, withRouterConfig, RouteReuseStrategy } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { ReloadRouteReuseStrategy } from '../shared/reload-route-reuse-strategy';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { providePrimeNG } from 'primeng/config';
import { MessageService } from 'primeng/api';
import Aura from '@primeuix/themes/aura';
import { definePreset, palette } from '@primeuix/themes';

import { routes } from './app.routes';

// Sans cet enregistrement, le pipe `date` retombe sur en-US et sort des mois en
// anglais (« 12 Aug 2026 ») dans une interface par ailleurs entièrement française.
registerLocaleData(localeFr);

// Aura fait défiler quatre teintes dans le spinner ; on le veut monochrome.
const SPINNER_COLORS = {
  root: {
    colorOne: '{primary.color}',
    colorTwo: '{primary.color}',
    colorThree: '{primary.color}',
    colorFour: '{primary.color}',
  },
};

/**
 * Aura tel quel, à deux exceptions près : la rampe `primary` pointe sur le bleu
 * d'Aura plutôt que sur l'emerald d'origine (pour rester aligné sur le tint
 * bleu du client iOS), et le spinner devient monochrome. Tout le reste —
 * surfaces, rayons, focus ring, états — vient du preset stock : aucune valeur
 * de thème n'est recopiée à la main, ici ou dans les feuilles de style.
 */
const TrackerPreset = definePreset(Aura, {
  semantic: {
    primary: palette('{blue}'),
  },
  components: {
    progressspinner: {
      colorScheme: { light: SPINNER_COLORS, dark: SPINNER_COLORS },
    },
  },
});

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    { provide: LOCALE_ID, useValue: 'fr-FR' },
    provideRouter(routes, withRouterConfig({ onSameUrlNavigation: 'reload' })),
    { provide: RouteReuseStrategy, useClass: ReloadRouteReuseStrategy },
    provideHttpClient(),
    provideAnimationsAsync(),
    MessageService,
    providePrimeNG({
      translation: {
        dayNames: ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'],
        dayNamesShort: ['dim', 'lun', 'mar', 'mer', 'jeu', 'ven', 'sam'],
        dayNamesMin: ['D', 'L', 'M', 'M', 'J', 'V', 'S'],
        monthNames: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
        monthNamesShort: ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'],
        today: "Aujourd'hui",
        clear: 'Effacer',
        emptyMessage: 'Aucun résultat',
        emptySelectionMessage: 'Aucune sélection',
        emptySearchMessage: 'Aucun résultat',
        emptyFilterMessage: 'Aucun résultat',
        // Libellés lus par les lecteurs d'écran : paginator, overlays, tables.
        aria: {
          selectAll: 'Tout sélectionner',
          unselectAll: 'Tout désélectionner',
          close: 'Fermer',
          previous: 'Précédent',
          next: 'Suivant',
          navigation: 'Navigation',
          firstPageLabel: 'Première page',
          lastPageLabel: 'Dernière page',
          nextPageLabel: 'Page suivante',
          prevPageLabel: 'Page précédente',
          previousPageLabel: 'Page précédente',
          pageLabel: 'Page {page}',
          rowsPerPageLabel: 'Éléments par page',
        },
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
