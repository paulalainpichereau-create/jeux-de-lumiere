// Test de bout en bout : une scène sur le téléphone, une autre sur le seul écran relié. Lancer d'abord « npm run serveurs ».
const { chromium } = require('playwright');
const path = require('path');
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
const pc = await mk('ordinateur', { width: 900, height: 500 });
await pc.goto('http://localhost:8765/?ecran=UNSEU'); await pc.waitForTimeout(1500);
const ph = await mk('telephone', { width: 390, height: 844 }, true);
await ph.goto('http://localhost:8765/?r=UNSEU');
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 });
await ph.keyboard.press('Escape'); await ph.click('#bSource'); await ph.click('#bDemo'); await ph.waitForTimeout(1000);
await ph.click('#bScenes');
console.log('section Écrans visible avec un seul écran:', await ph.$eval('#screensBox', (e) => !e.hidden));
await (await ph.$$('#screensList select'))[0].selectOption('lasers'); await ph.waitForTimeout(800);
await ph.click('[data-scene="disco"]'); await ph.waitForTimeout(1200);
const a = await ph.textContent('#bScenes'), c = await pc.textContent('#bScenes');
console.log('téléphone:', a, '| ordinateur:', c);
if (!/Boule/.test(a) || !/Lasers/.test(c)) errs.push('scènes différentes non obtenues');
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
