import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { Search } from './pages/search/search';
import { MediaDetail } from './pages/media-detail/media-detail';
import { Lists } from './pages/lists/lists';
import { ListDetail } from './pages/list-detail/list-detail';
import { StatsPage } from './pages/stats/stats';

export const routes: Routes = [
    { path: '', redirectTo: 'home', pathMatch: 'full' },
    { path: 'home', component: Home },
    { path: 'search', component: Search },
    { path: 'lists', component: Lists },
    { path: 'lists/:id', component: ListDetail },
    { path: 'stats', component: StatsPage },
    { path: 'movie/:tmdbId', component: MediaDetail, data: { type: 'movie' } },
    { path: 'tv/:tmdbId', component: MediaDetail, data: { type: 'tv' } },
];
