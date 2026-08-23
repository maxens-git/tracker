import { Component } from '@angular/core';
import { ProgressSpinnerModule } from 'primeng/progressspinner';

/** Indicateur de chargement centré, utilisé par toutes les pages. */
@Component({
  selector: 'app-spinner',
  standalone: true,
  imports: [ProgressSpinnerModule],
  template: `
    <div class="spinner-wrap">
      <p-progress-spinner strokeWidth="4" animationDuration=".7s" ariaLabel="Chargement" />
    </div>
  `,
  styles: [`
    .spinner-wrap {
      display: grid;
      padding: 3rem 0;
      place-items: center;
    }

    :host ::ng-deep .p-progressspinner {
      width: 42px;
      height: 42px;
    }
  `],
})
export class Spinner {}
