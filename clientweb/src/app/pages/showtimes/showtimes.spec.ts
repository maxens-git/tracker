import { TestBed } from '@angular/core/testing';
import { Location } from '@angular/common';
import { ActivatedRoute, Router, convertToParamMap } from '@angular/router';
import { MessageService } from 'primeng/api';
import { of, Subject } from 'rxjs';
import { Api, Showtime, TheaterShowtimes } from '../../../shared/services/api';
import { Showtimes } from './showtimes';

describe('Showtimes API consistency', () => {
  let page: Showtimes;
  let api: { multiShowtimes: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    api = { multiShowtimes: vi.fn(() => of<TheaterShowtimes[]>([])) };
    TestBed.configureTestingModule({ providers: [
      { provide: Api, useValue: api }, { provide: MessageService, useValue: { add: vi.fn() } },
      { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap({}) } } },
      { provide: Router, useValue: { createUrlTree: vi.fn(), serializeUrl: () => '/showtimes' } },
      { provide: Location, useValue: { replaceState: vi.fn() } },
    ] });
    page = TestBed.runInInjectionContext(() => new Showtimes());
    page.favorites.set([{ id: 1, code: 'P0057', position: 0, isActive: true }]);
  });

  it('deduplicates showtimes even when the source gives the same slot different IDs', () => {
    const first = showtime('a', '18:00');
    const earlier = showtime('b', '12:00');
    const program = schedule([first, earlier]);
    program.movies.push({ ...program.movies[0], shows: [{ ...first, id: 'duplicate' }] });
    page.data.set([program]);

    expect(page.mergedMovies()[0].byTheater[0].shows.map(show => show.id)).toEqual(['b', 'a']);
    expect(page.mergedMovies()[0].earliest).toBe(earlier.iso);
  });

  it('cancels an old date request before loading the selected date', () => {
    const old = new Subject<TheaterShowtimes[]>();
    const current = new Subject<TheaterShowtimes[]>();
    api.multiShowtimes.mockReturnValueOnce(old).mockReturnValueOnce(current);
    page.pickedDate = new Date(2026, 10, 13);
    page.load();
    page.pickedDate = new Date(2026, 10, 14);
    page.load();
    old.next([schedule([showtime('old', '12:00')])]);
    expect(page.data()).toEqual([]);
    expect(page.loading()).toBe(true);
    current.next([schedule([showtime('current', '12:00')])]);
    current.complete();
    expect(page.data()[0].movies[0].shows[0].id).toBe('current');
    expect(api.multiShowtimes).toHaveBeenLastCalledWith(['P0057'], '2026-11-14');
    expect(page.loading()).toBe(false);
  });

  it('restores today when the date input is cleared', () => {
    page.pickedDate = null as unknown as Date;
    expect(() => page.onDateChange()).not.toThrow();
    expect(page.pickedDate).toEqual(page.today);
    expect(api.multiShowtimes).toHaveBeenCalledOnce();
  });
});

function showtime(id: string, time: string): Showtime {
  return { id, iso: `2026-11-13T${time}:00+01:00`, date: '2026-11-13', time,
    version: 'VF', formats: [], isPreview: false, ticketingUrl: null };
}

function schedule(shows: Showtime[]): TheaterShowtimes {
  return {
    theater: { code: 'P0057', name: 'Cinéma', address: null, postalCode: null, city: null, image: null },
    date: '2026-11-13', nextDate: null,
    movies: [{ id: 42, title: 'Film', poster: null, runtime: null, genres: [], url: null, shows }],
  };
}
