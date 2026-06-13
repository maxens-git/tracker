import { Component, inject, signal, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { Api } from '../../../shared/services/api';
import { MediaListSummary } from '../../../shared/interfaces/list';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { SLUG_BY_SYSTEM_LIST } from '../../../shared/constants';

@Component({
  selector: 'app-lists',
  standalone: true,
  imports: [RouterLink, FormsModule, Spinner],
  templateUrl: './lists.html',
  styleUrl: './lists.scss',
})
export class Lists implements OnInit {
  private api = inject(Api);

  lists = signal<MediaListSummary[]>([]);
  loading = signal(true);
  error = signal(false);

  // ── Éditeur (création / modification) ──────────────────────────────────────
  editorOpen = signal(false);
  /** Liste en cours d'édition ; null = création. */
  editing = signal<MediaListSummary | null>(null);
  saving = signal(false);
  formName = '';
  formIcon = '';
  formDescription = '';

  ngOnInit() {
    this.reload();
  }

  private reload() {
    this.loading.set(true);
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

  // ── Actions ────────────────────────────────────────────────────────────────

  openCreate() {
    this.editing.set(null);
    this.formName = '';
    this.formIcon = '';
    this.formDescription = '';
    this.editorOpen.set(true);
  }

  openEdit(list: MediaListSummary, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    this.editing.set(list);
    this.formName = list.name;
    this.formIcon = list.icon ?? '';
    this.formDescription = list.description ?? '';
    this.editorOpen.set(true);
  }

  closeEditor() {
    if (this.saving()) return;
    this.editorOpen.set(false);
  }

  save() {
    const name = this.formName.trim();
    if (!name || this.saving()) return;

    const dto = { name, icon: this.formIcon.trim(), description: this.formDescription.trim() };
    this.saving.set(true);

    const list = this.editing();
    const request$ = list
      ? this.api.updateList(list.id, dto)
      : this.api.createList(dto);

    request$.subscribe({
      next: () => { this.saving.set(false); this.editorOpen.set(false); this.reload(); },
      error: () => { this.saving.set(false); },
    });
  }

  remove(list: MediaListSummary, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    if (!confirm(`Supprimer la liste « ${list.name} » ? Cette action est irréversible.`)) return;

    this.api.deleteList(list.id).subscribe({
      next: () => this.lists.update(ls => ls.filter(l => l.id !== list.id)),
    });
  }
}
