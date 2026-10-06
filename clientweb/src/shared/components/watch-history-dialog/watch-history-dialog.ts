import { Component, EventEmitter, Input, OnChanges, Output, SimpleChanges, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DialogModule } from 'primeng/dialog';
import { ButtonModule } from 'primeng/button';
import { DatePickerModule } from 'primeng/datepicker';
import { MessageService } from 'primeng/api';
import { Api } from '../../services/api';
import { WatchEvent } from '../../interfaces/watch-event';
import { TmdbGenre } from '../../interfaces/media';
import { errorMessage } from '../../services/http-error';

/** Nombre de visionnages et statut "vu" recalculés après une modification de l'historique. */
export interface WatchCountChange {
  watchCount: number;
  seen: boolean;
}

/**
 * Modale d'historique de visionnages : liste les visionnages passés (avec suppression)
 * et permet d'en ajouter un à une date choisie. Réutilisable pour un film/série
 * (tmdbId + mediaType) ou un épisode précis (+ seasonNumber/episodeNumber).
 */
@Component({
  selector: 'app-watch-history-dialog',
  standalone: true,
  imports: [CommonModule, FormsModule, DialogModule, ButtonModule, DatePickerModule],
  templateUrl: './watch-history-dialog.html',
  styleUrl: './watch-history-dialog.scss',
})
export class WatchHistoryDialog implements OnChanges {
  private api = inject(Api);
  private messages = inject(MessageService);

  @Input() visible = false;
  @Input({ required: true }) tmdbId!: number;
  @Input({ required: true }) mediaType!: 'movie' | 'tv';
  @Input() seasonNumber: number | null = null;
  @Input() episodeNumber: number | null = null;
  @Input() title: string | null | undefined = null;
  @Input() posterPath: string | null | undefined = null;
  @Input() runtime: number | null | undefined = null;
  @Input() genres: TmdbGenre[] | null = null;

  @Output() visibleChange = new EventEmitter<boolean>();
  @Output() watchCountChanged = new EventEmitter<WatchCountChange>();

  events = signal<WatchEvent[]>([]);
  loading = signal(false);
  adding = signal(false);
  removingId = signal<number | null>(null);
  newDate: Date = new Date();
  today = new Date();

  get isEpisode(): boolean {
    return this.seasonNumber != null && this.episodeNumber != null;
  }

  ngOnChanges(changes: SimpleChanges) {
    if (changes['visible'] && this.visible) {
      this.newDate = new Date();
      this.loadHistory();
    }
  }

  close() {
    this.visible = false;
    this.visibleChange.emit(false);
  }

  private loadHistory() {
    this.loading.set(true);
    const request$ = this.isEpisode
      ? this.api.getEpisodeWatches(this.tmdbId, this.seasonNumber!, this.episodeNumber!)
      : this.api.getWatches(this.tmdbId, this.mediaType);

    request$.subscribe({
      next: events => { this.events.set(sortDesc(events)); this.loading.set(false); },
      error: err => { this.loading.set(false); this.messages.add({ severity: 'error', summary: 'Historique', detail: errorMessage(err), life: 4000 }); },
    });
  }

  addWatch() {
    if (this.adding()) return;
    this.adding.set(true);
    const watchedAt = (this.newDate ?? new Date()).toISOString();

    const request$ = this.isEpisode
      ? this.api.addEpisodeWatch(this.tmdbId, this.seasonNumber!, this.episodeNumber!, watchedAt)
      : this.api.addWatch(this.tmdbId, this.mediaType, {
          watchedAt,
          posterPath: this.posterPath,
          runtime: this.runtime,
          title: this.title,
          genres: this.genres,
        });

    request$.subscribe({
      next: event => {
        this.events.update(list => sortDesc([...list, event]));
        this.adding.set(false);
        this.emitCountChange();
      },
      error: err => {
        this.adding.set(false);
        this.messages.add({ severity: 'error', summary: 'Historique', detail: errorMessage(err), life: 4000 });
      },
    });
  }

  removeWatch(event: WatchEvent) {
    if (this.removingId() !== null) return;
    this.removingId.set(event.id);

    const request$ = this.isEpisode
      ? this.api.deleteEpisodeWatch(this.tmdbId, this.seasonNumber!, this.episodeNumber!, event.id)
      : this.api.deleteWatch(this.tmdbId, this.mediaType, event.id);

    request$.subscribe({
      next: () => {
        this.events.update(list => list.filter(e => e.id !== event.id));
        this.removingId.set(null);
        this.emitCountChange();
      },
      error: err => {
        this.removingId.set(null);
        this.messages.add({ severity: 'error', summary: 'Historique', detail: errorMessage(err), life: 4000 });
      },
    });
  }

  private emitCountChange() {
    const watchCount = this.events().length;
    this.watchCountChanged.emit({ watchCount, seen: watchCount > 0 });
  }
}

function sortDesc(events: WatchEvent[]): WatchEvent[] {
  return [...events].sort((a, b) => b.watchedAt.localeCompare(a.watchedAt));
}
