import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap, catchError, of, BehaviorSubject } from 'rxjs';
import { AuthUser, LoginRequest, RefreshRequest, TokenResponse } from '../interfaces/auth.interface';

const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';
const USER_KEY = 'auth_user';

function hasValidTokenStatic(): boolean {
  const token = localStorage.getItem(ACCESS_TOKEN_KEY);
  const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);
  return !!(token && refreshToken);
}

function loadUserStatic(): AuthUser | null {
  const userJson = localStorage.getItem(USER_KEY);
  if (!userJson) return null;
  try {
    const user = JSON.parse(userJson);
    return {
      username: user.username,
      expiresAt: new Date(user.expiresAt)
    };
  } catch {
    return null;
  }
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);
  private apiUrl = '/api/auth';

  private _isAuthenticated = signal<boolean>(hasValidTokenStatic());
  private _currentUser = signal<AuthUser | null>(loadUserStatic());
  private _isLoading = signal<boolean>(false);

  isAuthenticated = this._isAuthenticated.asReadonly();
  currentUser = this._currentUser.asReadonly();
  isLoading = this._isLoading.asReadonly();

  private refreshTokenInProgress = false;
  private refreshTokenSubject = new BehaviorSubject<string | null>(null);

  constructor() {
  }

  login(credentials: LoginRequest): Observable<TokenResponse> {
    this._isLoading.set(true);
    return this.http.post<TokenResponse>(`${this.apiUrl}/login`, credentials).pipe(
      tap(response => {
        this.storeTokens(response);
        this._isAuthenticated.set(true);
        this._currentUser.set({
          username: response.username,
          expiresAt: new Date(response.expiresAt)
        });
        this._isLoading.set(false);
      }),
      catchError(error => {
        this._isLoading.set(false);
        throw error;
      })
    );
  }

  logout(): void {
    const refreshToken = this.getRefreshToken();
    if (refreshToken) {
      this.http.post(`${this.apiUrl}/logout`, { refreshToken } as RefreshRequest)
        .pipe(catchError(() => of(null)))
        .subscribe();
    }
    this.clearTokens();
    this._isAuthenticated.set(false);
    this._currentUser.set(null);
    this.router.navigate(['/login']);
  }

  logoutAll(): Observable<any> {
    return this.http.post(`${this.apiUrl}/logout-all`, {}).pipe(
      tap(() => {
        this.clearTokens();
        this._isAuthenticated.set(false);
        this._currentUser.set(null);
        this.router.navigate(['/login']);
      })
    );
  }

  refreshToken(): Observable<TokenResponse | null> {
    const refreshToken = this.getRefreshToken();
    if (!refreshToken) {
      this.logout();
      return of(null);
    }

    if (this.refreshTokenInProgress) {
      return new Observable(observer => {
        this.refreshTokenSubject.subscribe(token => {
          if (token) {
            observer.next({ accessToken: token } as TokenResponse);
            observer.complete();
          }
        });
      });
    }

    this.refreshTokenInProgress = true;
    this.refreshTokenSubject.next(null);

    return this.http.post<TokenResponse>(`${this.apiUrl}/refresh`, { refreshToken } as RefreshRequest).pipe(
      tap(response => {
        this.storeTokens(response);
        this._currentUser.set({
          username: response.username,
          expiresAt: new Date(response.expiresAt)
        });
        this.refreshTokenInProgress = false;
        this.refreshTokenSubject.next(response.accessToken);
      }),
      catchError(error => {
        this.refreshTokenInProgress = false;
        this.logout();
        return of(null);
      })
    );
  }

  getAccessToken(): string | null {
    return localStorage.getItem(ACCESS_TOKEN_KEY);
  }

  getRefreshToken(): string | null {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
  }

  isTokenExpired(): boolean {
    const user = this._currentUser();
    if (!user?.expiresAt) return true;
    return new Date(user.expiresAt).getTime() - 30000 < Date.now();
  }

  private storeTokens(response: TokenResponse): void {
    localStorage.setItem(ACCESS_TOKEN_KEY, response.accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, response.refreshToken);
    localStorage.setItem(USER_KEY, JSON.stringify({
      username: response.username,
      expiresAt: response.expiresAt
    }));
  }

  private clearTokens(): void {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  private validateToken(): void {
    this.http.get(`${this.apiUrl}/validate`).pipe(
      catchError(() => {
        return this.refreshToken();
      })
    ).subscribe();
  }
}
