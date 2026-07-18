import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ButtonModule } from 'primeng/button';
import { InputTextModule } from 'primeng/inputtext';
import { DatePickerModule } from 'primeng/datepicker';
import { SelectModule } from 'primeng/select';
import { DialogModule } from 'primeng/dialog';
import { Ripple } from 'primeng/ripple';
import { MessageService } from 'primeng/api';
import { finalize } from 'rxjs';
import {
  Api, Showtime, Theater, TheaterShowtimes, TheaterList,
} from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { Autofocus } from '../../../shared/directives/autofocus';
import { errorMessage } from '../../../shared/services/http-error';

// Cinéma affiché par défaut en mode « cinéma unique » (Pathé Toulouse Wilson).
const DEFAULT_THEATER = 'P0057';

// Valeur du sélecteur pour le mode ad hoc (un seul cinéma saisi à la main).
const ADHOC = -1;

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
    SelectModule, DialogModule, Ripple, Spinner, Autofocus,
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

  // Listes de cinémas sauvegardées + sélection courante (ADHOC = cinéma unique saisi à la main).
  lists = signal<TheaterList[]>([]);
  selectedId = signal<number>(ADHOC);
  adhocTheater = DEFAULT_THEATER;

  data = signal<TheaterShowtimes[]>([]);
  loading = signal(false);
  loaded = signal(false); // au moins une réponse reçue (distingue « vide » de « pas encore chargé »)

  // Options du sélecteur : listes sauvegardées puis l'entrée « cinéma unique ».
  selectOptions = computed(() => [
    ...this.lists().map(l => ({ label: l.isDefault ? `★ ${l.name}` : l.name, value: l.id })),
    { label: 'Cinéma unique…', value: ADHOC },
  ]);

  // Liste actuellement sélectionnée (null en mode ad hoc).
  selectedList = computed(() => this.lists().find(l => l.id === this.selectedId()) ?? null);
  isAdhoc = computed(() => this.selectedId() === ADHOC);

  // Noms de salles connus (code → nom), alimentés par les programmes déjà chargés.
  private theaterNames = new Map<string, string>();

  // Films fusionnés sur toutes les salles, triés par première séance.
  mergedMovies = computed<MergedMovie[]>(() => this.merge(this.data()));

  // Nombre de salles ayant renvoyé un programme (pour le sous-titre).
  theaterCount = computed(() => this.data().length);

  // ── Éditeur de liste (dialog) ────────────────────────────────────────────
  editorOpen = signal(false);
  editing = signal<TheaterList | null>(null); // null = création
  saving = signal(false);
  formName = '';
  editorCodes = signal<string[]>([]);
  codeInput = '';

  ngOnInit() {
    const params = this.route.snapshot.queryParamMap;

    const date = params.get('date');
    const parsed = date ? new Date(date + 'T00:00:00') : null;
    if (parsed && !Number.isNaN(parsed.getTime())) this.pickedDate = parsed;

    // Un lien direct vers un cinéma force le mode ad hoc.
    const theater = params.get('theater');
    if (theater) this.adhocTheater = theater;
    const listParam = Number(params.get('list'));

    this.api.theaterLists().subscribe({
      next: lists => {
        this.lists.set(lists);
        if (theater) {
          this.selectedId.set(ADHOC);
        } else if (listParam && lists.some(l => l.id === listParam)) {
          this.selectedId.set(listParam);
        } else {
          const def = lists.find(l => l.isDefault);
          this.selectedId.set(def ? def.id : ADHOC);
        }
        this.load();
      },
      error: () => this.load(), // pas de listes chargées → mode ad hoc par défaut
    });
  }

  // ── Chargement des séances ─────────────────────────────────────────────────

  private activeCodes(): string[] {
    const list = this.selectedList();
    if (list) return list.items.map(i => i.code);
    const code = this.adhocTheater.trim().toUpperCase();
    return code ? [code] : [];
  }

  load() {
    const codes = this.activeCodes();
    if (codes.length === 0 || this.loading()) return;

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
          for (const prog of result)
            if (prog.theater.name) this.theaterNames.set(prog.theater.code, prog.theater.name);
          this.data.set(result);
        },
        error: err => {
          this.data.set([]);
          this.showError(errorMessage(err, 'Impossible de récupérer les séances.'));
        },
      });
  }

  onListChange() {
    this.data.set([]);
    this.loaded.set(false);
    this.load();
  }

  onAdhocSubmit() {
    if (this.isAdhoc()) this.load();
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
    return this.theaterNames.get(code) ?? code;
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

  // Reflète la sélection (liste ou cinéma) + date dans l'URL sans empiler d'historique
  // ni relancer le routeur (une navigation recréerait le composant → boucle).
  private syncQueryParams(date: string) {
    const list = this.selectedList();
    const queryParams = list ? { list: list.id, date } : { theater: this.adhocTheater.trim(), date };
    const urlTree = this.router.createUrlTree([], { relativeTo: this.route, queryParams });
    this.location.replaceState(this.router.serializeUrl(urlTree));
  }

  // ── Éditeur de liste ─────────────────────────────────────────────────────

  openCreate() {
    this.editing.set(null);
    this.formName = '';
    this.editorCodes.set([]);
    this.codeInput = '';
    this.editorOpen.set(true);
  }

  openEdit() {
    const list = this.selectedList();
    if (!list) return;
    this.editing.set(list);
    this.formName = list.name;
    this.editorCodes.set(list.items.map(i => i.code));
    this.codeInput = '';
    this.editorOpen.set(true);
  }

  closeEditor() {
    if (this.saving()) return;
    this.editorOpen.set(false);
  }

  addCode() {
    const code = this.codeInput.trim().toUpperCase();
    if (!code) return;
    if (!THEATER_CODE.test(code)) {
      this.showError('Code cinéma invalide (ex. P0057).');
      return;
    }
    if (!this.editorCodes().includes(code))
      this.editorCodes.update(cs => [...cs, code]);
    this.codeInput = '';
  }

  removeCode(code: string) {
    this.editorCodes.update(cs => cs.filter(c => c !== code));
  }

  save() {
    const name = this.formName.trim();
    const codes = this.editorCodes();
    if (!name || codes.length === 0 || this.saving()) return;

    this.saving.set(true);
    const editing = this.editing();
    const request$ = editing
      ? this.api.updateTheaterList(editing.id, name, codes)
      : this.api.createTheaterList(name, codes);

    request$.subscribe({
      next: saved => {
        this.saving.set(false);
        this.editorOpen.set(false);
        this.reloadLists(saved.id);
      },
      error: err => {
        this.saving.set(false);
        this.showError(errorMessage(err));
      },
    });
  }

  remove() {
    const list = this.selectedList();
    if (!list) return;
    if (!confirm(`Supprimer la liste « ${list.name} » ?`)) return;

    this.api.deleteTheaterList(list.id).subscribe({
      next: () => {
        this.selectedId.set(ADHOC);
        this.reloadLists(ADHOC);
      },
      error: err => this.showError(errorMessage(err)),
    });
  }

  setDefault() {
    const list = this.selectedList();
    if (!list || list.isDefault) return;

    this.api.setDefaultTheaterList(list.id).subscribe({
      next: () => {
        this.showInfo(`« ${list.name} » définie par défaut.`);
        this.reloadLists(list.id);
      },
      error: err => this.showError(errorMessage(err)),
    });
  }

  // Recharge les listes puis sélectionne la liste voulue et recharge les séances.
  private reloadLists(selectId: number) {
    this.api.theaterLists().subscribe({
      next: lists => {
        this.lists.set(lists);
        this.selectedId.set(lists.some(l => l.id === selectId) ? selectId : ADHOC);
        this.onListChange();
      },
      error: () => this.onListChange(),
    });
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Séances', detail, life: 5000 });
  }

  private showInfo(detail: string) {
    this.messages.add({ severity: 'success', summary: 'Séances', detail, life: 3000 });
  }
}
