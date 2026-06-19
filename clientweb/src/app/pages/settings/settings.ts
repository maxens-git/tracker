import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Api, Settings } from '../../../shared/services/api';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
})
export class SettingsPage implements OnInit {
  private api = inject(Api);

  loading = signal(true);
  saving = signal(false);
  saved = signal(false);
  error = signal<string | null>(null);

  form: Omit<Settings, 'updatedAt'> = {
    ntfyEnabled: false,
    ntfyUrl: '',
    ntfyTopic: '',
    ntfyToken: '',
    notifyDaysAhead: 1,
    notificationHour: 9,
    notificationMinute: 0,
  };

  ngOnInit() {
    this.api.settings().subscribe({
      next: settings => {
        this.form = {
          ntfyEnabled: settings.ntfyEnabled,
          ntfyUrl: settings.ntfyUrl ?? '',
          ntfyTopic: settings.ntfyTopic ?? '',
          ntfyToken: settings.ntfyToken ?? '',
          notifyDaysAhead: settings.notifyDaysAhead,
          notificationHour: settings.notificationHour,
          notificationMinute: settings.notificationMinute,
        };
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossible de charger les réglages.');
        this.loading.set(false);
      },
    });
  }

  save() {
    if (this.saving()) return;
    this.saving.set(true);
    this.saved.set(false);
    this.error.set(null);

    const time = this.notificationTimeParts();
    this.api.updateSettings({
      ...this.form,
      notifyDaysAhead: Number(this.form.notifyDaysAhead) || 0,
      notificationHour: time.hour,
      notificationMinute: time.minute,
    }).subscribe({
      next: settings => {
        this.form.notifyDaysAhead = settings.notifyDaysAhead;
        this.form.notificationHour = settings.notificationHour;
        this.form.notificationMinute = settings.notificationMinute;
        this.saving.set(false);
        this.saved.set(true);
      },
      error: () => {
        this.error.set('Impossible d’enregistrer les réglages.');
        this.saving.set(false);
      },
    });
  }

  get notificationTime(): string {
    return `${String(this.form.notificationHour).padStart(2, '0')}:${String(this.form.notificationMinute).padStart(2, '0')}`;
  }

  set notificationTime(value: string) {
    const [hour, minute] = value.split(':').map(Number);
    this.form.notificationHour = Number.isFinite(hour) ? hour : 9;
    this.form.notificationMinute = Number.isFinite(minute) ? minute : 0;
  }

  private notificationTimeParts(): { hour: number; minute: number } {
    return {
      hour: Math.max(0, Math.min(23, Number(this.form.notificationHour) || 0)),
      minute: Math.max(0, Math.min(59, Number(this.form.notificationMinute) || 0)),
    };
  }
}
