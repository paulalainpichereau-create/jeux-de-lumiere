# Publier Jeux de lumière sur Google Play et l’App Store

Tout se fait depuis un téléphone ou un ordinateur, sans Mac. Les applications sont compilées automatiquement par GitHub.
Les textes à copier-coller sont dans [FICHES.md](FICHES.md), les images dans `images/` et `captures/`.

---

## Android (Google Play)

### 0. Essayer tout de suite (gratuit)
Sur un téléphone Android, ouvrez
https://github.com/paulalainpichereau-create/jeux-de-lumiere/releases/tag/android
et téléchargez **JeuxDeLumiere.apk**. Android demande d’autoriser l’installation depuis le navigateur : acceptez pour ce fichier.

### 1. Le compte développeur (25 $, une seule fois)
1. https://play.google.com/console › créer un compte **personnel** avec votre compte Google.
2. Payer les 25 $ et faire vérifier votre identité (pièce d’identité ; compter quelques jours).
3. ⚠️ Règle Google pour les nouveaux comptes personnels : avant la mise en ligne publique, l’application doit passer par un **test fermé avec au moins 12 testeurs pendant 14 jours d’affilée** (famille, amis : il leur faut juste une adresse Gmail).

### 2. La clé d’envoi (à faire une fois)
Le fichier **cle-android-a-garder.txt** (envoyé par Claude) contient deux valeurs à ajouter dans GitHub :
dépôt jeux-de-lumiere › **Settings › Secrets and variables › Actions › New repository secret**
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEYSTORE_B64`

Ensuite, demandez à Claude de relancer la compilation (ou faites un petit changement) : le fichier **JeuxDeLumiere-PlayStore.aab** de la page « android » est alors signé pour le Play Store.

### 3. Créer l’application dans la Play Console
1. **Créer une application** › nom « Jeux de lumière », langue français, Application, Gratuite.
2. **Fiche Play Store principale** : textes de FICHES.md, icône `images/icone-512.png`, bannière `images/banniere-play-1024x500.png`, captures `captures/android-*.png`.
3. **Contenu de l’application** : règles de confidentialité (adresse de la page confidentialite.html), accès aux applications (« toutes les fonctionnalités sont accessibles sans restriction »), annonces (« non »), classification, public cible, sécurité des données (réponses dans FICHES.md).

### 4. Envoyer et tester
1. **Tests › Test fermé** › créer une version › importer **JeuxDeLumiere-PlayStore.aab** (page « android » des releases).
   Accepter « Signature d’application par Google Play ».
2. Ajouter les 12 testeurs (adresses Gmail), leur envoyer le lien d’inscription.
3. Après 14 jours : **Production › Créer une version** avec le même fichier, puis « Envoyer pour examen ». Google répond en général en quelques jours.

*Bon à savoir : l’application affiche le site en ligne, donc les améliorations des lumières arrivent toutes seules, sans republier. On ne republie que si la partie Android elle-même change.*

### Android TV / Google TV (facultatif)
L’application s’installe aussi sur les TV Android. Pour la proposer dans le Play Store des TV : Play Console › Paramètres avancés › **Formats › Android TV**, avec des captures en 1920 × 1080. Google vérifie les applis TV à part.

---

## iPhone et iPad (App Store)

### 1. Le compte développeur Apple (99 $ par an)
1. Installez l’app **Apple Developer** sur l’iPhone › Compte › **S’inscrire** (avec votre identifiant Apple ; double authentification obligatoire).
2. Payer l’abonnement. L’activation prend en général de quelques heures à 2 jours.

### 2. Déclarer l’application
1. https://developer.apple.com/account › **Certificates, Identifiers & Profiles › Identifiers › +** › App IDs › App.
   Description « Jeux de lumière », Bundle ID explicite : `fr.jeuxdelumiere.app`. Enregistrer.
2. https://appstoreconnect.apple.com › **Apps › + › Nouvelle app** : plateforme iOS, nom « Jeux de lumière », langue français, Bundle ID `fr.jeuxdelumiere.app`, SKU `jeuxdelumiere`.

### 3. La clé qui permet à GitHub d’envoyer l’app
1. App Store Connect › **Utilisateurs et accès › Intégrations › Clés de l’API App Store Connect** › générer une clé, nom « GitHub », accès **Admin**.
2. Noter l’**ID d’émetteur** (Issuer ID, en haut) et l’**ID de la clé** (Key ID), puis **télécharger** le fichier `.p8`. Il n’est téléchargeable qu’une fois : gardez-le.
3. Votre **Team ID** : https://developer.apple.com/account › Abonnement (Membership details).
4. Dans GitHub (Settings › Secrets and variables › Actions › New repository secret), ajouter :
   - `APPSTORE_ISSUER_ID` : l’ID d’émetteur
   - `APPSTORE_KEY_ID` : l’ID de la clé
   - `APPSTORE_KEY_P8` : tout le contenu du fichier .p8 (l’ouvrir avec un éditeur de texte, de `-----BEGIN PRIVATE KEY-----` à `-----END PRIVATE KEY-----`)
   - `APPLE_TEAM_ID` : le Team ID
5. Demandez à Claude de relancer la compilation : GitHub signe l’app et l’envoie à Apple.

### 4. Tester avec TestFlight
Une quinzaine de minutes après l’envoi, la version apparaît dans App Store Connect › TestFlight.
Installez l’app **TestFlight** sur l’iPhone : l’app Jeux de lumière s’y installe en un geste, sans Sideloadly ni ordinateur.
C’est aussi le moyen de faire essayer l’app à des proches (jusqu’à 100 testeurs internes, 10 000 externes).

### 5. Soumettre à Apple
App Store Connect › l’app › version 1.0 :
- textes, mots-clés, URL : FICHES.md ;
- captures : `captures/iphone-6.9-*.png` (iPhone) et `captures/ipad-13-*.png` (iPad) ;
- **Confidentialité de l’app** : « Données non collectées » ;
- **Classification par âge** : voir FICHES.md ;
- choisir la version envoyée par GitHub (« Build »), coller les **notes pour la vérification** de FICHES.md, puis **Soumettre pour vérification**. Apple répond en général en 1 à 3 jours.

### Chromecast dans l’app iPhone (facultatif)
Le bouton Chromecast n’apparaît que lorsque l’identifiant Google Cast est configuré (voir `ios/CHROMECAST.md` : 5 $ une fois chez Google, puis la variable `CAST_APP_ID`). Sans lui, l’app fonctionne avec la TV par le code à taper, et dans l’onglet Lumières.

---

## Récapitulatif des coûts
| | Coût | Délai |
|---|---|---|
| Google Play | 25 $ une fois | vérification d’identité quelques jours + test fermé 14 jours + examen quelques jours |
| App Store | 99 $ par an | activation 1-2 jours + examen 1-3 jours |
| Chromecast (facultatif) | 5 $ une fois | immédiat |
