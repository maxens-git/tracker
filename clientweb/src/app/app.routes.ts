import { Routes } from '@angular/router';

// Pages chargées à la demande : chaque écran est un chunk lazy, ce qui sort les
// dépendances lourdes (ex. primeng du calendrier des sorties) du bundle initial.
export const routes: Routes = [
    { path: '', redirectTo: 'home', pathMatch: 'full' },
    { path: 'home', loadComponent: () => import('./pages/home/home').then(m => m.Home) },
    { path: 'search', loadComponent: () => import('./pages/search/search').then(m => m.Search) },
    { path: 'lists', loadComponent: () => import('./pages/lists/lists').then(m => m.Lists) },
    { path: 'lists/:id', loadComponent: () => import('./pages/list-detail/list-detail').then(m => m.ListDetail) },
    { path: 'stats', loadComponent: () => import('./pages/stats/stats').then(m => m.StatsPage) },
    { path: 'activity', loadComponent: () => import('./pages/activity/activity').then(m => m.ActivityPage) },
    { path: 'logs', loadComponent: () => import('./pages/logs/logs').then(m => m.LogsPage) },
    { path: 'releases', loadComponent: () => import('./pages/release-calendar/release-calendar').then(m => m.ReleaseCalendar) },
    { path: 'settings', loadComponent: () => import('./pages/settings/settings').then(m => m.SettingsPage) },
    { path: 'movie/:tmdbId', loadComponent: () => import('./pages/media-detail/media-detail').then(m => m.MediaDetail), data: { type: 'movie' } },
    { path: 'tv/:tmdbId', loadComponent: () => import('./pages/media-detail/media-detail').then(m => m.MediaDetail), data: { type: 'tv' } },
    { path: 'person/:id', loadComponent: () => import('./pages/person/person').then(m => m.Person) },
];
