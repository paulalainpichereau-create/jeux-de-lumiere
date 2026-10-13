// Test de bout en bout : messages invites. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'] });
const errs = [];
const mk = async (name, vp, mobile) => { const c = await b.newContext({ viewport: vp, permissions: ['microphone'], isMobile: !!mobile, hasTouch: !!mobile });
  await c.addInitScript(() => { try { localStorage.setItem('jdl.welcomed', '1'); } catch (e) {} window.JDL_PEER = { host: '127.0.0.1', port: 9000, path: '/', secure: false, config: { iceServers: [] } }; window.JDL_MQTT = 'ws://127.0.0.1:8884/mqtt'; });
  const p = await c.newPage(); p.on('pageerror', e => errs.push(name + ': ' + e.message));
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.route(/cdn\.jsdelivr\.net/, r => { const u = r.request().url(); const f = u.includes('peerjs') ? 'peerjs.min.js' : u.includes('qrcode') ? 'qrcode.js' : u.includes('mqtt') ? 'mqtt.min.js' : u.includes('Presets') ? 'butterchurnPresets.min.js' : 'butterchurn.min.js'; r.fulfill({ path: ROOT + '/vendor/' + f, contentType: 'application/javascript' }); });
  return p; };
const tv = await mk('tv', { width: 1280, height: 720 });
await tv.goto('http://localhost:8765/');
await tv.click('#bMore'); await tv.click('#bRemote'); await tv.click('#bBeScreen');
await tv.waitForFunction(() => /^[A-Z0-9]{5}$/.test(document.getElementById('screenCode').textContent));
const code = await tv.textContent('#screenCode');
const tab = await mk('tablet', { width: 1024, height: 768 });
await tab.goto('http://localhost:8765/?ecran=' + code);
const ph = await mk('phone', { width: 390, height: 844 }, true);
await ph.goto('http://localhost:8765/?r=' + code);
await ph.waitForFunction(() => document.getElementById('remoteStatus').textContent.startsWith('Connecté'), null, { timeout: 20000 });
await ph.keyboard.press('Escape'); await ph.click('#bSource'); await ph.click('#bDemo'); await ph.waitForTimeout(600);
console.log('tv qr before:', await tv.$eval('#guestQr', e => !e.hidden));
await ph.click('#bMore'); await ph.click('#bOpts'); await ph.check('#guestOn'); await ph.waitForTimeout(2500);
console.log('phone guest box:', await ph.$eval('#guestBox', e => !e.hidden), '| phone corner qr hidden:', await ph.$eval('#guestQr', e => e.hidden));
await ph.screenshot({ path: OUT + '/guest-host-phone.png' });
await tv.keyboard.press('Escape'); await tab.waitForTimeout(500);
console.log('tv corner qr:', await tv.$eval('#guestQr', e => !e.hidden), '| tablet corner qr:', await tab.$eval('#guestQr', e => !e.hidden));
const url = 'http://localhost:8765/?invite=' + code;
// guest 1
const g1 = await mk('guest1', { width: 390, height: 844 }, true);
await g1.goto(url); await g1.waitForTimeout(1200);
console.log('guest page:', await g1.$eval('#guestPage', e => !e.hidden), '| deck hidden:', await g1.$eval('.deck', e => getComputedStyle(e).display === 'none'), '| welcome hidden:', await g1.$eval('#welcome', e => e.hidden));
await g1.fill('#gName', 'Camille'); await g1.fill('#gText', 'Joyeux anniversaire Marie !'); 
await g1.screenshot({ path: OUT + '/guest-page.png' });
await g1.click('#gSend'); await g1.waitForTimeout(300);
console.log('guest1:', await g1.textContent('#gStatus'), '|', await g1.textContent('#gSend'));
await tv.waitForTimeout(1200);
console.log('tv shows:', await tv.$eval('#guestWall', e => e.textContent), '| tablet shows:', await tab.$eval('#guestWall', e => e.textContent));
await tv.screenshot({ path: OUT + '/guest-tv.png' });
// emoji + insult + link + too fast
for (let i = 0; i < 3; i++) { await g1.click('#gEmojis button >> nth=0'); await g1.waitForTimeout(900); }
console.log('tv emoji bursts:', await tv.$eval('#guestFx', e => e.childElementCount));
await tv.waitForTimeout(400); await tv.screenshot({ path: OUT + '/guest-tv-emoji.png' });
const g2 = await mk('guest2', { width: 390, height: 844 }, true);
await g2.goto(url); await g2.waitForTimeout(1200);
await g2.fill('#gText', 't es un connard'); await g2.click('#gSend'); console.log('guest2 insult:', await g2.textContent('#gStatus'));
// bypass the guest page check: publish straight to the relay (a guest with an old or modified page)
await g2.evaluate(async (code) => { const c = window.mqtt.connect(window.JDL_MQTT); await new Promise(r => c.on('connect', r));
  c.publish('jeux-de-lumiere/v1/' + code + '/m', JSON.stringify({ t: 'msg', id: 'zz1', text: 'Va voir www.arnaque.fr', name: 'Spam' }));
  c.publish('jeux-de-lumiere/v1/' + code + '/m', JSON.stringify({ t: 'msg', id: 'zz2', text: 'Quelle CONNASSE', name: 'X' }));
  c.publish('jeux-de-lumiere/v1/' + code + '/m', JSON.stringify({ t: 'msg', id: 'zz3', text: 'Premier', name: 'Léo' }));
  c.publish('jeux-de-lumiere/v1/' + code + '/m', JSON.stringify({ t: 'msg', id: 'zz3', text: 'Deuxième trop vite', name: 'Léo' }));
}, code);
await g2.fill('#gText', 'On danse !'); await g2.fill('#gName', 'Sam'); await g2.click('#gSend');
// collect what the TV shows over 30 s
const seen = new Set();
for (let i = 0; i < 34; i++) { const t = await tv.$eval('#guestWall', e => e.textContent); if (t) seen.add(t); await tv.waitForTimeout(1000); }
console.log('tv sequence:', [...seen].join(' → '));
await ph.click('#guestClear'); await tv.waitForTimeout(800);
console.log('after clear:', JSON.stringify(await tv.$eval('#guestWall', e => e.textContent)));
await ph.uncheck('#guestOn'); await tv.waitForTimeout(2500);
console.log('turned off → tv corner qr hidden:', await tv.$eval('#guestQr', e => e.hidden), '| tablet:', await tab.$eval('#guestQr', e => e.hidden));
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
