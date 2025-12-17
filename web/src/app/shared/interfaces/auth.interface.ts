export interface LoginRequest {
  username: string;
  password: string;
}

export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  username: string;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface AuthUser {
  username: string;
  expiresAt: Date;
}
