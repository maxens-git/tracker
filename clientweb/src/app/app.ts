import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ToastModule } from 'primeng/toast';
import { Nav } from '../shared/components/nav/nav';
import { ThemeService } from '../shared/services/theme';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, Nav, ToastModule],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  constructor(readonly theme: ThemeService) {}
}
