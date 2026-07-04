#!/usr/bin/env node
/* ===========================================================================
 * Self-contained jsmpeg websocket relay (no external npm deps).
 *
 * Usage:  node websocket-relay.js <secret> <ingestPort> <wsPort>
 *
 *   ffmpeg POSTs an MPEG-TS stream to  http://127.0.0.1:<ingestPort>/<secret>
 *   browsers connect a WebSocket to    ws://0.0.0.0:<wsPort>/   (any path)
 *
 * Each ingest chunk is fanned out to every connected websocket client as a
 * binary frame, which the browser's JSMpeg.Player decodes and plays. This is
 * the same design as Dominic Szablewski's jsmpeg websocket-relay, reimplemented
 * on Node's built-in net/http/crypto so the workspace image needs no npm.
 * =========================================================================== */
'use strict';
const http = require('http');
const net  = require('net');
const crypto = require('crypto');

const SECRET    = process.argv[2] || 'secret';
const HTTP_PORT = parseInt(process.argv[3] || '8081', 10);
const WS_PORT   = parseInt(process.argv[4] || '4901', 10);
const WS_GUID   = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/* ---- minimal websocket server ---- */
const clients = new Set();

function wsHandshake(socket, key) {
  const accept = crypto.createHash('sha1')
    .update(key + WS_GUID).digest('base64');
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
    'Upgrade: websocket\r\n' +
    'Connection: Upgrade\r\n' +
    'Sec-WebSocket-Accept: ' + accept + '\r\n\r\n'
  );
}

// Build a binary (opcode 0x2) frame, unmasked (server->client).
function wsFrame(payload) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x82, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x82; header[1] = 126; header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x82; header[1] = 127;
    header.writeUInt32BE(Math.floor(len / 4294967296), 2);
    header.writeUInt32BE(len >>> 0, 6);
  }
  return Buffer.concat([header, payload]);
}

const wsServer = http.createServer();
wsServer.on('upgrade', (req, socket) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) { socket.destroy(); return; }
  wsHandshake(socket, key);
  socket.on('error', () => {});
  clients.add(socket);
  socket.on('close', () => clients.delete(socket));
  socket.on('end', () => clients.delete(socket));
});
wsServer.listen(WS_PORT, '0.0.0.0', () =>
  console.log('[audio-relay] websocket listening on :' + WS_PORT));

function broadcast(chunk) {
  if (!clients.size) return;
  const frame = wsFrame(chunk);
  for (const c of clients) {
    if (c.writable) { try { c.write(frame); } catch (_) { clients.delete(c); } }
  }
}

/* ---- ingest server (ffmpeg POSTs MPEG-TS here) ---- */
http.createServer((req, res) => {
  if (req.url !== '/' + SECRET) {
    res.writeHead(403); res.end('forbidden'); return;
  }
  console.log('[audio-relay] ingest stream connected');
  req.on('data', broadcast);
  req.on('end', () => console.log('[audio-relay] ingest stream ended'));
}).listen(HTTP_PORT, '127.0.0.1', () =>
  console.log('[audio-relay] ingest listening on 127.0.0.1:' + HTTP_PORT));
