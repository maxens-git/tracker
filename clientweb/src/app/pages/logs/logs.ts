import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MessageService } from 'primeng/api';
import { ButtonModule } from 'primeng/button';
import { InputTextModule } from 'primeng/inputtext';
import { Ripple } from 'primeng/ripple';
import { Api, SystemLog } from '../../../shared/services/api';
import { Spinner } from '../../../shared/components/spinner/spinner';

type LevelFilter = 'all' | 'Information' | 'Warning' | 'Error' | 'Critical';

@Component({
  selector: 'app-logs',
  standalone: true,
  imports: [FormsModule, ButtonModule, InputTextModule, Ripple, Spinner],
  templateUrl: './logs.html',
  styleUrl: './logs.scss',
})
export class LogsPage implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);

  logs = signal<SystemLog[]>([]);
  page = signal(0);
  totalPages = signal(1);
  totalCount = signal(0);
  loading = signal(false);
  clearing = signal(false);
  error = signal(false);

  level: LevelFilter = 'all';
  search = '';

  readonly levels: { label: string; value: LevelFilter }[] = [
    { label: 'Tous', value: 'all' },
    { label: 'Info', value: 'Information' },
    { label: 'Warnings', value: 'Warning' },
    { label: 'Erreurs', value: 'Error' },
    { label: 'Critiques', value: 'Critical' },
  ];

  ngOnInit() {
    this.refresh();
  }

  get hasMore(): boolean {
    return this.page() < this.totalPages();
  }

  refresh() {
    this.logs.set([]);
    this.page.set(0);
    this.totalPages.set(1);
    this.totalCount.set(0);
    this.loadMore();
  }

  loadMore() {
    if (this.loading()) return;

    const next = this.page() + 1;
    this.loading.set(true);
    this.error.set(false);

    this.api.logs(next, this.level, this.search.trim()).subscribe({
      next: result => {
        this.logs.update(current => [...current, ...result.items]);
        this.page.set(result.page);
        this.totalPages.set(result.totalPages);
        this.totalCount.set(result.totalCount);
        this.loading.set(false);
      },
      error: () => {
        this.error.set(true);
        this.loading.set(false);
        this.messages.add({ severity: 'error', summary: 'Logs', detail: 'Impossible de charger les logs.', life: 5000 });
      },
    });
  }

  clear() {
    if (this.clearing()) return;

    this.clearing.set(true);
    this.api.clearLogs().subscribe({
      next: () => {
        this.clearing.set(false);
        this.messages.add({ severity: 'success', summary: 'Logs', detail: 'Logs vidés.', life: 3500 });
        this.refresh();
      },
      error: () => {
        this.clearing.set(false);
        this.messages.add({ severity: 'error', summary: 'Logs', detail: 'Impossible de vider les logs.', life: 5000 });
      },
    });
  }

  levelClass(level: string): string {
    return `level-${level.toLowerCase()}`;
  }

  formatDate(iso: string): string {
    const date = this.parseUtc(iso);
    return date.toLocaleString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  }

  private parseUtc(iso: string): Date {
    const hasZone = iso.endsWith('Z') || /[+-]\d\d:\d\d$/.test(iso);
    return new Date(hasZone ? iso : iso + 'Z');
  }
}
