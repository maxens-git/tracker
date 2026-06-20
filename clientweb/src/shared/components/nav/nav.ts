import { Component, signal, HostListener } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
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
  open = signal(false);

  readonly items: NavItem[] = [
    { label: 'Accueil', path: '/home', icon: 'pi pi-home' },
    { label: 'Recherche', path: '/search', icon: 'pi pi-search' },
    { label: 'Mes listes', path: '/lists', icon: 'pi pi-th-large' },
    { label: 'Sorties', path: '/releases', icon: 'pi pi-calendar' },
    { label: 'Activité', path: '/activity', icon: 'pi pi-clock' },
    { label: 'Statistiques', path: '/stats', icon: 'pi pi-chart-bar' },
    { label: 'Réglages', path: '/settings', icon: 'pi pi-cog' },
  ];

  toggle() { this.open.update(v => !v); }
  close() { this.open.set(false); }

  @HostListener('document:keydown.escape')
  onEscape() { this.close(); }
}
