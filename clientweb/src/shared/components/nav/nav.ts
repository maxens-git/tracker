import { Component, signal, HostListener, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import {
  RouterLink,
  RouterLinkActive,
  Router,
  NavigationStart,
  NavigationEnd,
  NavigationCancel,
  NavigationError,
} from '@angular/router';
import { ButtonModule } from 'primeng/button';
import { DrawerModule } from 'primeng/drawer';
import { Ripple } from 'primeng/ripple';

type NavItem = {
  label: string;
  path: string;
  icon: string;
  badge?: string;
};

@Component({
  selector: 'app-nav',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, ButtonModule, DrawerModule, Ripple],
  templateUrl: './nav.html',
  styleUrl: './nav.scss',
})
export class Nav {
  private readonly router = inject(Router);

  open = signal(false);

  // Chemin de la page vers laquelle on navigue actuellement (null au repos).
  // Permet d'afficher un spinner sur le lien cliqué le temps du chargement,
  // pour un retour immédiat même quand le chunk lazy met du temps à arriver.
  readonly pendingPath = signal<string | null>(null);

  constructor() {
    this.router.events.pipe(takeUntilDestroyed()).subscribe(event => {
      if (event instanceof NavigationStart) {
        this.pendingPath.set(event.url.split('?')[0]);
      } else if (
        event instanceof NavigationEnd ||
        event instanceof NavigationCancel ||
        event instanceof NavigationError
      ) {
        this.pendingPath.set(null);
      }
    });
  }

  readonly items: NavItem[] = [
    { label: 'Accueil', path: '/home', icon: 'pi pi-home' },
    { label: 'Recherche', path: '/search', icon: 'pi pi-search' },
    { label: 'Torrents', path: '/torrents', icon: 'pi pi-download' },
    { label: 'Mes listes', path: '/lists', icon: 'pi pi-th-large' },
    { label: 'Sorties', path: '/releases', icon: 'pi pi-calendar' },
    { label: 'Activité', path: '/activity', icon: 'pi pi-clock' },
    { label: 'Logs', path: '/logs', icon: 'pi pi-list-check' },
    { label: 'Statistiques', path: '/stats', icon: 'pi pi-chart-bar' },
    { label: 'Réglages', path: '/settings', icon: 'pi pi-cog' },
  ];

  toggle() { this.open.update(v => !v); }
  close() { this.open.set(false); }

  @HostListener('document:keydown.escape')
  onEscape() { this.close(); }
}
