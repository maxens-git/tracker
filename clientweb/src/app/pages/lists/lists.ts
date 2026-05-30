import { Component, inject, signal, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Api } from '../../../shared/services/api';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SLUG_BY_SYSTEM_LIST } from '../../../shared/constants';

@Component({
  selector: 'app-lists',
  standalone: true,
  imports: [RouterLink, Spinner],
  templateUrl: './lists.html',
  styleUrl: './lists.scss',
})
export class Lists implements OnInit {
  private api = inject(Api);

  lists = signal<MediaListSummary[]>([]);
  loading = signal(true);
  error = signal(false);

  ngOnInit() {
    this.api.lists().subscribe({
      next: data => { this.lists.set(data); this.loading.set(false); },
      error: () => { this.error.set(true); this.loading.set(false); },
    });
  }

  listIcon(list: MediaListSummary): string {
    if (list.icon) return list.icon;
    return list.name.charAt(0).toUpperCase();
  }

  /**
   * Identifiant de route : slug pour les listes système (virtuelles côté backend),
   * id numérique pour les listes personnalisées.
   */
  listRouteId(list: MediaListSummary): string | number {
    return (list.isSystem && SLUG_BY_SYSTEM_LIST[list.name]) || list.id;
  }

  totalCount(list: MediaListSummary): string {
    return list.itemsCount > 0 ? `${list.itemsCount} élément${list.itemsCount > 1 ? 's' : ''}` : 'Vide';
  }
}
