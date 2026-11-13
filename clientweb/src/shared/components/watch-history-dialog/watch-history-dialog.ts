import { Component, EventEmitter, Input, OnChanges, Output, SimpleChanges, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { HttpErrorResponse } from '@angular/common/http';
import { Observable, Subject, takeUntil } from 'rxjs';
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
  private destroyRef = inject(DestroyRef);
  private sessionChanged = new Subject<void>();
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
  historyError = signal<string | null>(null);
  newDate: Date | null = new Date();
  today = new Date();

  get isEpisode(): boolean {
    return this.seasonNumber != null && this.episodeNumber != null;
  }

  ngOnChanges(changes: SimpleChanges) {
    if (['visible', 'tmdbId', 'mediaType', 'seasonNumber', 'episodeNumber'].some(key => changes[key])) {
      this.sessionChanged.next();
      this.adding.set(false);
      this.removingId.set(null);
      this.events.set([]);
      if (this.visible) {
        this.today = new Date();
        this.newDate = new Date();
        this.loadHistory();
      }
    }
  }

  close() {
    this.sessionChanged.next();
    this.visible = false;
    this.visibleChange.emit(false);
  }

  private currentRequest<T>(request: Observable<T>): Observable<T> {
    return request.pipe(takeUntil(this.sessionChanged), takeUntilDestroyed(this.destroyRef));
  }

  loadHistory() {
    this.loading.set(true);
    this.historyError.set(null);
    const request$ = this.isEpisode
      ? this.api.getEpisodeWatches(this.tmdbId, this.seasonNumber!, this.episodeNumber!)
      : this.api.getWatches(this.tmdbId, this.mediaType);

    this.currentRequest(request$).subscribe({
      next: events => {
        this.events.set(sortDesc(events));
        this.loading.set(false);
        this.emitCountChange();
      },
      error: err => {
        this.loading.set(false);
        this.historyError.set(errorMessage(err));
      },
    });
  }

  get mutationPending(): boolean {
    return this.adding() || this.removingId() !== null;
  }

  addWatch() {
    if (this.loading() || this.historyError() || this.mutationPending) return;
    if (!(this.newDate instanceof Date) || !Number.isFinite(this.newDate.getTime())
        || this.newDate.getUTCFullYear() < 1000 || this.newDate.getUTCFullYear() > 9999) {
      this.messages.add({ severity: 'error', summary: 'Historique', detail: 'Choisissez une date valide.', life: 4000 });
      return;
    }
    const watchedAt = this.newDate.toISOString();
    this.adding.set(true);

    const request$ = this.isEpisode
      ? this.api.addEpisodeWatch(this.tmdbId, this.seasonNumber!, this.episodeNumber!, watchedAt)
      : this.api.addWatch(this.tmdbId, this.mediaType, {
          watchedAt, posterPath: this.posterPath, runtime: this.runtime,
          title: this.title, genres: this.genres,
        });

    this.currentRequest(request$).subscribe({
      next: event => {
        this.events.update(list => sortDesc([...list, event]));
        this.adding.set(false);
        this.newDate = new Date();
        this.emitCountChange();
        this.loadHistory();
      },
      error: err => { this.adding.set(false); this.handleMutationError(err); },
    });
  }

  removeWatch(event: WatchEvent) {
    if (this.loading() || this.historyError() || this.mutationPending) return;
    this.removingId.set(event.id);

    const request$ = this.isEpisode
      ? this.api.deleteEpisodeWatch(this.tmdbId, this.seasonNumber!, this.episodeNumber!, event.id)
      : this.api.deleteWatch(this.tmdbId, this.mediaType, event.id);

    this.currentRequest(request$).subscribe({
      next: () => {
        this.events.update(list => list.filter(e => e.id !== event.id));
        this.removingId.set(null);
        this.emitCountChange();
        this.loadHistory();
      },
      error: err => { this.removingId.set(null); this.handleMutationError(err); },
    });
  }

  private handleMutationError(err: unknown) {
    this.messages.add({ severity: 'error', summary: 'Historique', detail: errorMessage(err), life: 4000 });
    if (err instanceof HttpErrorResponse && (err.status === 409 || err.status === 404))
      this.loadHistory();
  }

  private emitCountChange() {
    const watchCount = this.events().length;
    this.watchCountChanged.emit({ watchCount, seen: watchCount > 0 });
  }
}

function sortDesc(events: WatchEvent[]): WatchEvent[] {
  return [...events].sort((a, b) => b.watchedAt.localeCompare(a.watchedAt));
}
