// Test de bout en bout : accueil et barre. Lancer d'abord « npm run serveurs » dans outils/.
const { chromium, devices } = require('playwright');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'captures');
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
const b = await chromium.launch({ args: ['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'] });
const errs = [];
for (const [name, opt] of [['phone', devices['iPhone 13']], ['tv', { viewport: { width: 1280, height: 720 } }]]) {
  const c = await b.newContext(Object.assign({ permissions: ['microphone'] }, opt)); const p = await c.newPage();
  p.on('pageerror', e => errs.push(name + ': ' + e.message));
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort());
  await p.goto('http://localhost:8765/');
  await p.waitForTimeout(600);
  console.log(name, '| welcome shown on first visit:', await p.$eval('#welcome', e => !e.hidden));
  await p.screenshot({ path: OUT + '/simple-' + name + '-1-welcome.png' });
  await p.click('[data-where="here"]');
  await p.screenshot({ path: OUT + '/simple-' + name + '-2-sound.png' });
  await p.click('[data-sound="' + (name === 'phone' ? 'mic' : 'demo') + '"]');
  await p.waitForTimeout(2500);
  console.log('  after choice: welcome hidden', await p.$eval('#welcome', e => e.hidden), '| source', await p.textContent('#bSource'), '| scene', await p.textContent('#bScenes'), '| party', await p.getAttribute('#bParty', 'aria-pressed'));
  await p.mouse.move(50, 50); await p.mouse.move(60, 60);
  await p.screenshot({ path: OUT + '/simple-' + name + '-3-bar.png' });
  await p.click('#bMore'); await p.waitForTimeout(200);
  await p.screenshot({ path: OUT + '/simple-' + name + '-4-more.png' });
  await p.click('#bRemote'); await p.waitForTimeout(200);
  console.log('  Plus › Télécommande: more closed', await p.$eval('#moreSheet', e => e.hidden), '| remote open', await p.$eval('#remoteSheet', e => !e.hidden));
  await p.keyboard.press('Escape');
  await p.click('#bSource'); await p.click('#bDemo'); await p.waitForTimeout(300);
  console.log('  source panel › démo:', await p.textContent('#bSource'), '| panel closed', await p.$eval('#srcSheet', e => e.hidden));
  await p.reload(); await p.waitForTimeout(500);
  console.log('  second visit: welcome hidden', await p.$eval('#welcome', e => e.hidden), '| scroll width ok', await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await c.close();
}
console.log('errors:', errs.length ? errs : 'none');
await b.close();
})();
