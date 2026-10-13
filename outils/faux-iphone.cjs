// Fake iPhone: speaks raw MQTT 3.1.1 over a WebSocket exactly like MQTTLink.swift does
// (CONNECT, then QoS 0 PUBLISH of JSON frames ~22/s, PINGREQ), so the byte format is checked end to end.
const WebSocket = require('ws');
const [, , url, code, seconds] = process.argv;
const rl = (n) => { const o = []; do { let b = n % 128; n = Math.floor(n / 128); if (n > 0) b |= 0x80; o.push(b); } while (n > 0); return o; };
const str = (s) => { const u = [...Buffer.from(s, 'utf8')]; return [u.length >> 8, u.length & 255, ...u]; };
const connectPkt = (id) => { const vh = [...str('MQTT'), 4, 2, 0, 60]; const pl = str(id); return Buffer.from([0x10, ...rl(vh.length + pl.length), ...vh, ...pl]); };
const publishPkt = (topic, payload) => { const body = [...str(topic), ...Buffer.from(payload, 'utf8')]; return Buffer.from([0x30, ...rl(body.length), ...body]); };
const sock = new WebSocket(url, ['mqtt']);
let ready = false, t0 = Date.now(), n = 0;
sock.on('open', () => sock.send(connectPkt('jdl-ios-test1234')));
sock.on('message', (d) => { if (d[0] === 0x20 && d[3] === 0) { ready = true; console.log('CONNACK ok'); } });
const r2 = (x) => Math.round(x * 100) / 100;
const timer = setInterval(() => {
  if (!ready) return;
  const t = (Date.now() - t0) / 1000, ph = (t * 124 / 60) % 1, k = Math.exp(-ph * 6);
  const ts = Array.from({ length: 48 }, (_, j) => r2(Math.max(0, (0.9 - j / 60) * (0.4 + 0.6 * k * Math.exp(-j / 10)))));
  const wv = Array.from({ length: 64 }, (_, i) => r2(Math.sin(i / 64 * Math.PI * 6 + t * 5) * (0.3 + 0.6 * k)));
  const f = { t: 'f', tb: r2(0.25 + 0.7 * k), tm: r2(0.5), th: r2(0.3 + 0.2 * Math.sin(t * 3)), loud: r2(0.8), ts, wv, beat: ph < 0.05 };
  sock.send(publishPkt('jeux-de-lumiere/v1/' + code, JSON.stringify(f))); n++;
  if (t > Number(seconds || 8)) { console.log('sent', n, 'frames; bytes/frame', JSON.stringify(f).length); sock.send(Buffer.from([0xe0, 0])); sock.close(); clearInterval(timer); }
}, 45);
setInterval(() => { if (ready) sock.send(Buffer.from([0xc0, 0])); }, 25000).unref();
