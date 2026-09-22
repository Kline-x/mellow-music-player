const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8088;
const ROOT = path.resolve(__dirname);
const PUBLIC_DIR = path.join(ROOT, 'public');
const ALLOWED_ROOT_FILES = new Set(['/index.html', '/mobile.html', '/design_tokens.css', '/favicon.ico']);
const DENY = ['.git', 'node_modules', '.github', '.qa', 'release_windows', 'build', 'app', 'docs', '.claude'];

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.cjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4'
};

function safeResolve(rawPath) {
  if (rawPath.includes('\0')) return null;

  const normalized = path.posix.normalize('/' + rawPath.replace(/\\/g, '/'));

  // 1. 允许访问根目录指定的几个前端入口文件
  if (ALLOWED_ROOT_FILES.has(normalized)) {
    return path.join(ROOT, normalized);
  }

  // 2. 其余所有请求仅允许定位到 public 目录下
  let relPublic = normalized;
  if (relPublic.startsWith('/public/')) {
    relPublic = relPublic.slice('/public'.length);
  }
  const absPublic = path.resolve(PUBLIC_DIR, '.' + relPublic);

  // 严格确保处于 PUBLIC_DIR 内，且不匹配拒绝黑名单
  if (!absPublic.startsWith(PUBLIC_DIR)) return null;

  const segs = path.relative(PUBLIC_DIR, absPublic).split(path.sep);
  if (segs.some((s) => s.startsWith('.') || DENY.includes(s))) return null;

  return absPublic;
}

const server = http.createServer(async (req, res) => {
  try {
    if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      res.writeHead(405, { 'Content-Type': 'text/plain; charset=utf-8', Allow: 'GET, HEAD, OPTIONS' });
      return res.end('405 Method Not Allowed');
    }

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Type'
      });
      return res.end();
    }

    // 严格路径穿越与非法编码检查
    const rawUrl = req.url || '';
    if (rawUrl.includes('..') || /%2e/i.test(rawUrl) || /\\/.test(rawUrl)) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('403 Forbidden');
    }

    let reqPath;
    try {
      reqPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    } catch {
      res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('400 Bad Request');
    }

    if (reqPath.includes('..')) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('403 Forbidden');
    }

    if (reqPath === '/' || reqPath === '') {
      reqPath = '/index.html';
    }

    const filePath = safeResolve(reqPath);
    if (!filePath) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('403 Forbidden');
    }

    let stats;
    try {
      stats = await fs.promises.stat(filePath);
    } catch {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('404 Not Found');
    }

    if (!stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('404 Not Found');
    }

    const total = stats.size;
    const type = MIME_TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
    const head = { 'Content-Type': type, 'Accept-Ranges': 'bytes' };

    const range = req.headers.range;
    const m = range && !String(range).includes(',') ? /^bytes=(\d*)-(\d*)$/.exec(String(range)) : null;

    if (!m) {
      res.writeHead(200, { ...head, 'Content-Length': total });
      if (req.method === 'HEAD') return res.end();
      const s = fs.createReadStream(filePath);
      s.on('error', () => res.destroy());
      return s.pipe(res);
    }

    const [, a, b] = m;
    let start, end;
    if (a === '') {
      const n = Number(b);
      start = Number.isInteger(n) && n > 0 ? Math.max(0, total - n) : NaN;
      end = total - 1;
    } else {
      start = Number(a);
      end = b === '' ? total - 1 : Number(b);
    }

    if (!Number.isInteger(start) || !Number.isInteger(end) || start > end || start >= total) {
      res.writeHead(416, { 'Content-Range': 'bytes */' + total });
      return res.end();
    }

    end = Math.min(end, total - 1);
    res.writeHead(206, {
      ...head,
      'Content-Range': `bytes ${start}-${end}/${total}`,
      'Content-Length': end - start + 1
    });

    if (req.method === 'HEAD') return res.end();
    const stream = fs.createReadStream(filePath, { start, end });
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  } catch {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('500 Internal Server Error');
  }
});

process.on('uncaughtException', (err) => console.error('[server fatal]', err));

const HOST = process.env.MELLOW_HOST === 'lan' ? '0.0.0.0' : '127.0.0.1';
server.listen(PORT, HOST, () => {
  console.log(`Server running at http://${HOST}:${PORT}/`);
});
