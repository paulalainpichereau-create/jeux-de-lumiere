// Test de bout en bout : dalle de couleur. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const mk = async (name, vp, mobile, init) => { const c = await b.newContext({ viewport: vp, isMobile: !!mobile, hasTouch: !!mobile, permissions: ['microphone'] });
  await c.addInitScript((init) => { try { localStorage.setItem('jdl.welcomed', '1'); for (const [k, v] of Object.entries(init || {})) localStorage.setItem(k, v); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; window.JDL_MQTT = 'ws://127.0.0.1:8884/mqtt'; }, init);
  const p = await c.newPage(); p.on('pageerror', e => errs.push(name + ': ' + e.message));
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : 'mqtt.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); });
  return p; };
const px = (p) => p.evaluate(() => { const c = document.getElementById('stage'); const d = c.getContext('2d').getImageData(c.width >> 1, c.height >> 1, 1, 1).data; return '#' + [d[0], d[1], d[2]].map(x => x.toString(16).padStart(2, '0')).join(''); });
const seq = async (pages, n = 10, gap = 300) => { const out = []; for (let t = 0; t < n; t++) { out.push((await Promise.all(pages.map(px))).join(' ')); await pages[0].waitForTimeout(gap); } return out.join('\n   '); };
// --- one TV on its own
const tv = await mk('tv', { width: 960, height: 540 });
await tv.goto('http://localhost:8765/');
await tv.click('#bSource'); await tv.click('#bDemo'); await tv.waitForTimeout(800);
await tv.click('#bScenes'); await tv.click('[data-scene="tile"]'); await tv.waitForTimeout(600);
console.log('label:', await tv.textContent('#bScenes'), '| Régler la dalle visible:', await tv.$eval('#bTile', e => !e.hidden));
await tv.click('#bTile'); await tv.screenshot({ path: OUT + '/tile-sheet.png' });
for (const r of ['pulse', 'jump', 'fade']) {
  await tv.click(`[data-rhythm="${r}"]`); await tv.waitForTimeout(1200);
  console.log(r + ':\n   ' + await seq([tv], 8, 350));
}
await tv.click('[data-rhythm="jump"]'); await tv.selectOption('#tileEvery', '2'); await tv.selectOption('#tileColors', 'fixed'); await tv.fill('#tileFixed', '#ff0000');
await tv.waitForTimeout(800); console.log('jump, one colour (red), every 2 beats:\n   ' + await seq([tv], 8, 350));
await tv.click('#tileClose');
await tv.close();
// --- three screens + a phone remote + a guest phone
const screens = [];
for (let i = 0; i < 3; i++) { const s = await mk('s' + i, { width: 480, height: 270 }); await s.goto('http://localhost:8765/?ecran=T1LES'); await s.waitForTimeout(1500); screens.push(s); }
const ph = await mk('phone', { width: 390, height: 844 }, true, { 'jdl.guestOn': '1' });
await ph.goto('http://localhost:8765/?r=T1LES');
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 });
await ph.keyboard.press('Escape'); await ph.click('#bSource'); await ph.click('#bDemo'); await ph.waitForTimeout(800);
await ph.click('#bScenes'); await ph.click('[data-scene="tile"]'); await ph.waitForTimeout(500);
await ph.click('#bTile'); await ph.click('[data-rhythm="jump"]'); await ph.selectOption('#tileEvery', '1'); await ph.selectOption('#tileColors', 'palette');
for (const mu of ['same', 'each', 'chase']) {
  await ph.selectOption('#tileMulti', mu); await screens[0].waitForTimeout(1500);
  console.log('3 screens, ' + mu + ':\n   ' + await seq(screens, 6, 300));
  for (let i = 0; i < 3; i++) await screens[i].screenshot({ path: `${OUT}/tile-${mu}-${i}.png` });
}
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
