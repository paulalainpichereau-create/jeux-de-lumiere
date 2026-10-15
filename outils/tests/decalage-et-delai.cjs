// Test de bout en bout : décalage lumière/son et indicateur de délai. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const { spawn } = require('child_process');
const ROOT = path.resolve(__dirname, '..', '..');
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream', '--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const mk = async (name, vp, mobile) => { const c = await b.newContext({ viewport: vp, isMobile: !!mobile, hasTouch: !!mobile, permissions: ['microphone'] });
  await c.addInitScript(() => { try { localStorage.setItem('jdl.welcomed', '1'); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; window.JDL_MQTT = 'ws://127.0.0.1:8884/mqtt'; });
  const p = await c.newPage(); p.on('pageerror', e => errs.push(name + ': ' + e.message));
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : u.includes('mqtt') ? 'mqtt.min.js' : u.includes('Presets') ? 'butterchurnPresets.min.js' : 'butterchurn.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); });
  return p; };
// records the bass meter of a page on every frame, with the shared wall clock
const record = (p) => p.evaluate(() => { window.__rec = []; const el = document.getElementById('mBass');
  const f = () => { const m = /scaleY\(([\d.]+)\)/.exec(el.style.transform); if (m) window.__rec.push([Date.now(), +m[1]]); if (window.__rec.length < 4000) requestAnimationFrame(f); }; requestAnimationFrame(f); });
const series = (p) => p.evaluate(() => window.__rec);
// lag (ms) of b behind a: the shift that best matches the two curves
function lag(a, bb) {
  const t0 = Math.max(a[0][0], bb[0][0]) + 600, t1 = Math.min(a[a.length - 1][0], bb[bb.length - 1][0]) - 600;
  const at = (s, t) => { let i = s.findIndex((x) => x[0] >= t); if (i < 1) i = 1; const [ta, va] = s[i - 1], [tb, vb] = s[i]; return va + (vb - va) * ((t - ta) / Math.max(1, tb - ta)); };
  let best = 0, bestErr = Infinity;
  for (let d = 0; d <= 600; d += 10) { let e = 0, n = 0; for (let t = t0; t < t1 - d; t += 20) { e += Math.abs(at(a, t) - at(bb, t + d)); n++; } e /= n; if (e < bestErr) { bestErr = e; best = d; } }
  return best;
}
const tv = await mk('tv', { width: 900, height: 500 });
await tv.goto('http://localhost:8765/?ecran=DELAI'); await tv.waitForTimeout(1500);
const ph = await mk('phone', { width: 390, height: 844 }, true);
await ph.goto('http://localhost:8765/?r=DELAI');
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 });
await ph.waitForFunction(() => !document.getElementById('linkInfo').hidden, null, { timeout: 15000 });
console.log('téléphone:', await ph.textContent('#linkInfo'));
console.log('écran:', await tv.textContent('#screenStatus'));
await ph.keyboard.press('Escape'); await ph.click('#bSource'); await ph.click('#bDemo'); await ph.waitForTimeout(1500);
const measure = async () => { await record(ph); await record(tv); await ph.waitForTimeout(7000); return lag(await series(ph), await series(tv)); };
const l0 = await measure();
console.log('décalage 0 ms → la TV suit le téléphone avec', l0, 'ms');
await ph.mouse.move(5, 5); await ph.click('#bMore');
await ph.$eval('#delay', (e) => { e.value = 300; e.dispatchEvent(new Event('input', { bubbles: true })); });
await ph.click('#moreClose'); await ph.waitForTimeout(1500);
console.log('réglage reçu par la TV:', await tv.$eval('#delay', (e) => e.value), 'ms |', await tv.textContent('#delayInfo'));
const l300 = await measure();
console.log('décalage 300 ms → la TV suit le téléphone avec', l300, 'ms (écart ' + (l300 - l0) + ' ms)');
// the iPhone app through the relay
const tv2 = await mk('tv2', { width: 600, height: 400 });
await tv2.goto('http://localhost:8765/?ecran=RELAI'); await tv2.waitForTimeout(1500);
const fake = spawn(process.execPath, [path.join(__dirname, '..', 'faux-iphone.cjs'), 'ws://127.0.0.1:8884/mqtt', 'RELAI', '12'], { stdio: 'ignore' });
await tv2.waitForFunction(() => /relais internet ~/.test(document.getElementById('screenStatus').textContent), null, { timeout: 15000 }).catch(() => {});
console.log('écran avec l’app iPhone:', await tv2.textContent('#screenStatus'));
fake.kill();
const okDelay = Math.abs((l300 - l0) - 300) <= 60;
if (!okDelay) errs.push('écart mesuré ' + (l300 - l0) + ' ms au lieu de ~300 ms');
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
