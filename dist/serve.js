// Servidor estático mínimo para probar el build web de love.js localmente.
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'web');
const types = {
  '.html': 'text/html',
  '.js':   'application/javascript',
  '.wasm': 'application/wasm',
  '.data': 'application/octet-stream',
  '.css':  'text/css',
  '.png':  'image/png',
};

http.createServer((req, res) => {
  let url = req.url === '/' ? '/index.html' : req.url.split('?')[0];
  const fp = path.join(root, decodeURIComponent(url));
  fs.readFile(fp, (err, data) => {
    if (err) { res.writeHead(404); res.end('404'); return; }
    // Headers COOP/COEP por si se sirve la versión no-compat (SharedArrayBuffer)
    res.writeHead(200, {
      'Content-Type': types[path.extname(fp)] || 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    res.end(data);
  });
}).listen(8000, () => console.log('Hell Farm web build -> http://localhost:8000'));
