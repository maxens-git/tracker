import { Component, OnInit, inject, signal } from '@angular/core';
import { Ripple } from 'primeng/ripple';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { forkJoin, of, switchMap } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { TmdbService } from '../../../shared/services/tmdb.service';
import { Api, withUserStates } from '../../../shared/services/api';
import { MediaItem } from '../../../shared/interfaces/media';
import { TmdbPerson, TmdbPersonCredit } from '../../../shared/interfaces/person';
import { PosterCard } from '../../../shared/components/poster-card/poster-card';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { profileUrl } from '../../../shared/services/tmdb-image';

@Component({
  selector: 'app-person',
  standalone: true,
  imports: [Ripple, CommonModule, PosterCard, Spinner],
  templateUrl: './person.html',
  styleUrl: './person.scss',
})
export class Person implements OnInit {
  private route = inject(ActivatedRoute);
  private tmdb = inject(TmdbService);
  private api = inject(Api);
  private location = inject(Location);

  loading = signal(true);
  error = signal<string | null>(null);
  person = signal<TmdbPerson | null>(null);
  filmography = signal<MediaItem[]>([]);

  ngOnInit() {
    this.route.paramMap.pipe(
      switchMap(p => {
        const id = Number(p.get('id'));
        this.loading.set(true);
        this.error.set(null);
        this.person.set(null);
        this.filmography.set([]);

        return forkJoin({
          person: this.tmdb.person(id),
          credits: this.tmdb.personCombinedCredits(id).pipe(catchError(() => of(null))),
        }).pipe(
          switchMap(({ person, credits }) => {
            this.person.set(person);
            const items = this.buildFilmography(credits?.cast ?? []);
            return this.api.statesByTmdbId(items).pipe(
              map(states => withUserStates(items, states))
            );
          }),
          catchError(() => {
            this.error.set('Impossible de charger cette personne');
            return of([] as MediaItem[]);
          }),
        );
      }),
    ).subscribe({
      next: items => {
        this.filmography.set(items);
        this.loading.set(false);
        window.scrollTo({ top: 0 });
      },
      error: () => {
        this.error.set('Impossible de charger cette personne');
        this.loading.set(false);
      },
    });
  }

  goBack() { this.location.back(); }

  profile(path: string | null): string | null { return profileUrl(path, 'w342'); }

  get age(): number | null {
    const p = this.person();
    if (!p?.birthday) return null;
    const end = p.deathday ? new Date(p.deathday) : new Date();
    const birth = new Date(p.birthday);
    let age = end.getFullYear() - birth.getFullYear();
    const m = end.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && end.getDate() < birth.getDate())) age--;
    return age;
  }

  /** Films + séries d'un acteur : dédoublonnés, avec affiche, triés du plus récent au plus ancien. */
  private buildFilmography(cast: TmdbPersonCredit[]): MediaItem[] {
    const byKey = new Map<string, MediaItem>();
    for (const c of cast) {
      if (c.media_type !== 'movie' && c.media_type !== 'tv') continue;
      if (!c.poster_path) continue;
      const key = `${c.media_type}-${c.id}`;
      if (byKey.has(key)) continue;
      byKey.set(key, {
        id: c.id,
        media_type: c.media_type,
        title: c.title,
        name: c.name,
        poster_path: c.poster_path,
        backdrop_path: c.backdrop_path,
        release_date: c.release_date,
        first_air_date: c.first_air_date,
        vote_average: c.vote_average ?? 0,
        vote_count: c.vote_count ?? 0,
        popularity: c.popularity ?? 0,
        seen: false,
      });
    }
    return [...byKey.values()].sort((a, b) => {
      const da = a.release_date || a.first_air_date || '';
      const db = b.release_date || b.first_air_date || '';
      return db.localeCompare(da);
    });
  }
}
