import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { environment } from '../../environments/environment';
import { TmdbService, setTmdbConfig } from './tmdb.service';

describe('TMDB runtime settings', () => {
  let service: TmdbService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(TmdbService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    setTmdbConfig({ apiKey: null, baseUrl: null, language: null });
  });

  it('normalizes a configured base URL and restores defaults when settings are cleared', () => {
    setTmdbConfig({ apiKey: ' configured-key ', baseUrl: ' https://tmdb.example/3/// ', language: ' en-US ' });
    service.movie(42).subscribe();
    let request = http.expectOne(req => req.url === 'https://tmdb.example/3/movie/42');
    expect(request.request.params.get('api_key')).toBe('configured-key');
    request.flush({});

    setTmdbConfig({ apiKey: '', baseUrl: null, language: ' ' });
    service.movie(42).subscribe();
    request = http.expectOne(req => req.url === `${environment.tmdbBaseUrl}/movie/42`);
    expect(request.request.params.get('api_key')).toBe(environment.tmdbApiKey);
    expect(request.request.params.get('language')).toBe(environment.tmdbLang);
    request.flush({});
  });
});
