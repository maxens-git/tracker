import { Component, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { TabBar } from "./shared/components/tab-bar/tab-bar";

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, TabBar],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  protected readonly title = signal('tracker');
}
