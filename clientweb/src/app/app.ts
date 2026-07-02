import { Component, signal, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import {
  RouterOutlet,
  Router,
  NavigationStart,
  NavigationEnd,
  NavigationCancel,
  NavigationError,
} from '@angular/router';
import { ToastModule } from 'primeng/toast';
import { Nav } from '../shared/components/nav/nav';
import { ThemeService } from '../shared/services/theme';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, Nav, ToastModule],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  private readonly router = inject(Router);

  // Vrai pendant qu'une navigation est en cours (chunk lazy en cours de
  // téléchargement inclus). Alimente la barre de progression en haut de page
  // pour donner un retour visuel immédiat, même sur connexion lente.
  readonly navigating = signal(false);

  constructor(readonly theme: ThemeService) {
    this.router.events.pipe(takeUntilDestroyed()).subscribe(event => {
      if (event instanceof NavigationStart) {
        this.navigating.set(true);
      } else if (
        event instanceof NavigationEnd ||
        event instanceof NavigationCancel ||
        event instanceof NavigationError
      ) {
        this.navigating.set(false);
      }
    });
  }
}
