import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ButtonModule } from 'primeng/button';
import { InputTextModule } from 'primeng/inputtext';
import { DatePickerModule } from 'primeng/datepicker';
import { MultiSelectModule } from 'primeng/multiselect';
import { DialogModule } from 'primeng/dialog';
import { Ripple } from 'primeng/ripple';
import { MessageService } from 'primeng/api';
import { finalize } from 'rxjs';
import {
  Api, Showtime, Theater, TheaterShowtimes, FavoriteTheater,
} from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { Autofocus } from '../../../shared/directives/autofocus';
import { errorMessage } from '../../../shared/services/http-error';

// Un code salle Allociné valide : une lettre suivie de 3 à 5 chiffres (ex. P0057).
const THEATER_CODE = /^[A-Z][0-9]{3,5}$/;

// Étiquettes compactes des formats Allociné (ex. DOLBY_CINEMA → « Dolby »).
const FORMAT_LABELS: Record<string, string> = {
  IMAX: 'IMAX',
  IMAX_3D: 'IMAX 3D',
  DOLBY_CINEMA: 'Dolby',
  DOLBY_ATMOS: 'Atmos',
  PLF: 'PLF',
  ICE: 'ICE',
  '4DX': '4DX',
  SCREENX: 'ScreenX',
  '3D': '3D',
};

/** Signature d'une séance indépendante de son id : deux séances de même horaire, version
 * et format sont considérées identiques (Allociné duplique parfois les entrées). */
function showSignature(s: Showtime): string {
  return `${s.iso}|${s.version ?? ''}|${[...s.formats].sort().join(',')}`;
}

/** Les séances d'un film dans une salle donnée. */
interface TheaterShows {
  theater: Theater;
  shows: Showtime[];
}

/** Un film agrégé sur toutes les salles consultées, avec ses séances par salle. */
interface MergedMovie {
  key: string;
  id: number | null;
  title: string;
  poster: string | null;
  runtime: string | null;
  genres: string[];
  url: string | null;
  byTheater: TheaterShows[];
  earliest: string; // ISO de la première séance, pour le tri
}

@Component({
  selector: 'app-showtimes',
  standalone: true,
  imports: [
    CommonModule, FormsModule, ButtonModule, InputTextModule, DatePickerModule,
    MultiSelectModule, DialogModule, Ripple, Spinner, Autofocus,
  ],
  templateUrl: './showtimes.html',
  styleUrl: './showtimes.scss',
})
export class Showtimes implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);

  // Jour consulté (lié au p-datepicker). Par défaut aujourd'hui.
  pickedDate: Date = new Date();

  // Aucune séance dans le passé : on borne la sélection à aujourd'hui (minuit).
  readonly today: Date = (() => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; })();

  // Cinémas enregistrés (liste plate) ; chacun coché ou non (état mémorisé côté serveur).
  favorites = signal<FavoriteTheater[]>([]);

  data = signal<TheaterShowtimes[]>([]);
  loading = signal(false);
  loaded = signal(false); // au moins une réponse reçue (distingue « vide » de « pas encore chargé »)

  // Codes des cinémas cochés : détermine les salles affichées.
  private activeCodes = computed(() =>
    new Set(this.favorites().filter(f => f.isActive).map(f => f.code)));

  // Ids des cinémas cochés (liés au multi-select).
  activeIds = computed(() => this.favorites().filter(f => f.isActive).map(f => f.id));

  // Options du multi-select : un cinéma enregistré par entrée (libellé = nom connu, sinon code).
  favoriteOptions = computed(() =>
    this.favorites().map(f => ({ label: this.codeLabel(f.code), value: f.id })));

  // Noms de salles connus (code → nom), alimentés par les programmes déjà chargés.
  // Signal pour que les libellés du multi-select se rafraîchissent après chargement.
  private theaterNames = signal(new Map<string, string>());

  // Films fusionnés sur toutes les salles chargées, triés par première séance.
  private allMovies = computed<MergedMovie[]>(() => this.merge(this.data()));

  // Films affichés : on ne garde que les salles cochées.
  mergedMovies = computed<MergedMovie[]>(() => {
    const active = this.activeCodes();
    return this.allMovies()
      .map(m => ({ ...m, byTheater: m.byTheater.filter(g => active.has(g.theater.code)) }))
      .filter(m => m.byTheater.length > 0);
  });

  // Nombre de cinémas cochés (pour le sous-titre).
  activeCount = computed(() => this.favorites().filter(f => f.isActive).length);

  // ── Ajout / gestion des cinémas (dialog) ─────────────────────────────────
  manageOpen = signal(false);
  adding = signal(false);
  codeInput = '';

  ngOnInit() {
    const date = this.route.snapshot.queryParamMap.get('date');
    const parsed = date ? new Date(date + 'T00:00:00') : null;
    if (parsed && !Number.isNaN(parsed.getTime())) this.pickedDate = parsed;

    this.api.favoriteTheaters().subscribe({
      next: favorites => { this.favorites.set(favorites); this.load(); },
      error: () => { this.loaded.set(true); },
    });
  }

  // ── Chargement des séances ─────────────────────────────────────────────────

  // On charge tous les cinémas enregistrés en une requête ; le filtrage coché/décoché
  // se fait à l'affichage, pour un basculement instantané sans rechargement.
  private codesToLoad(): string[] {
    return this.favorites().map(f => f.code);
  }

  load() {
    const codes = this.codesToLoad();
    if (this.loading()) return;
    if (codes.length === 0) { this.data.set([]); this.loaded.set(true); return; }

    const date = this.isoDate(this.pickedDate);
    this.loading.set(true);
    this.syncQueryParams(date);

    this.api.multiShowtimes(codes, date)
      .pipe(finalize(() => {
        this.loading.set(false);
        this.loaded.set(true);
      }))
      .subscribe({
        next: result => {
          const names = new Map(this.theaterNames());
          for (const prog of result)
            if (prog.theater.name) names.set(prog.theater.code, prog.theater.name);
          this.theaterNames.set(names);
          this.data.set(result);
        },
        error: err => {
          this.data.set([]);
          this.showError(errorMessage(err, 'Impossible de récupérer les séances.'));
        },
      });
  }

  shiftDay(delta: number) {
    const next = new Date(this.pickedDate);
    next.setDate(next.getDate() + delta);
    next.setHours(0, 0, 0, 0);
    if (next < this.today) return; // pas de jour antérieur à aujourd'hui
    this.pickedDate = next;
    this.load();
  }

  // Vrai quand on ne peut pas reculer (déjà sur aujourd'hui) : désactive le chevron « précédent ».
  atMinDay(): boolean {
    return this.isoDate(this.pickedDate) <= this.isoDate(this.today);
  }

  onDateChange() {
    this.load();
  }

  // ── Cinémas : cocher / décocher, ajouter, retirer ───────────────────────────

  /** Applique la sélection du multi-select : persiste chaque cinéma dont l'état a changé. */
  onActiveChange(ids: number[]) {
    const selected = new Set(ids);
    for (const fav of this.favorites()) {
      const shouldBeActive = selected.has(fav.id);
      if (shouldBeActive !== fav.isActive) this.setActive(fav, shouldBeActive);
    }
  }

  /** Coche / décoche un cinéma : affichage instantané, choix mémorisé côté serveur. */
  private setActive(fav: FavoriteTheater, active: boolean) {
    this.favorites.update(fs => fs.map(f => f.id === fav.id ? { ...f, isActive: active } : f));
    this.api.setFavoriteTheaterActive(fav.id, active).subscribe({
      error: err => {
        // Échec de persistance : on rétablit l'état précédent pour rester cohérent.
        this.favorites.update(fs => fs.map(f => f.id === fav.id ? { ...f, isActive: !active } : f));
        this.showError(errorMessage(err, 'Impossible d’enregistrer la sélection.'));
      },
    });
  }

  addFavorite() {
    const code = this.codeInput.trim().toUpperCase();
    if (!code || this.adding()) return;
    if (!THEATER_CODE.test(code)) {
      this.showError('Code cinéma invalide (ex. P0057).');
      return;
    }
    if (this.favorites().some(f => f.code === code)) {
      this.showError('Ce cinéma est déjà enregistré.');
      this.codeInput = '';
      return;
    }

    this.adding.set(true);
    this.api.addFavoriteTheater(code)
      .pipe(finalize(() => this.adding.set(false)))
      .subscribe({
        next: fav => {
          this.favorites.update(fs => fs.some(f => f.id === fav.id) ? fs : [...fs, fav]);
          this.codeInput = '';
          this.load(); // recharge pour inclure les séances du nouveau cinéma
        },
        error: err => this.showError(errorMessage(err)),
      });
  }

  removeFavorite(fav: FavoriteTheater) {
    this.api.removeFavoriteTheater(fav.id).subscribe({
      next: () => {
        this.favorites.update(fs => fs.filter(f => f.id !== fav.id));
        this.load();
      },
      error: err => this.showError(errorMessage(err)),
    });
  }

  openManage() {
    this.codeInput = '';
    this.manageOpen.set(true);
  }

  closeManage() {
    if (this.adding()) return;
    this.manageOpen.set(false);
  }

  // ── Fusion par film ────────────────────────────────────────────────────────

  private merge(programs: TheaterShowtimes[]): MergedMovie[] {
    const byKey = new Map<string, MergedMovie>();

    for (const prog of programs) {
      for (const movie of prog.movies) {
        if (movie.shows.length === 0) continue;
        const key = movie.id != null ? `m:${movie.id}` : `t:${movie.title}`;

        let merged = byKey.get(key);
        if (!merged) {
          merged = {
            key,
            id: movie.id,
            title: movie.title,
            poster: movie.poster,
            runtime: movie.runtime,
            genres: movie.genres,
            url: movie.url,
            byTheater: [],
            earliest: movie.shows[0].iso,
          };
          byKey.set(key, merged);
        } else if (!merged.poster && movie.poster) {
          merged.poster = movie.poster; // complète l'affiche si une salle l'a et pas l'autre
        }

        // Allociné peut renvoyer un même film en plusieurs entrées pour une salle
        // (versions/expériences), avec des séances identiques mais des ids différents :
        // on regroupe par salle et on déduplique par signature (horaire + version + format).
        let group = merged.byTheater.find(g => g.theater.code === prog.theater.code);
        if (!group) {
          group = { theater: prog.theater, shows: [] };
          merged.byTheater.push(group);
        }
        const seen = new Set(group.shows.map(showSignature));
        for (const s of movie.shows) if (seen.add(showSignature(s))) group.shows.push(s);
        group.shows.sort((a, b) => a.iso.localeCompare(b.iso));
        if (movie.shows[0].iso < merged.earliest) merged.earliest = movie.shows[0].iso;
      }
    }

    const movies = [...byKey.values()];
    for (const m of movies)
      m.byTheater.sort((a, b) => this.theaterLabel(a.theater).localeCompare(this.theaterLabel(b.theater)));
    movies.sort((a, b) => a.earliest.localeCompare(b.earliest));
    return movies;
  }

  // ── Libellés ────────────────────────────────────────────────────────────────

  theaterLabel(theater: Theater): string {
    return theater.name || theater.code;
  }

  /** Nom de salle connu pour un code (issu des programmes chargés), sinon le code lui-même. */
  codeLabel(code: string): string {
    return this.theaterNames().get(code) ?? code;
  }

  formatLabel(format: string): string {
    return FORMAT_LABELS[format] ?? format.replace(/_/g, ' ');
  }

  dayLabel(): string {
    return this.pickedDate.toLocaleDateString('fr-FR', {
      weekday: 'long', day: 'numeric', month: 'long',
    });
  }

  isToday(): boolean {
    return this.isoDate(this.pickedDate) === this.isoDate(new Date());
  }

  // Date sélectionnée au format YYYY-MM-DD (fuseau local).
  private isoDate(d: Date): string {
    return d.toLocaleDateString('en-CA');
  }

  // Reflète la date consultée dans l'URL sans empiler d'historique ni relancer le routeur
  // (une navigation recréerait le composant → boucle).
  private syncQueryParams(date: string) {
    const urlTree = this.router.createUrlTree([], { relativeTo: this.route, queryParams: { date } });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Séances', detail, life: 5000 });
  }
}
