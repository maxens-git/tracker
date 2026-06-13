import { Directive, ElementRef, AfterViewInit, inject } from '@angular/core';

/** Place le focus sur l'élément à son apparition (ex. champ d'une modale). */
@Directive({ selector: '[appAutofocus]', standalone: true })
export class Autofocus implements AfterViewInit {
  private el = inject(ElementRef<HTMLElement>);

  ngAfterViewInit() {
    queueMicrotask(() => this.el.nativeElement.focus());
  }
}
