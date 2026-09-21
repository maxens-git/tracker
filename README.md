# Tracker

Appli perso pour suivre les films et séries que je regarde (vu, envie de voir, listes, notifs de sortie...).

## Archi

- **Backend** : API ASP.NET Core (C#) + MySQL via EF Core. Sert aussi les fichiers statiques du client web, donc une seule appli à déployer.
- **Client web** (`clientweb/`) : Angular + PrimeNG.
- **Client iOS** (`clientios/`) : app SwiftUI. Elle appelle TMDB directement pour les métadonnées (affiches, titres...) et l'API pour l'état perso (vu / aimé / listes).
- **Base de données** : MySQL, tourne à part (pas dans le docker-compose).
- **Auth** : Authelia devant l'API en prod (reverse proxy).

## Intégrations externes

- TMDB / OMDb : métadonnées films/séries
- JustWatch : dispo streaming
- Allociné : séances ciné
- Prowlarr / AllDebrid : recherche/téléchargement
- ntfy : notifs de sortie

## Lancer en local

1. Copier `.env.example` en `.env` et remplir les valeurs (clé TMDB, connexion DB...)
2. `docker compose up` pour l'API
3. `cd clientweb && npm install && npm start` pour le front en dev

## Déploiement

`./deploy.sh` build et push l'image Docker (arm & x86)
