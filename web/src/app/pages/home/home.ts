import { Component, OnInit, signal } from '@angular/core';
import { PanelModule } from 'primeng/panel';
import { InputTextModule } from 'primeng/inputtext';
import { FormsModule } from '@angular/forms';
import { Trends } from "./trends/trends";
import { TrendingHomeData, TMDbSearchResult } from '../../shared/interfaces/tmdb-trending.interface'
import { TrendsService } from '../../shared/services/trends.service';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-home',
  templateUrl: './home.html',
  styleUrls: ['./home.scss'],
  standalone: true,
  imports: [
    PanelModule,
    InputTextModule,
    FormsModule,
    Trends,
    CommonModule
]
})
export class Home implements OnInit {
  protected searchValue: string = "";
  protected trends = signal<TrendingHomeData | undefined>(undefined);

  constructor(private trendsService: TrendsService) {}

  ngOnInit(): void {
    this.trendsService.getHomeData().subscribe({
      next: (data: TrendingHomeData) => {
        this.trends.set(data);
      },
      error: (err) => {
        console.log(err);
      }
    });
  }
}
