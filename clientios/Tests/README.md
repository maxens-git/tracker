# Régressions iOS

Depuis la racine du dépôt, avec Xcode et ses outils Swift installés :

    python3 clientios/Tests/run.py

Ces tests compilent les modèles et services de l'application avec des services
simulés. Ils n'appellent aucun serveur et ne modifient pas les notifications iOS.

- Réglages : chargement réussi obligatoire, échec et nouvelle tentative,
  réponses périmées après changement de serveur.
- Listes : identités film/série, recherche sur les pages suivantes, retour d'une
  fiche, nouvelles tentatives et réponses concurrentes.
- Séances et journaux : changements pendant une requête, réponses reçues dans
  le désordre, pagination avec les filtres appliqués.
- Notifications : panne TMDB, découverte partielle, liste réellement vide,
  annulation et désactivation pendant la synchronisation.

La compilation de l'app et les parcours visuels sur simulateur/appareil restent
des vérifications distinctes.
