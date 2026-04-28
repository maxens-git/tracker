import { Component, inject, signal, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Api } from '../../../shared/services/api';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { Spinner } from '../../../shared/components/spinner/spinner';

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

  totalCount(list: MediaListSummary): string {
    const parts: string[] = [];
    if (list.moviesCount) parts.push(`${list.moviesCount} film${list.moviesCount > 1 ? 's' : ''}`);
    if (list.showsCount) parts.push(`${list.showsCount} série${list.showsCount > 1 ? 's' : ''}`);
    return parts.length ? parts.join(' · ') : 'Vide';
  }
}
