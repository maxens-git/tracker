import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MenuItem } from 'primeng/api';
import { AvatarModule } from 'primeng/avatar';
import { MenubarModule } from 'primeng/menubar';
import { InputTextModule } from 'primeng/inputtext';
import { ButtonModule } from 'primeng/button';
import { TMDbSearchResult } from '../../interfaces/tmdb-trending.interface';

@Component({
  selector: 'app-tab-bar',
  imports: [MenubarModule, AvatarModule, InputTextModule, ButtonModule, FormsModule],
  templateUrl: './tab-bar.html',
  styleUrl: './tab-bar.scss',
})
export class TabBar {
  private readonly router: Router;

  items: MenuItem[] = [
    {
      label: 'Accueil',
      icon: 'pi pi-home',
      routerLink: '/'
    },
    {
      label: 'Recherche',
      icon: 'pi pi-search',
      routerLink: '/search'
    },
    {
      label: 'Mes listes',
      icon: 'pi pi-list',
      routerLink: '/listes'
    },
    {
      label: 'Statistiques',
      icon: 'pi pi-chart-bar',
      routerLink: '/stats'
    }
  ];

  constructor(router: Router) {
    this.router = router;
  }
}
