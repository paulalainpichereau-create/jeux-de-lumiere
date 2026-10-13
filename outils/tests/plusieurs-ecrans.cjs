// Test de bout en bout : plusieurs ecrans. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const mk = async (name, vp) => { const c = await b.newContext({ viewport: vp, permissions: ['microphone'] });
  await c.addInitScript(() => { try { localStorage.setItem('jdl.welcomed', '1'); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; window.JDL_MQTT = 'ws://127.0.0.1:8884/mqtt'; });
  const p = await c.newPage(); p.on('pageerror', e => errs.push(name + ': ' + e.message)); p.on('console', m => { if (/peer/i.test(m.text())) console.log(name, 'console:', m.text().slice(0,200)); });
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : u.includes('mqtt') ? 'mqtt.min.js' : u.includes('Presets') ? 'butterchurnPresets.min.js' : 'butterchurn.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); });
  return p; };
const lbl = (p) => p.textContent('#bScenes');
const meter = (p) => p.$eval('#mBass', e => e.style.transform);
// TV 1: normal "Cet appareil est l'écran"
const tv1 = await mk('tv1', { width: 1280, height: 720 });
await tv1.goto('http://localhost:8765/');
await tv1.click('#bMore'); await tv1.click('#bRemote'); await tv1.click('#bBeScreen');
await tv1.waitForFunction(() => /^[A-Z0-9]{5}$/.test(document.getElementById('screenCode').textContent));
const code = await tv1.textContent('#screenCode');
// tablet: Plus › Télécommande › Ajouter cet écran
const tab = await mk('tablet', { width: 1024, height: 768 });
await tab.goto('http://localhost:8765/');
await tab.click('#bMore'); await tab.click('#bRemote');
await tab.fill('#joinCode', code); await tab.click('#bJoinScreen');
await tab.waitForFunction(() => document.getElementById('screenStatus').textContent.includes('suit le premier'), null, { timeout: 15000 });
console.log('code', code, '| tablet:', await tab.textContent('#screenStatus'), '| tv1:', await tv1.textContent('#screenExtra'));
await tab.screenshot({ path: OUT + '/multi-tablet-sheet.png' });
// TV 2 via ?ecran=CODE (what Caster opens)
const tv2 = await mk('tv2', { width: 1280, height: 720 });
await tv2.goto('http://localhost:8765/?ecran=' + code);
await tv2.waitForFunction(() => /supplémentaire/.test(document.getElementById('statusText').textContent), null, { timeout: 15000 });
console.log('tv2:', await tv2.textContent('#statusText'), '| tv1:', await tv1.textContent('#screenExtra'));
// phone pairs with TV1 and plays demo, chooses Disco pack
const ph = await mk('phone', { width: 390, height: 844 });
await ph.goto('http://localhost:8765/?r=' + code);
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 });
await ph.keyboard.press('Escape'); await ph.click('#bSource'); await ph.click('#bDemo'); await ph.waitForTimeout(800);
await ph.click('#bScenes'); await ph.click('[data-pack="disco"]'); await ph.waitForTimeout(2000);
await tab.keyboard.press('Escape');
for (const [n, p] of [['phone', ph], ['tv1', tv1], ['tablet', tab], ['tv2', tv2]]) console.log(n.padEnd(7), await lbl(p), '|', await p.textContent('#bPal'), '|', await meter(p));
await ph.click('#bScenes'); await ph.click('[data-scene="lasers"]'); await ph.waitForTimeout(1200);
console.log('single scene → tv1', await lbl(tv1), '| tablet', await lbl(tab), '| tv2', await lbl(tv2));
await tab.screenshot({ path: OUT + '/multi-tablet.png' });
// TV 1 goes away: one of the others takes over the code, the phone finds it again
await tv1.context().close();
const t0 = Date.now();
await ph.waitForFunction(() => /perdue/.test(document.getElementById('remoteStatus').textContent), null, { timeout: 20000 }).catch(() => {});
console.log('phone noticed after', ((Date.now() - t0) / 1000).toFixed(1), 's');
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 40000 }).catch(() => {});
console.log('phone back after', ((Date.now() - t0) / 1000).toFixed(1), 's');
await ph.waitForTimeout(3000);
console.log('after tv1 left → phone:', await ph.textContent('#remoteStatus'));
console.log('  tablet:', await tab.textContent('#screenStatus'), '|', await tab.textContent('#screenExtra'));
console.log('  tv2:', await tv2.textContent('#screenStatus'), '|', await tv2.textContent('#screenExtra'));
await ph.click('#bScenes').catch(()=>{}); await ph.mouse.move(5,5); await ph.click('#bScenes'); await ph.click('[data-pack="halloween"]'); await ph.waitForTimeout(2500);
console.log('  pack halloween → tablet', await lbl(tab), '| tv2', await lbl(tv2), '| meters', await meter(tab), await meter(tv2));
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
