import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { Search } from './pages/search/search';
import { MediaDetail } from './pages/media-detail/media-detail';
import { Lists } from './pages/lists/lists';
import { ListDetail } from './pages/list-detail/list-detail';
import { StatsPage } from './pages/stats/stats';
import { ActivityPage } from './pages/activity/activity';
import { Person } from './pages/person/person';
import { ReleaseCalendar } from './pages/release-calendar/release-calendar';
import { SettingsPage } from './pages/settings/settings';

export const routes: Routes = [
    { path: '', redirectTo: 'home', pathMatch: 'full' },
    { path: 'home', component: Home },
    { path: 'search', component: Search },
    { path: 'lists', component: Lists },
    { path: 'lists/:id', component: ListDetail },
    { path: 'stats', component: StatsPage },
    { path: 'activity', component: ActivityPage },
    { path: 'releases', component: ReleaseCalendar },
    { path: 'settings', component: SettingsPage },
    { path: 'movie/:tmdbId', component: MediaDetail, data: { type: 'movie' } },
    { path: 'tv/:tmdbId', component: MediaDetail, data: { type: 'tv' } },
    { path: 'person/:id', component: Person },
];
