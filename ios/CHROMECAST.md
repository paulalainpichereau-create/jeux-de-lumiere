# Afficher les lumières sur un Chromecast depuis l’app iPhone

Le Chromecast affiche une page « réceptrice » propre à l’application : c’est l’app web en mode
Chromecast (`?cast=1`). Google demande de déclarer cette page une fois, dans sa console développeur.

## 1. Inscription (une seule fois)
1. Ouvrir https://cast.google.com/publish et se connecter avec un compte Google.
2. Accepter les conditions et payer les frais d’inscription (paiement unique).

## 2. Déclarer le récepteur
1. **Add New Application** › **Custom Receiver**.
2. Nom : `Jeux de lumière`.
3. Receiver Application URL :
   `https://paulalainpichereau-create.github.io/jeux-de-lumiere/?cast=1`
4. Enregistrer : Google affiche un **Application ID** de 8 caractères (par exemple `A1B2C3D4`).

## 3. Déclarer votre Chromecast (pour les tests)
Tant que l’application n’est pas publiée, elle ne s’ouvre que sur les appareils déclarés.
1. **Add New Device**, taper le **numéro de série** du Chromecast (au dos de l’appareil ou de la boîte,
   ou dans l’app Google Home › appareil › Paramètres › Informations sur l’appareil).
2. Attendre environ 15 minutes, puis **redémarrer le Chromecast**.
(Ou cliquer **Publish** sur l’application : elle s’ouvre alors sur tous les Chromecast.)

## 4. Donner l’identifiant à l’app iPhone
Dans le dépôt GitHub : Settings › Secrets and variables › Actions › onglet **Variables** ›
**New repository variable** : nom `CAST_APP_ID`, valeur = l’Application ID. (Ou envoyer l’identifiant
à Claude, qui le règle.) GitHub recompile l’app avec cet identifiant.

## Utilisation
1. iPhone et Chromecast sur le même Wi-Fi ; autoriser « réseau local » quand l’app le demande.
2. Dans l’app : toucher l’icône **Cast**, choisir le Chromecast → la TV affiche les lumières.
3. Toucher le bouton rond › **Commencer la diffusion**, puis lancer Spotify ou Deezer.
