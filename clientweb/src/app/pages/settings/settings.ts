import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Api, Settings } from '../../../shared/services/api';
import { switchMap } from 'rxjs/operators';
import { MessageService } from 'primeng/api';
import { ButtonModule } from 'primeng/button';
import { InputTextModule } from 'primeng/inputtext';
import { ToggleSwitchModule } from 'primeng/toggleswitch';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [FormsModule, ButtonModule, InputTextModule, ToggleSwitchModule],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
})
export class SettingsPage implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);

  loading = signal(true);
  saving = signal(false);
  testing = signal(false);

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
        this.loading.set(false);
        this.showError('Impossible de charger les réglages.');
      },
    });
  }

  save() {
    if (this.saving()) return;
    this.saving.set(true);

    this.api.updateSettings(this.normalizedSettings()).subscribe({
      next: settings => {
        this.applySavedSettings(settings);
        this.saving.set(false);
        this.showSuccess('Réglages enregistrés.');
      },
      error: () => {
        this.saving.set(false);
        this.showError('Impossible d’enregistrer les réglages.');
      },
    });
  }

  sendTestNotification() {
    if (this.testing() || this.saving()) return;
    this.testing.set(true);

    this.api.updateSettings(this.normalizedSettings()).pipe(
      switchMap(settings => {
        this.applySavedSettings(settings);
        return this.api.sendTestNotification();
      })
    ).subscribe({
      next: () => {
        this.testing.set(false);
        this.showSuccess('Notification de test envoyée.');
      },
      error: () => {
        this.testing.set(false);
        this.showError('Impossible d’envoyer la notification de test.');
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

  private normalizedSettings(): Omit<Settings, 'updatedAt'> {
    const time = this.notificationTimeParts();
    return {
      ...this.form,
      notifyDaysAhead: Number(this.form.notifyDaysAhead) || 0,
      notificationHour: time.hour,
      notificationMinute: time.minute,
    };
  }

  private applySavedSettings(settings: Settings) {
    this.form.notifyDaysAhead = settings.notifyDaysAhead;
    this.form.notificationHour = settings.notificationHour;
    this.form.notificationMinute = settings.notificationMinute;
  }

  private showSuccess(detail: string) {
    this.messages.add({ severity: 'success', summary: 'Réglages', detail, life: 3500 });
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Réglages', detail, life: 5000 });
  }
}
