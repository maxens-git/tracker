import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ButtonModule } from 'primeng/button';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { DatePickerModule } from 'primeng/datepicker';
import { forkJoin, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { Api, TrackedMedia } from '../../../shared/services/api';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { TmdbMovie, TmdbShow, TmdbSeasonSummary } from '../../../shared/interfaces/media';
import { posterUrl } from '../../../shared/services/tmdb-image';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SelectButtonModule } from 'primeng/selectbutton';
import { TagModule } from 'primeng/tag';
import { MessageModule } from 'primeng/message';
import { CardModule } from 'primeng/card';

interface ReleaseCalendarItem {
  id: string;
  tmdbId: number;
  type: 'movie' | 'tv';
  kind: 'Film' | 'Saison' | 'Episode';
  title: string;
  subtitle: string;
  /** Vide pour un item « à confirmer » (saison/film annoncé sans date TMDB). */
  date: string;
  /** Vrai = annoncé mais sans date publiée : affiché hors calendrier, dans la section « à venir ». */
  pending?: boolean;
  posterPath?: string | null;
}

@Component({
  selector: 'app-release-calendar',
  standalone: true,
  imports: [ButtonModule, CommonModule, FormsModule, RouterLink, DatePickerModule, Spinner, SelectButtonModule, TagModule, MessageModule, CardModule],
  templateUrl: './release-calendar.html',
  styleUrl: './release-calendar.scss',
})
export class ReleaseCalendar implements OnInit {
  private api = inject(Api);
  private tmdb = inject(TmdbService);

  items = signal<ReleaseCalendarItem[]>([]);
  /** Saisons/films annoncés sans date confirmée sur TMDB (ex. série « terminée » avec une saison à venir). */
  pendingItems = signal<ReleaseCalendarItem[]>([]);
  tracked = signal<TrackedMedia[]>([]);
  loading = signal(true);
  error = signal(false);

  view = signal<'list' | 'calendar'>('list');
  readonly viewOptions = [
    { label: 'Liste', value: 'list' as const, icon: 'pi pi-list' },
    { label: 'Calendrier', value: 'calendar' as const, icon: 'pi pi-calendar' },
  ];
  /** Mois affiché + jour sélectionné dans le calendrier (lié au p-datepicker). */
  calendarDate: Date = new Date();
  selectedKey = signal<string>('');

  /** Index des sorties par jour (clé `yyyy-mm-dd`), pour marquer les cases et lister un jour. */
  private itemsByDay = computed(() => {
    const map = new Map<string, ReleaseCalendarItem[]>();
    for (const item of this.items()) {
      const day = map.get(item.date) ?? [];
      day.push(item);
      map.set(item.date, day);
    }
    return map;
  });

  selectedDayItems = computed(() => this.itemsByDay().get(this.selectedKey()) ?? []);

  ngOnInit() {
    this.load();
  }

  load() {
    this.loading.set(true);
    this.error.set(false);

    this.api.trackedMedia().pipe(
      switchMap(tracked => {
        this.tracked.set(tracked);
        if (tracked.length === 0) return of([] as ReleaseCalendarItem[]);
        return forkJoin(tracked.map(item => this.releaseItemsFor(item).pipe(catchError(() => of([])))));
      }),
      map(groups => groups.flat()),
    ).subscribe({
      next: all => {
        // Les items datés alimentent le calendrier/la liste ; ceux « à confirmer » leur section dédiée.
        const dated = all.filter(item => !item.pending).sort((a, b) => a.date.localeCompare(b.date));
        const pending = all.filter(item => item.pending);
        this.items.set(dated);
        this.pendingItems.set(pending);
        // Cale le calendrier sur la première sortie à venir pour qu'un jour soit déjà rempli.
        if (dated.length > 0) {
          this.selectedKey.set(dated[0].date);
          this.calendarDate = new Date(dated[0].date + 'T00:00:00');
        }
        this.loading.set(false);
      },
      error: () => { this.error.set(true); this.loading.set(false); },
    });
  }

  setView(view: 'list' | 'calendar') {
    this.view.set(view);
  }

  /** Vrai si la case de jour du calendrier porte au moins une sortie. */
  hasRelease(date: { year: number; month: number; day: number }): boolean {
    return this.itemsByDay().has(dayKey(date.year, date.month, date.day));
  }

  onDaySelect(date: Date) {
    this.selectedKey.set(dayKey(date.getFullYear(), date.getMonth(), date.getDate()));
  }

  selectedDayLabel(): string {
    return this.selectedKey() ? this.formatDate(this.selectedKey()) : '';
  }

  remove(item: ReleaseCalendarItem, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    this.api.removeTrackedMedia(item.tmdbId, item.type).subscribe({
      complete: () => this.load(),
    });
  }

  poster(path?: string | null): string | null {
    return posterUrl(path, 'w185');
  }

  formatDate(date: string): string {
    return new Date(date + 'T00:00:00').toLocaleDateString('fr-FR', {
      weekday: 'short',
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }

  private releaseItemsFor(item: TrackedMedia) {
    return item.mediaType === 'movie'
      ? this.tmdb.movie(item.tmdbId).pipe(map(movie => this.movieRelease(item, movie)))
      : this.tmdb.show(item.tmdbId).pipe(
          switchMap(show => this.showReleaseItems(item, show)),
        );
  }

  private movieRelease(tracked: TrackedMedia, movie: TmdbMovie): ReleaseCalendarItem[] {
    if (isFuture(movie.release_date)) {
      return [{
        id: `movie-${movie.id}-${movie.release_date}`,
        tmdbId: movie.id,
        type: 'movie',
        kind: 'Film',
        title: movie.title,
        subtitle: 'Sortie du film',
        date: movie.release_date,
        posterPath: movie.poster_path ?? tracked.posterPath,
      }];
    }
    // Film annoncé mais sans date publiée → section « à venir ».
    if (!movie.release_date) {
      return [{
        id: `movie-${movie.id}-pending`,
        tmdbId: movie.id,
        type: 'movie',
        kind: 'Film',
        title: movie.title,
        subtitle: 'Sortie à confirmer',
        date: '',
        pending: true,
        posterPath: movie.poster_path ?? tracked.posterPath,
      }];
    }
    return [];
  }

  private showReleaseItems(tracked: TrackedMedia, show: TmdbShow) {
    const datedSeasons = show.seasons
      .filter(season => season.season_number > 0 && isFuture(season.air_date))
      .map(season => this.seasonRelease(tracked, show, season));

    // Datées + annoncées-sans-date : ces dernières iront dans la section « à venir ».
    const undatedSeasons = this.undatedSeasons(tracked, show);
    const baseItems = [...datedSeasons, ...undatedSeasons];

    const seasonsToInspect = show.seasons
      .filter(season => shouldInspectSeason(season))
      .slice(-3);

    const episodes$ = seasonsToInspect.length === 0
      ? of([] as ReleaseCalendarItem[])
      : forkJoin(seasonsToInspect.map(season =>
          this.tmdb.season(show.id, season.season_number).pipe(
            map(detail => detail.episodes
              .filter(ep => isFuture(ep.air_date))
              .map((ep): ReleaseCalendarItem => ({
                id: `tv-${show.id}-s${ep.season_number}-e${ep.episode_number}-${ep.air_date}`,
                tmdbId: show.id,
                type: 'tv' as const,
                kind: 'Episode' as const,
                title: show.name,
                subtitle: `S${String(ep.season_number).padStart(2, '0')}E${String(ep.episode_number).padStart(2, '0')} - ${ep.name}`,
                date: ep.air_date!,
                posterPath: show.poster_path ?? tracked.posterPath,
              }))),
            catchError(() => of([] as ReleaseCalendarItem[])),
          )
        )).pipe(map(groups => groups.flat()));

    return episodes$.pipe(
      map(episodes => {
        const items = [...baseItems, ...episodes]
          .filter((item, index, all) => all.findIndex(other => other.id === item.id) === index);

        // Rien de concret à venir mais TMDB indique la série en production (cas typique :
        // saison confirmée mais pas encore créée comme entrée TMDB) → carte « en préparation ».
        if (datedSeasons.length === 0 && undatedSeasons.length === 0 && episodes.length === 0 && show.in_production) {
          items.push(this.inProductionPlaceholder(tracked, show));
        }
        return items;
      })
    );
  }

  /**
   * Saisons annoncées mais sans date TMDB, plus récentes que la dernière saison déjà
   * diffusée (cas typique : série marquée « terminée » dont une nouvelle saison arrive).
   */
  private undatedSeasons(tracked: TrackedMedia, show: TmdbShow): ReleaseCalendarItem[] {
    return show.seasons
      .filter(s => s.season_number > 0 && !s.air_date && s.season_number > lastAiredSeason(show))
      .map(s => ({
        id: `tv-${show.id}-season-${s.season_number}-pending`,
        tmdbId: show.id,
        type: 'tv' as const,
        kind: 'Saison' as const,
        title: show.name,
        subtitle: `${s.name} · date à confirmer`,
        date: '',
        pending: true,
        posterPath: s.poster_path ?? show.poster_path ?? tracked.posterPath,
      }));
  }

  /**
   * Carte « saison en préparation » quand TMDB signale la série en production mais n'a
   * pas encore créé d'entrée pour la prochaine saison (ex. The White Lotus S4 confirmée).
   */
  private inProductionPlaceholder(tracked: TrackedMedia, show: TmdbShow): ReleaseCalendarItem {
    const nextNumber = lastAiredSeason(show) + 1;
    return {
      id: `tv-${show.id}-inproduction`,
      tmdbId: show.id,
      type: 'tv',
      kind: 'Saison',
      title: show.name,
      subtitle: `Saison ${nextNumber} en préparation · date à confirmer`,
      date: '',
      pending: true,
      posterPath: show.poster_path ?? tracked.posterPath,
    };
  }

  private seasonRelease(tracked: TrackedMedia, show: TmdbShow, season: TmdbSeasonSummary): ReleaseCalendarItem {
    return {
      id: `tv-${show.id}-season-${season.season_number}-${season.air_date}`,
      tmdbId: show.id,
      type: 'tv',
      kind: 'Saison',
      title: show.name,
      subtitle: `${season.name} · ${season.episode_count ?? 0} épisode${(season.episode_count ?? 0) > 1 ? 's' : ''}`,
      date: season.air_date!,
      posterPath: season.poster_path ?? show.poster_path ?? tracked.posterPath,
    };
  }
}

/** Construit une clé `yyyy-mm-dd` à partir d'une année, d'un mois 0-based et d'un jour. */
function dayKey(year: number, month0: number, day: number): string {
  return `${year}-${String(month0 + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/** Numéro de la dernière saison déjà diffusée (date passée), ou 0 si aucune. */
function lastAiredSeason(show: TmdbShow): number {
  const aired = show.seasons
    .filter(s => s.season_number > 0 && s.air_date && !isFuture(s.air_date))
    .map(s => s.season_number);
  return aired.length ? Math.max(...aired) : 0;
}

function isFuture(date?: string | null): boolean {
  if (!date) return false;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return new Date(date + 'T00:00:00') >= today;
}

function shouldInspectSeason(season: TmdbSeasonSummary): boolean {
  if (season.season_number <= 0) return false;
  if (!season.air_date) return true;
  const date = new Date(season.air_date + 'T00:00:00');
  const min = new Date();
  min.setDate(min.getDate() - 90);
  min.setHours(0, 0, 0, 0);
  return date >= min;
}
