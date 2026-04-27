import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { MovieDetailsComponent } from './shared/components/movie-details/movie-details';
import { ShowDetailsComponent } from './shared/components/show-details/show-details';
import { Search } from './pages/search/search';
import { Listes } from './pages/listes/listes';
import { Stats } from './pages/stats/stats';

export const routes: Routes = [
    { path: '', component: Home },
    { path: 'movies/:id', component: MovieDetailsComponent },
    { path: 'shows/:id', component: ShowDetailsComponent },
    { path: 'search', component: Search },
    { path: 'listes', component: Listes },
    { path: 'stats', component: Stats },
    { path: '**', redirectTo: '' }
];
