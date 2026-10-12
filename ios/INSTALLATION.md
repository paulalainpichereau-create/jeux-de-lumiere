# Installer le prototype iPhone sans Mac

Le prototype sert à une seule chose : vérifier que le son de Spotify ou Deezer arrive bien dans l’application
pendant une « Diffusion » d’écran. Il n’est pas sur l’App Store ; on l’installe soi-même.

## Ce qu’il faut
- Un ordinateur **Windows** (ou un Mac) et le câble de l’iPhone.
- Votre **identifiant Apple** (un compte gratuit suffit).
- Le fichier : https://github.com/paulalainpichereau-create/jeux-de-lumiere/releases/tag/prototype-iphone
  → télécharger `JeuxDeLumiere-non-signe.ipa`.

## Étapes (avec Sideloadly, gratuit)
1. Sur l’ordinateur, installer **iTunes** (version du site d’Apple, pas celle du Microsoft Store) puis **Sideloadly** (sideloadly.io).
2. Brancher l’iPhone, le déverrouiller, toucher « Se fier à cet ordinateur ».
3. Ouvrir Sideloadly, glisser le fichier `.ipa`, taper l’identifiant Apple, cliquer **Start**.
4. Sur l’iPhone : Réglages › Confidentialité et sécurité › **Mode développeur** › activer (l’iPhone redémarre).
5. Réglages › Général › **VPN et gestion de l’appareil** › votre identifiant › **Faire confiance**.
6. Ouvrir « Jeux de lumière ».

Avec un compte Apple gratuit, l’application doit être réinstallée tous les **7 jours** (même procédure).

## Le test
1. Dans l’app, toucher le bouton rond, choisir « Jeux de lumière », puis **Commencer la diffusion**.
2. Ouvrir Spotify (ou Deezer) et lancer une musique, sur le haut-parleur ou une enceinte Bluetooth.
3. Revenir dans l’app :
   - « Son reçu : ça marche ! » et des flashs au rythme → la capture fonctionne avec cette app de musique ;
   - « Diffusion en cours, mais aucun son reçu » → cette app de musique bloque la capture.
4. Arrêter la diffusion en touchant l’indicateur rouge en haut de l’écran.
