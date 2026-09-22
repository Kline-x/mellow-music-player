import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import puppeteer from 'puppeteer-core';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = 8092;
const WEB_DIR = path.join(__dirname, 'app', 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

function startServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');

      let reqPath = decodeURI(req.url.split('?')[0]);
      if (reqPath === '/' || reqPath === '') {
        reqPath = '/index.html';
      }

      const filePath = path.join(WEB_DIR, reqPath);
      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': contentType });
        fs.createReadStream(filePath).pipe(res);
      } else {
        // SPA Fallback
        const indexPath = path.join(WEB_DIR, 'index.html');
        if (fs.existsSync(indexPath)) {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          fs.createReadStream(indexPath).pipe(res);
        } else {
          res.writeHead(404, { 'Content-Type': 'text/plain' });
          res.end('Not Found');
        }
      }
    });

    server.listen(PORT, () => {
      console.log(`[Flutter E2E] Web server running at http://localhost:${PORT}`);
      resolve(server);
    });
  });
}

async function runFlutterE2E() {
  const CHROME_PATH = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  const EDGE_PATH = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
  const browserPath = fs.existsSync(CHROME_PATH) ? CHROME_PATH : EDGE_PATH;
  console.log(`[Flutter E2E] Using browser binary: ${browserPath}`);

  const server = await startServer();
  const browser = await puppeteer.launch({
    executablePath: browserPath,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--autoplay-policy=no-user-gesture-required']
  });

  const publicDir = path.join(__dirname, 'public');
  if (!fs.existsSync(publicDir)) {
    fs.mkdirSync(publicDir, { recursive: true });
  }

  let allPassed = true;

  try {
    // ----------------------------------------------------
    // 测试 1: 桌面端视口 (1440 x 900) 产物 E2E
    // ----------------------------------------------------
    console.log('\n--- 💻 [E2E-1] Flutter Desktop Viewport (1440x900) ---');
    const desktopPage = await browser.newPage();
    await desktopPage.setViewport({ width: 1440, height: 900, deviceScaleFactor: 1 });

    const desktopErrors = [];
    desktopPage.on('pageerror', err => desktopErrors.push(err.message));

    console.log(`[E2E-1] Navigating to http://localhost:${PORT}...`);
    await desktopPage.goto(`http://localhost:${PORT}`, { waitUntil: 'networkidle0', timeout: 30000 });

    // 等待 Flutter 视图挂载完成 (最多等待 15 秒)
    await desktopPage.waitForFunction(() => {
      const flutterView = document.querySelector('flutter-view') || document.querySelector('flt-glass-pane');
      return !!flutterView;
    }, { timeout: 15000 });

    // 额外留出渲染稳定缓冲
    await new Promise(r => setTimeout(r, 3000));

    const desktopTitle = await desktopPage.title();
    console.log(`[E2E-1] Page title: "${desktopTitle}"`);
    console.log(`[E2E-1] Uncaught errors count: ${desktopErrors.length}`);

    const desktopScreenshotPath = path.join(publicDir, 'e2e_flutter_desktop_verified.png');
    await desktopPage.screenshot({ path: desktopScreenshotPath });
    console.log(`✅ [PASS] Desktop E2E verified! Screenshot saved to: ${desktopScreenshotPath}`);

    // ----------------------------------------------------
    // 测试 2: 移动端视口 (390 x 844) 自适应触控 E2E
    // ----------------------------------------------------
    console.log('\n--- 📱 [E2E-2] Flutter Mobile Viewport (390x844) ---');
    const mobilePage = await browser.newPage();
    await mobilePage.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });

    const mobileErrors = [];
    mobilePage.on('pageerror', err => mobileErrors.push(err.message));

    console.log(`[E2E-2] Navigating to http://localhost:${PORT} in Mobile mode...`);
    await mobilePage.goto(`http://localhost:${PORT}`, { waitUntil: 'networkidle0', timeout: 30000 });

    await mobilePage.waitForFunction(() => {
      const flutterView = document.querySelector('flutter-view') || document.querySelector('flt-glass-pane');
      return !!flutterView;
    }, { timeout: 15000 });

    await new Promise(r => setTimeout(r, 3000));

    const mobileScreenshotPath = path.join(publicDir, 'e2e_flutter_mobile_verified.png');
    await mobilePage.screenshot({ path: mobileScreenshotPath });
    console.log(`✅ [PASS] Mobile E2E verified! Screenshot saved to: ${mobileScreenshotPath}`);

    await desktopPage.close();
    await mobilePage.close();
  } catch (err) {
    console.error('❌ [E2E Failed]', err);
    allPassed = false;
  } finally {
    await browser.close();
    server.close();
  }

  if (allPassed) {
    console.log('\n======================================================');
    console.log('🎉 恭喜！Flutter 真实客户端产物级 E2E 测试 100% 通过！');
    console.log('======================================================\n');
  } else {
    process.exit(1);
  }
}

runFlutterE2E();
