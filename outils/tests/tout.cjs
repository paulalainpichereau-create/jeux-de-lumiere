// Lance tous les tests l'un après l'autre et résume. Les serveurs locaux doivent tourner (npm run serveurs).
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const files = fs.readdirSync(__dirname).filter((f) => f.endsWith('.cjs') && f !== 'tout.cjs').sort();
let failed = 0;
for (const f of files) {
  const r = spawnSync(process.execPath, [path.join(__dirname, f)], { encoding: 'utf8', timeout: 240000 });
  const out = (r.stdout || '') + (r.stderr || '');
  const ok = r.status === 0 && /errors: none/.test(out);
  if (!ok) failed++;
  console.log((ok ? '✓ ' : '✗ ') + f.replace('.cjs', ''));
  if (!ok) console.log(out.split('\n').slice(-15).map((l) => '    ' + l).join('\n'));
}
console.log(failed ? `${failed} test(s) en échec` : 'Tous les tests passent.');
process.exit(failed ? 1 : 0);
