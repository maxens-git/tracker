import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Api, Settings, WebSettingsUpdate } from '../../../shared/services/api';
import { switchMap } from 'rxjs/operators';
import { MessageService } from 'primeng/api';
import { ButtonModule } from 'primeng/button';
import { InputTextModule } from 'primeng/inputtext';
import { ToggleSwitchModule } from 'primeng/toggleswitch';
import { CardModule } from 'primeng/card';
import { SelectButtonModule } from 'primeng/selectbutton';
import { CheckboxModule } from 'primeng/checkbox';
import { Spinner } from '../../../shared/components/spinner/spinner';
import { ThemeMode, ThemeService } from '../../../shared/services/theme';
import { SettingsState } from '../../../shared/services/settings-state';
import { buildInfo } from '../../../environments/build-info';
import { errorMessage } from '../../../shared/services/http-error';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [FormsModule, ButtonModule, InputTextModule, ToggleSwitchModule, Spinner, CardModule, SelectButtonModule, CheckboxModule],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
})
export class SettingsPage implements OnInit {
  private api = inject(Api);
  private messages = inject(MessageService);
  private settingsState = inject(SettingsState);
  readonly theme = inject(ThemeService);

  loading = signal(true);
  loadFailed = signal(false);
  saving = signal(false);
  testing = signal(false);
  saved = signal(false);
  testSent = signal(false);
  calendarSubscribeLoading = signal(false);
  calendarCopying = signal(false);
  calendarCopied = signal(false);
  exporting = signal(false);
  importing = signal(false);
  readonly iosLocalNotificationsEnabled = signal<boolean | null>(null);
  exportIncludeLogs = false;
  readonly themeOptions: { label: string; icon: string; value: ThemeMode }[] = [
    { label: 'Clair', icon: 'pi pi-sun', value: 'light' },
    { label: 'Sombre', icon: 'pi pi-moon', value: 'dark' },
    { label: 'Auto', icon: 'pi pi-desktop', value: 'system' },
  ];

  form: WebSettingsUpdate = {
    ntfyEnabled: false,
    ntfyUrl: '',
    ntfyTopic: '',
    ntfyToken: '',
    notifyDaysAhead: 1,
    notificationHour: 9,
    notificationMinute: 0,
    torrentsEnabled: true,
    prowlarrUrl: '',
    prowlarrApiKey: '',
    allDebridApiKey: '',
    tmdbApiKey: '',
    tmdbBaseUrl: '',
    tmdbLanguage: '',
  };

  ngOnInit() {
    this.loadSettings();
  }

  loadSettings() {
    this.loading.set(true);
    this.loadFailed.set(false);
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
          torrentsEnabled: settings.torrentsEnabled,
          prowlarrUrl: settings.prowlarrUrl ?? '',
          prowlarrApiKey: settings.prowlarrApiKey ?? '',
          allDebridApiKey: settings.allDebridApiKey ?? '',
          tmdbApiKey: settings.tmdbApiKey ?? '',
          tmdbBaseUrl: settings.tmdbBaseUrl ?? '',
          tmdbLanguage: settings.tmdbLanguage ?? '',
        };
        this.iosLocalNotificationsEnabled.set(settings.iosLocalNotificationsEnabled ?? null);
        this.settingsState.apply(settings);
        this.loading.set(false);
      },
      error: () => {
        this.loadFailed.set(true);
        this.loading.set(false);
        this.showError('Impossible de charger les réglages.');
      },
    });
  }

  save() {
    if (this.loading() || this.loadFailed() || this.saving() || this.testing() || this.importing()) return;
    this.saving.set(true);
    this.saved.set(false);

    this.api.updateSettings(this.normalizedSettings()).subscribe({
      next: settings => {
        this.applySavedSettings(settings);
        this.saving.set(false);
        this.saved.set(true);
        window.setTimeout(() => this.saved.set(false), 2200);
        this.showSuccess('Réglages enregistrés.');
      },
      error: err => {
        this.saving.set(false);
        this.showError(errorMessage(err, 'Impossible d’enregistrer les réglages.'));
      },
    });
  }

  sendTestNotification() {
    if (this.loading() || this.loadFailed() || this.testing() || this.saving() || this.importing()) return;
    this.testing.set(true);
    this.testSent.set(false);

    this.api.updateSettings(this.normalizedSettings()).pipe(
      switchMap(settings => {
        this.applySavedSettings(settings);
        return this.api.sendTestNotification();
      })
    ).subscribe({
      next: () => {
        this.testing.set(false);
        this.testSent.set(true);
        window.setTimeout(() => this.testSent.set(false), 2200);
        this.showSuccess('Notification de test envoyée.');
      },
      error: err => {
        this.testing.set(false);
        this.showError(errorMessage(err, 'Impossible d’envoyer la notification de test.'));
      },
    });
  }

  subscribeToCalendar() {
    if (this.calendarSubscribeLoading()) return;
    this.calendarSubscribeLoading.set(true);

    this.api.calendarInfo().subscribe({
      next: info => {
        window.location.href = info.webcalUrl;
        this.calendarSubscribeLoading.set(false);
      },
      error: () => {
        this.calendarSubscribeLoading.set(false);
        this.showError('Impossible de récupérer le lien du calendrier.');
      },
    });
  }

  copyCalendarLink() {
    if (this.calendarCopying()) return;
    this.calendarCopying.set(true);
    this.calendarCopied.set(false);

    this.api.calendarInfo().subscribe({
      next: async info => {
        try {
          if (!navigator.clipboard) throw new Error('Clipboard unavailable');
          await navigator.clipboard.writeText(info.httpsUrl);
          this.calendarCopied.set(true);
          window.setTimeout(() => this.calendarCopied.set(false), 2200);
          this.showSuccess('Lien du calendrier copié.');
        } catch {
          this.showError('Impossible de copier le lien du calendrier.');
        } finally {
          this.calendarCopying.set(false);
        }
      },
      error: () => {
        this.calendarCopying.set(false);
        this.showError('Impossible de récupérer le lien du calendrier.');
      },
    });
  }

  exportBackup() {
    if (this.exporting() || this.importing()) return;
    this.exporting.set(true);

    this.api.exportBackup(this.exportIncludeLogs).subscribe({
      next: response => {
        if (!response.body) {
          this.exporting.set(false);
          this.showError('Le serveur a renvoyé une sauvegarde vide.');
          return;
        }
        const disposition = response.headers.get('Content-Disposition') ?? '';
        const fileName = /filename="?([^";]+)"?/.exec(disposition)?.[1] ?? 'tracker-backup.json';
        const url = URL.createObjectURL(response.body);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        link.click();
        URL.revokeObjectURL(url);
        this.exporting.set(false);
        this.showSuccess('Sauvegarde téléchargée.');
      },
      error: () => {
        this.exporting.set(false);
        this.showError('Impossible d’exporter la base.');
      },
    });
  }

  importBackup(input: HTMLInputElement) {
    const file = input.files?.[0];
    input.value = '';
    if (!file || this.importing() || this.exporting() || this.saving() || this.testing()) return;

    if (file.size > 512 * 1024 * 1024) {
      this.showError('La sauvegarde ne doit pas dépasser 512 Mo.');
      return;
    }

    if (!confirm(`Remplacer toutes les données par le contenu de « ${file.name} » ? Les données actuelles seront définitivement perdues.`)) return;

    this.importing.set(true);
    this.api.importBackup(file).subscribe({
      next: result => {
        const media = result.counts['userMedia'] ?? 0;
        const lists = result.counts['mediaLists'] ?? 0;
        this.showSuccess(`Import terminé : ${media} médias, ${lists} listes. Rechargement…`);
        // Réglages, listes, états vus… tout a changé : on repart d'une page propre.
        window.setTimeout(() => window.location.reload(), 1500);
      },
      error: err => {
        this.importing.set(false);
        this.showError(errorMessage(err, 'Impossible d’importer la sauvegarde.'));
      },
    });
  }

  setTheme(mode: ThemeMode) {
    this.theme.setMode(mode);
  }

  get buildDate(): string {
    const date = new Date(buildInfo.timestamp);
    if (Number.isNaN(date.getTime()) || date.getFullYear() < 2000) {
      return 'Inconnue (build local)';
    }
    return date.toLocaleString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
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
      hour: Math.trunc(Math.max(0, Math.min(23, Number(this.form.notificationHour) || 0))),
      minute: Math.trunc(Math.max(0, Math.min(59, Number(this.form.notificationMinute) || 0))),
    };
  }

  private normalizedSettings(): WebSettingsUpdate {
    const time = this.notificationTimeParts();
    return {
      ...this.form,
      notifyDaysAhead: Math.trunc(Math.max(0, Math.min(30, Number(this.form.notifyDaysAhead) || 0))),
      notificationHour: time.hour,
      notificationMinute: time.minute,
    };
  }

  private applySavedSettings(settings: Settings) {
    this.form.notifyDaysAhead = settings.notifyDaysAhead;
    this.form.notificationHour = settings.notificationHour;
    this.form.notificationMinute = settings.notificationMinute;
    this.iosLocalNotificationsEnabled.set(settings.iosLocalNotificationsEnabled ?? null);
    this.settingsState.apply(settings);
  }

  private showSuccess(detail: string) {
    this.messages.add({ severity: 'success', summary: 'Réglages', detail, life: 3500 });
  }

  private showError(detail: string) {
    this.messages.add({ severity: 'error', summary: 'Réglages', detail, life: 5000 });
  }
}
