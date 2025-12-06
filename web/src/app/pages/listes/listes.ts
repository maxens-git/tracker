import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaListsService } from '../../shared/services/media-lists.service';
import { MediaListSummary } from '../../shared/interfaces/media-list.interface';

@Component({
  selector: 'app-listes',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './listes.html',
  styleUrl: './listes.scss',
})
export class Listes implements OnInit {
  protected lists = signal<MediaListSummary[] | null>(null);
  protected loading = signal<boolean>(true);
  protected error = signal<string | null>(null);

  constructor(private mediaListsService: MediaListsService) {}

  ngOnInit(): void {
    this.fetchLists();
  }

  private fetchLists(): void {
    this.loading.set(true);
    this.error.set(null);

    this.mediaListsService.getAll().subscribe({
      next: (data) => {
        this.lists.set(data);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossible de charger vos listes pour le moment.');
        this.loading.set(false);
      }
    });
  }
}
