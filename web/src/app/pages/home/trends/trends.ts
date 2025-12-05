import { Component, input } from '@angular/core';
import { TrendingHomeData } from '../../../shared/interfaces/tmdb-trending.interface'
import { Panel } from "primeng/panel";

@Component({
  selector: 'app-trends',
  imports: [
    Panel
  ],
  templateUrl: './trends.html',
  styleUrl: './trends.scss',
})
export class Trends {
  trends = input<TrendingHomeData | undefined>();
}
