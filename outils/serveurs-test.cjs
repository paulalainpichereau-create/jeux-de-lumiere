// Les trois serveurs locaux pour développer et tester sans dépendre des services publics :
//   - l'appli elle-même          http://localhost:8765/
//   - un relais PeerJS            127.0.0.1:9000  (remplace 0.peerjs.com)
//   - un relais MQTT WebSocket    ws://127.0.0.1:8884/mqtt (remplace broker.emqx.io)
// L'appli utilise ces relais quand la page définit window.JDL_PEER et window.JDL_MQTT (ce que font les tests).
const http = require('http');
const fs = require('fs');
const path = require('path');
const express = require('express');
const { ExpressPeerServer } = require('peer');
const aedes = require('aedes')();
const wsStream = require('websocket-stream');

const ROOT = path.resolve(__dirname, '..');
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.json': 'application/json',
  '.webmanifest': 'application/manifest+json', '.png': 'image/png', '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8' };

http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); res.end('404'); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(f).pipe(res);
}).listen(8765, '127.0.0.1', () => console.log('appli   http://localhost:8765/'));

const app = express();
const peerServer = http.createServer(app);
app.use('/', ExpressPeerServer(peerServer, { path: '/' }));
peerServer.listen(9000, '127.0.0.1', () => console.log('PeerJS  127.0.0.1:9000'));

const mq = http.createServer();
wsStream.createServer({ server: mq, path: '/mqtt' }, aedes.handle);
mq.listen(8884, '127.0.0.1', () => console.log('MQTT    ws://127.0.0.1:8884/mqtt'));
