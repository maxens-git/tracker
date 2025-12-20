export interface CastMember {
    id: number;
    name: string;
    character?: string;
    profilePath?: string;
    order: number;
    knownForDepartment?: string;
}

export interface CrewMember {
    id: number;
    name: string;
    job?: string;
    department?: string;
    profilePath?: string;
}

export interface CreditsResponse {
    tmdbId: number;
    cast: CastMember[];
    crew: CrewMember[];
}
