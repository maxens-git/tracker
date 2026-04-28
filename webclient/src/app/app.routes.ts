import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { Search } from './pages/search/search';
import { MediaDetail } from './pages/media-detail/media-detail';

export const routes: Routes = [
    { path: '', redirectTo: 'home', pathMatch: 'full' },
    { path: 'home', component: Home },
    { path: 'search', component: Search },
    { path: 'movie/:tmdbId', component: MediaDetail, data: { type: 'movie' } },
    { path: 'tv/:tmdbId', component: MediaDetail, data: { type: 'tv' } },
];
