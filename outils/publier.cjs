// À lancer après chaque modification de index.html, avant de pousser sur GitHub :
// change la version du cache hors connexion (sw.js), pour que les appareils qui ont déjà l'appli
// téléchargent la nouvelle version au lieu de garder l'ancienne.
const fs = require('fs');
const path = require('path');
const f = path.resolve(__dirname, '..', 'sw.js');
const s = fs.readFileSync(f, 'utf8');
const m = s.match(/const CACHE = 'jdl-v(\d+)';/);
if (!m) { console.error('Version du cache introuvable dans sw.js'); process.exit(1); }
const next = Number(m[1]) + 1;
fs.writeFileSync(f, s.replace(m[0], `const CACHE = 'jdl-v${next}';`));
console.log(`Cache : jdl-v${m[1]} → jdl-v${next}`);
