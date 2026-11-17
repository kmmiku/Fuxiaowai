'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PORT = Number(process.env.FXW_DOWNLOAD_PORT || 18080);
const BIND = process.env.FXW_DOWNLOAD_BIND || '0.0.0.0';
const assets = new Map([
  ['/', { file: 'index.html', type: 'text/html; charset=utf-8' }],
  ['/index.html', { file: 'index.html', type: 'text/html; charset=utf-8' }],
  ['/icon.png', { file: 'icon.png', type: 'image/png' }],
  ['/android-logo.jpg', { file: 'android-logo.jpg', type: 'image/jpeg' }],
  ['/harmony-logo.jpg', { file: 'harmony-logo.jpg', type: 'image/jpeg' }]
]);

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD', 'X-Content-Type-Options': 'nosniff' });
    res.end();
    return;
  }

  let pathname;
  try {
    pathname = new URL(req.url, 'http://localhost').pathname;
  } catch {
    res.writeHead(400, { 'X-Content-Type-Options': 'nosniff' });
    res.end();
    return;
  }

  const asset = assets.get(pathname);
  if (!asset) {
    res.writeHead(404, { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end('Not Found');
    return;
  }

  fs.readFile(path.join(__dirname, asset.file), (error, body) => {
    if (error) {
      res.writeHead(500, { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      res.end('Unavailable');
      return;
    }
    res.writeHead(200, {
      'Content-Type': asset.type,
      'Content-Length': body.length,
      'Cache-Control': asset.file === 'index.html' ? 'no-store' : 'public, max-age=86400',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer'
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  });
});

server.listen(PORT, BIND, () => {
  process.stdout.write(`Download center listening on port ${PORT}\n`);
});

server.on('error', (error) => {
  process.stderr.write(`Download center failed to start (${error.code || 'unknown error'})\n`);
  process.exitCode = 1;
});
