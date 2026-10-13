// Test de bout en bout : telephones lumieres. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const mk = async (name, vp, mobile, init) => { const c = await b.newContext({ viewport: vp, isMobile: !!mobile, hasTouch: !!mobile });
  await c.addInitScript((init) => { try { localStorage.setItem('jdl.welcomed', '1'); for (const [k, v] of Object.entries(init || {})) localStorage.setItem(k, v); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; window.JDL_MQTT = 'ws://127.0.0.1:8884/mqtt'; }, init);
  const p = await c.newPage(); p.on('pageerror', e => errs.push(name + ': ' + e.message));
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : u.includes('mqtt') ? 'mqtt.min.js' : u.includes('Presets') ? 'butterchurnPresets.min.js' : 'butterchurn.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); });
  return p; };
// a laptop on the TV, on its own (no phone remote), guest features on
const tv = await mk('tv', { width: 1280, height: 720 }, false, { 'jdl.guestOn': '1', 'jdl.guestCode': 'LUM3S' });
await tv.goto('http://localhost:8765/');
await tv.click('#bSource'); await tv.click('#bDemo'); await tv.waitForTimeout(2500);
console.log('tv qr shown:', await tv.$eval('#guestQr', e => !e.hidden));
const phones = [];
for (let i = 0; i < 4; i++) {
  const g = await mk('guest' + i, { width: 300, height: 560 }, true, { 'jdl.guestId': ['aaaaaaaa', 'bbbbbbbb', 'cccccccc', 'dddddddd'][i] });
  await g.goto('http://localhost:8765/?invite=LUM3S'); await g.waitForTimeout(500);
  await g.click('#gLight');
  phones.push(g);
}
await phones[0].waitForTimeout(3500);
console.log('tv count:', await tv.textContent('#gLightsN'));
const sample = async (label) => {
  const rows = [];
  for (let t = 0; t < 8; t++) {
    rows.push((await Promise.all(phones.map(g => g.$eval('#lightPage', e => e.style.background)))).map(s => s.replace(/rgb\((\d+), (\d+), (\d+)\)/, (m, r, g2, bb) => '#' + [r, g2, bb].map(x => (+x).toString(16).padStart(2, '0')).join(''))).join(' '));
    await phones[0].waitForTimeout(250);
  }
  console.log(label + '\n  ' + rows.join('\n  '));
};
console.log('hint hidden (cue arriving):', await phones[0].$eval('#lightHint', e => e.hidden));
await sample('pulse (Projecteurs):');
await tv.mouse.move(5, 5); await tv.click('#bScenes'); await tv.click('[data-scene="chase"]'); await tv.waitForTimeout(800);
{ const seq = [];
  for (let t = 0; t < 24; t++) {
    const bg = await Promise.all(phones.map(g => g.$eval('#lightPage', e => e.style.background)));
    const lum = bg.map(x => { const m = x.match(/\d+/g).map(Number); return m[0] + m[1] + m[2]; });
    seq.push(lum.indexOf(Math.max(...lum)) + 1);
    await phones[0].waitForTimeout(250);
  }
  console.log('wave, brightest phone every 0.25 s:', seq.join(' ')); }
await sample('wave raw:');
const shots = [];
for (let i = 0; i < 4; i++) shots.push(await phones[i].screenshot());
require('fs').writeFileSync(OUT + '/phones-wave.json', JSON.stringify(shots.map(s => s.toString('base64'))));
await tv.screenshot({ path: OUT + '/phones-tv.png' });
await phones[1].click('#lightPage'); await phones[1].waitForTimeout(300);
console.log('phone 2 left light mode:', await phones[1].$eval('#lightPage', e => e.hidden), '| guest page visible', await phones[1].$eval('#guestPage', e => !e.hidden));
await tv.mouse.move(9, 9); await tv.click('#bPlay'); await tv.waitForTimeout(3600);
console.log('music paused → phone hint shown:', await phones[0].$eval('#lightHint', e => !e.hidden), '|', await phones[0].$eval('#lightPage', e => e.style.background));
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
