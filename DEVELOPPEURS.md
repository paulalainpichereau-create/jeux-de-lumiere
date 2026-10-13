# Guide développeur — Jeux de lumière

Pour une présentation de l’appli côté utilisateur, voir le [README](README.md).

## 1. Vue d’ensemble

```
                 musique (micro, fichier, démo…)
                            │
              ┌─────────────▼─────────────┐
              │  TÉLÉPHONE-TÉLÉCOMMANDE    │  analyse le son, choisit scènes et réglages
              └─────────────┬─────────────┘
                 PeerJS → WebRTC direct (~30 images de son par seconde + réglages)
              ┌─────────────▼─────────────┐
              │  ÉCRAN PRINCIPAL (hub)     │  dessine les lumières
              └──────┬──────────────┬─────┘
          WebRTC (relais)       relais MQTT public
       ┌─────────▼───────┐   ┌────▼──────────────────────────┐
       │ ÉCRANS EN PLUS  │   │ TÉLÉPHONES DES INVITÉS         │
       │ (même code)     │   │ lumières + messages / émojis   │
       └─────────────────┘   └────────────────────────────────┘

  App iPhone (Spotify sans micro) ──MQTT──► tous les écrans du même code
```

- **Une seule appli web** (`index.html`) fait tout : appareil seul, télécommande, écran, écran en plus, récepteur Chromecast, page invité. Le rôle dépend du parcours dans l’appli ou des paramètres d’adresse.
- Les **applis natives** (Android, iPhone) affichent ce même site dans une vue web plein écran, et ajoutent ce qu’une page ne peut pas faire (écran toujours allumé, permissions ; sur iPhone, la capture du son de Spotify).
- **Aucun serveur à nous** : le site est statique (GitHub Pages) ; la mise en relation passe par deux services publics gratuits (voir § 4).

## 2. Le dépôt

```
index.html            toute l’appli web (HTML + CSS + JS, sans étape de compilation)
sw.js                 service worker : fonctionnement hors connexion (version du cache)
manifest.webmanifest  installation sur l’écran d’accueil (PWA)
vendor/               bibliothèques servies en local en production (Butterchurn, PeerJS, MQTT.js, qrcode)
confidentialite.html  politique de confidentialité (exigée par les stores)
android/              app Android (Java, WebView), compilée par .github/workflows/android.yml
ios/                  app iPhone (SwiftUI + extension ReplayKit + Google Cast), compilée par .github/workflows/ios.yml
stores/               fiches, captures, images et guide de publication Google Play / App Store
outils/               serveurs locaux de test, tests de bout en bout, version du cache, icônes
```

## 3. L’appli web (`index.html`)

Du JavaScript « vanilla » dans un seul bloc, découpé en sections commentées (`/* ---------- … ---------- */`). Les principales, dans l’ordre du fichier :

| Section | Rôle |
|---|---|
| canvas, state | taille du canevas, qualité adaptative (`renderScale`), état audio `S` (bass, mid, high, level, beat, hue…) |
| audio graph, demo, files, microphone | `AudioContext` + `AnalyserNode` (FFT 2048) ; morceau de démo généré (118 BPM) ; lecture de fichiers ; micro avec seuil de bruit |
| analysis | 48 bandes logarithmiques (40 Hz–14 kHz), gain automatique, détection des battements, tempo (médiane des intervalles, ramené à 80–170 BPM) |
| scenes, club scenes, holiday scenes, colour tile | une fonction par scène (`SCENE_FN`), traînée par scène (`TRAIL`) ; les couleurs passent par `mapHue()` (palette) sauf les scènes de fête |
| MilkDrop | Butterchurn en WebGL 2, chargé à la première utilisation |
| frame loop | analyse → mode Auto → dessin (deux calques pour les fondus) → surimpressions → signaux vers les téléphones invités |
| Auto, packs | `autoScene()` : énergie lissée, passages calmes, « drop » ; `PACKS` : scènes, palette, rythme (`pace`), fondus (`fade`), scène phare (`home`) |
| interface, panneaux | barre unique, panneaux Son / Plus / Scènes / Couleurs / Dalle / Options, accueil en deux questions |
| keep awake | Wake Lock renouvelé + mini-vidéo silencieuse sur iPhone |
| remote control | télécommande, écrans en plus, battement de cœur (§ 4) |
| Cast, Chromecast receiver | Presentation API (Chrome) ; récepteur Google Cast personnalisé (`?cast=1`) |
| guest messages, phones as lights | page invité, filtre, mur de messages, signal lumineux pour les téléphones |

**Paramètres d’adresse**

| Adresse | Effet |
|---|---|
| `?r=CODE` | ce téléphone devient la télécommande de l’écran CODE (QR code de l’écran) |
| `?ecran=CODE` | cet appareil devient l’écran CODE (ou un écran en plus si le code est pris) — utilisé par le bouton Caster |
| `?cast=1` | récepteur Chromecast (le code arrive par le canal Cast) |
| `?invite=CODE` | page invité : téléphone-lumière, messages, émojis |
| `?app=android` / `?app=ios` | ouverte par une app native (l’appli le détecte aussi via le User-Agent `JeuxDeLumiereApp/…`) |

**Réglages mémorisés** : `localStorage`, clés préfixées `jdl.` (scène, pack, palette, mes couleurs, tonalité, dalle, options invités…). Aucune donnée ne part ailleurs.

**Accessibilité et sécurité** : `prefers-reduced-motion` adoucit les effets et désactive le stroboscope ; le stroboscope est désactivé par défaut et limité à 3 flashs par seconde ; flash des téléphones limité à 2 par seconde.

## 4. Les liaisons entre appareils

### Télécommande et écrans (PeerJS → WebRTC)
- Chaque écran principal prend l’identifiant PeerJS `jeux-de-lumiere-<code>` sur 0.peerjs.com (le code : 5 caractères sans ambiguïté, `ABCDEFGHJKMNPQRSTUVWXYZ23456789`).
- La télécommande s’y connecte ; un **écran en plus** qui tape le même code trouve l’identifiant pris et se connecte à son tour au hub avec `metadata: { follow: 1 }`. Le hub relaie aux écrans en plus les images de son et les réglages.
- **Battement de cœur** : chaque liaison envoie `{t:'hb'}` toutes les 2 s ; sans nouvelles depuis 8 s, elle est fermée. Si le hub disparaît, un écran en plus reprend le code et la télécommande réessaie (6 fois, toutes les 2,5 s).

Messages (JSON) :

| `t` | Sens | Contenu |
|---|---|---|
| `f` | télécommande → écrans | une image de son : `tb tm th` (graves, médiums, aigus), `loud`, `ts` (48 bandes), `wv` (64 points d’onde), `beat`, et `k` (compteur de battements du hub, ajouté au relais) |
| `state` | télécommande → écrans | réglages : `sel`, `pack`, `palette`, `mine`, `tone`, `multiHue`, `tile`, `autoSet`, `opt` (message, compte à rebours, stroboscope, invités, effet des téléphones) |
| `scene` | télécommande/hub → écrans | `current`, `sel`, `dur` (durée du fondu) |
| `idx` | hub → écrans en plus | place de l’écran `i` sur `n`, compteur `k`, option couleurs différentes `on` |
| `guestClear` | → écrans | effacer les messages des invités |
| `hb` | dans les deux sens | battement de cœur |

### Relais MQTT (broker.emqx.io, WebSocket `wss://broker.emqx.io:8084/mqtt`)

| Sujet | Qui publie | Contenu |
|---|---|---|
| `jeux-de-lumiere/v1/<code>` | app iPhone (extension ReplayKit) | images de son `{t:'f', …}`, même format que ci-dessus |
| `jeux-de-lumiere/v1/<code>/m` | téléphones des invités | `{t:'msg', id, text, name}`, `{t:'react', id, e}`, `{t:'light', id}` (présence d’un téléphone-lumière, toutes les 8 s) |
| `jeux-de-lumiere/v1/<code>/l` | écran principal | signal lumineux ~12/s, seulement si des téléphones sont allumés : `h h2` (teintes), `lv` (niveau), `b` (n° de battement), `bpm`, `ago` (ms depuis le dernier battement), `m` (effet) ; pour la dalle : `cs ci mu rh` |

Les téléphones recalculent eux-mêmes les battements à partir de `bpm` et `ago` (avec ~150 ms de compensation du relais), ce qui les garde en rythme malgré le délai.
Côté écran, les messages invités passent un filtre (insultes courantes, liens) et une limite (1 message / 12 s par invité).

### Chromecast
- Depuis Chrome (ordinateur, Android) : **Presentation API**, qui ouvre `?ecran=CODE` sur la TV ; repli sur l’appairage par code après 6 s.
- Depuis l’app iPhone : récepteur Google Cast personnalisé `?cast=1`, espace de noms `urn:x-cast:fr.jeuxdelumiere`, premier message `{t:'code', code}`. Il faut un identifiant d’application Cast (voir `ios/CHROMECAST.md`, variable de dépôt `CAST_APP_ID`).

## 5. Les applis natives

### Android (`android/`)
- Une seule activité Java (`MainActivity`) : WebView plein écran immersif sur le site en ligne, `FLAG_KEEP_SCREEN_ON`, permission micro relayée à la page, retour arrière qui ferme d’abord les panneaux, page hors connexion au premier lancement sans réseau. S’installe aussi sur Android TV (bannière, `LEANBACK_LAUNCHER`).
- Pas d’AndroidX : seul le plugin Android Gradle (8.11). `compileSdk`/`targetSdk` 36, `minSdk` 24.
- Le site étant chargé en ligne, **une modification de `index.html` arrive dans l’app sans republier**.

### iPhone (`ios/`)
- Projet décrit par **XcodeGen** (`project.yml`) + **CocoaPods** (Google Cast) ; le projet Xcode est généré sur GitHub.
- `App/` : deux onglets — `LightsView` (WKWebView du site, micro autorisé, écran allumé ; pendant une diffusion, s’ouvre en écran de son propre code pour suivre Spotify) et « Spotify et TV » ; `CastLink` (Google Cast).
- `Broadcast/` : **extension ReplayKit** qui reçoit le son des autres applis (`.audioApp`), l’analyse (`Analyzer.swift`, FFT Accelerate, même calcul que le site) et publie les images sur le relais MQTT (`MQTTLink.swift`, client MQTT 3.1.1 minimal sur WebSocket).
- `Shared/Signal.swift` : l’app et l’extension se parlent par **notifications Darwin** (le code est épelé caractère par caractère, sans App Group).

### Compilation (GitHub Actions)
| Workflow | Produit | Secrets / variables |
|---|---|---|
| `android.yml` (à chaque changement de `android/`) | release **android** : `JeuxDeLumiere.apk` (essai), `JeuxDeLumiere-PlayStore.aab` | `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD` (sinon signé avec une clé de test) |
| `ios.yml` (à chaque changement de `ios/`) | release **prototype-iphone** (ipa non signé) ; envoi à App Store Connect | `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_P8`, `APPLE_TEAM_ID` ; variable `CAST_APP_ID` |
| GitHub Pages (branche `main`) | le site | — |

## 6. Travailler en local

Il faut Node.js 18+ (et Python 3 avec Pillow seulement pour régénérer les icônes).

```bash
cd outils
npm install
npx playwright install chromium     # une fois : le navigateur des tests
npm run serveurs                    # appli sur http://localhost:8765/ + relais PeerJS et MQTT locaux
```

Dans un autre terminal :

```bash
cd outils
npm run tests                       # 9 tests de bout en bout (≈ 5 min)
```

- Ouvrir http://localhost:8765/ dans Chrome suffit pour travailler sur les scènes (choisir **Démo** comme son).
- Pour utiliser les relais locaux au lieu des services publics, la page lit `window.JDL_PEER` (options PeerJS) et `window.JDL_MQTT` (adresse du relais) ; les tests les définissent avant le chargement. `outils/faux-iphone.cjs` simule l’app iPhone (même octets MQTT que `MQTTLink.swift`).
- Le micro ne marche qu’en `https` ou sur `localhost`.

Les tests (`outils/tests/`) : accueil et barre, télécommande, plusieurs écrans (dont la reprise quand l’écran principal s’éteint), app iPhone (faux iPhone), messages des invités (filtre, limite), téléphones-lumières, couleurs, dalle, packs. Leurs captures vont dans `outils/tests/captures/`.

## 7. Publier une modification

1. Modifier `index.html` (et tester : `npm run tests`).
2. `cd outils && npm run publier` — change la version du cache dans `sw.js`, sinon les appareils qui ont déjà l’appli garderaient l’ancienne version.
3. Pousser sur `main` : GitHub Pages met le site à jour en ~1 minute ; les applis Android et iPhone l’affichent aussitôt.
4. Ne republier les applis natives que si `android/` ou `ios/` changent (versions incrémentées automatiquement par le numéro de compilation).

Icônes : `python3 outils/icones.py` (depuis la racine) régénère celles du site, d’Android, de l’App Store et des stores.

## 8. Points d’attention

- **Services publics gratuits** (0.peerjs.com, broker.emqx.io) : sans garantie de disponibilité ni de charge. Pour un usage à grande échelle, prévoir un serveur PeerJS et un relais MQTT à nous (il suffit de changer `peerOpts()` et `MQ_URL()`).
- **Codes de soirée** : 5 caractères, n’importe qui connaissant le code peut écouter ou publier sur le relais. Rien de sensible n’y passe (des niveaux sonores, des réglages, des messages éphémères), mais c’est à garder en tête.
- **iPhone (Safari)** : pas de plein écran pour une page (d’où le guide d’installation sur l’écran d’accueil), Wake Lock ignoré dans une appli installée avant iOS 18.4 (d’où la mini-vidéo), pas de flash depuis le web.
- **Revue Apple** : la capture du son de Spotify par ReplayKit pourrait être questionnée ; les notes de vérification sont prêtes dans `stores/FICHES.md`.
- **Pistes ouvertes** : vote des invités pour le prochain pack ; capture du son des autres applis sur Android (AudioPlaybackCapture) ; ampoules et rubans LED connectés (Hue, WLED) ; serveurs à nous.
