import { Component } from '@angular/core';
import { Menubar } from 'primeng/menubar';
import { MenuItem } from 'primeng/api';
import { Avatar } from 'primeng/avatar';

@Component({
  selector: 'app-tab-bar',
  imports: [Menubar, Avatar],
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
      label: 'Listes',
      icon: 'pi pi-search',
      routerLink: '/discover'
    }
  ];
}
