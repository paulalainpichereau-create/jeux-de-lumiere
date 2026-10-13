// Test de bout en bout : telecommande. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const init = () => { try { localStorage.setItem('jdl.welcomed', '1'); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; };
const mk = async (name, vp) => { const c = await b.newContext({ viewport: vp, permissions: ['microphone'] }); await c.addInitScript(init); const p = await c.newPage();
  p.on('pageerror', e => errs.push(name + ': ' + e.message)); await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort()); await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : u.includes('Presets') ? 'butterchurnPresets.min.js' : 'butterchurn.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); }); return p; };
const scr = await mk('screen', { width: 1280, height: 720 });
await scr.goto('http://localhost:8765/');
await scr.click('#bMore'); await scr.click('#bRemote'); await scr.click('#bBeScreen');
await scr.waitForSelector('#screenBox:not([hidden])', { timeout: 15000 });
const code = (await scr.textContent('#screenCode')).trim();
console.log('screen code', code, '| qr svg', await scr.$eval('#screenQr', e => e.innerHTML.startsWith('<svg')), '| status', await scr.textContent('#statusText'));
await scr.screenshot({ path: OUT + '/remote-screen.png' });
const ph = await mk('phone', { width: 390, height: 844 });
await ph.goto('http://localhost:8765/?r=' + code);   // as if the QR code was scanned
try { await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 }); } catch (e) { console.log('PHONE STATUS:', await ph.textContent('#remoteStatus'), '| screen status', await scr.textContent('#screenStatus')); throw e; }
console.log('phone:', await ph.textContent('#remoteStatus'));
await ph.click('#bRemoteMic');
await ph.waitForTimeout(1500);
console.log('screen status:', await scr.textContent('#statusText'));
// phone picks a scene + palette + message → screen follows
await ph.click('#remoteClose');
await ph.click('#bScenes'); await ph.click('#scenePicks [data-scene="disco"]');
await ph.click('#bPal'); await ph.click('[data-pal="feu"]'); await ph.click('#palClose');
await ph.waitForTimeout(2500);
console.log('screen label:', await scr.textContent('#bScenes'), '| screen palette:', await scr.textContent('#bPal'));
await scr.keyboard.press('Escape'); await scr.waitForTimeout(5000);
await scr.screenshot({ path: OUT + '/remote-screen-live.png' });
// screen draws from the phone's frames: meters move?
const m1 = await scr.$eval('#mBass', e => e.style.transform); await scr.waitForTimeout(300); const m2 = await scr.$eval('#mBass', e => e.style.transform);
console.log('screen bass meter', m1, m2);
await ph.mouse.move(20,20); await ph.mouse.move(30,30); await ph.click('#bMore'); await ph.click('#bRemote'); await ph.click('#bDisconnect'); await scr.waitForTimeout(1500);
console.log('after disconnect, screen:', await scr.textContent('#screenStatus'));
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
