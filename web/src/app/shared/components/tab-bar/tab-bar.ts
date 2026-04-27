import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MenuItem } from 'primeng/api';
import { MenubarModule } from 'primeng/menubar';
import { MenuModule } from 'primeng/menu';
import { ButtonModule } from 'primeng/button';

@Component({
  selector: 'app-tab-bar',
  imports: [MenubarModule, MenuModule, ButtonModule, FormsModule],
  templateUrl: './tab-bar.html',
  styleUrl: './tab-bar.scss',
})
export class TabBar {
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
}
