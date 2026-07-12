import { ActivatedRouteSnapshot, BaseRouteReuseStrategy } from '@angular/router';

/**
 * Empêche la réutilisation d'un composant de page quand on renavigue vers la
 * même route (ex. reclic sur le lien déjà actif dans la sidebar). Combiné à
 * `onSameUrlNavigation: 'reload'`, le composant est détruit puis recréé, ce qui
 * réinitialise complètement la page (état, formulaires, résultats…).
 */
export class ReloadRouteReuseStrategy extends BaseRouteReuseStrategy {
  override shouldReuseRoute(_future: ActivatedRouteSnapshot, _curr: ActivatedRouteSnapshot): boolean {
    return false;
  }
}
