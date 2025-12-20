export interface Trailer {
    id: string;
    name: string;
    key: string;
    site: string;
    type: string;
    official: boolean;
    language: string | null;
    publishedAt: string | null;
}

export interface TrailersResponse {
    tmdbId: number;
    trailers: Trailer[];
}
