import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MenuItem } from 'primeng/api';
import { MenubarModule } from 'primeng/menubar';
import { MenuModule } from 'primeng/menu';
import { ButtonModule } from 'primeng/button';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-tab-bar',
  imports: [MenubarModule, MenuModule, ButtonModule, FormsModule],
  templateUrl: './tab-bar.html',
  styleUrl: './tab-bar.scss',
})
export class TabBar {
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);

  currentUser = this.authService.currentUser;

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

  profileItems: MenuItem[] = [
    { label: 'Déconnexion', icon: 'pi pi-sign-out', command: () => this.logout() }
  ];

  logout(): void {
    this.authService.logout();
  }
}
