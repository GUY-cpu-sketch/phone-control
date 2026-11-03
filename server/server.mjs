import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
app.use(express.static(path.join(__dirname, '../web')));
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

let phone = null;
let phoneCode = null;
const viewers = new Map();

const newCode = () => String(Math.floor(100000 + Math.random() * 900000));
const sendJSON = (ws, value) => ws?.readyState === 1 && ws.send(JSON.stringify(value));

wss.on('connection', ws => {
  ws.on('message', (raw, isBinary) => {
    if (isBinary) {
      for (const viewer of viewers.values()) if (viewer.readyState === 1) viewer.send(raw, { binary: true });
      return;
    }

    let message;
    try { message = JSON.parse(raw.toString()); } catch { return; }

    if (message.type === 'hello' && message.role === 'device') {
      if (phone && phone.readyState === 1) phone.close();
      phone = ws;
      phoneCode = newCode();
      phone.role = 'phone';
      sendJSON(phone, { type: 'welcome', pairingCode: phoneCode });
      for (const viewer of viewers.values()) sendJSON(viewer, { type: 'device-online' });
      return;
    }

    if (message.type === 'pair') {
      if (message.code && message.code === phoneCode && phone?.readyState === 1) {
        ws.role = 'viewer';
        viewers.set(ws, ws);
        sendJSON(ws, { type: 'paired' });
        sendJSON(phone, { type: 'viewer-connected' });
      } else {
        sendJSON(ws, { type: 'error', message: 'Invalid pairing code or phone offline.' });
      }
      return;
    }

    if (message.type === 'command' && ws.role === 'viewer' && viewers.has(ws) && phone?.readyState === 1) {
      sendJSON(phone, message);
    }

    if (message.type === 'browser-state' && ws.role === 'phone') {
      for (const viewer of viewers.values()) sendJSON(viewer, message);
    }
  });

  ws.on('close', () => {
    if (phone === ws) {
      phone = null;
      phoneCode = null;
      for (const viewer of viewers.values()) sendJSON(viewer, { type: 'device-offline' });
    }
    viewers.delete(ws);
  });
});

const port = process.env.PORT || 8787;
server.listen(port, () => console.log(`Phone Control listening on ${port}`));
