import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { MovieDetailsComponent } from './shared/components/movie-details/movie-details';
import { ShowDetailsComponent } from './shared/components/show-details/show-details';
import { Search } from './pages/search/search';
import { Listes } from './pages/listes/listes';
import { Stats } from './pages/stats/stats';
import { Login } from './pages/login/login';
import { authGuard, publicGuard } from './shared/guards/auth.guard';

export const routes: Routes = [
    { path: 'login', component: Login, canActivate: [publicGuard] },
    { path: '', component: Home, canActivate: [authGuard] },
    { path: 'movies/:id', component: MovieDetailsComponent, canActivate: [authGuard] },
    { path: 'shows/:id', component: ShowDetailsComponent, canActivate: [authGuard] },
    { path: 'search', component: Search, canActivate: [authGuard] },
    { path: 'listes', component: Listes, canActivate: [authGuard] },
    { path: 'stats', component: Stats, canActivate: [authGuard] },
    { path: '**', redirectTo: '' }
];
