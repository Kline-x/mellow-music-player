import fs from 'fs';
import path from 'path';
import puppeteer from 'puppeteer-core';

const candidates = [
  process.env.CHROME_PATH,
  process.env.PUPPETEER_EXECUTABLE_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'
].filter(Boolean);

const browserPath = candidates.find(p => fs.existsSync(p));
console.log(`[Full Audit] Using browser: ${browserPath}`);

const BASE_URL = 'http://localhost:8088';
const OUT_DIR = path.resolve('docs/evidence/web-desktop-audit');
fs.mkdirSync(OUT_DIR, { recursive: true });

async function runAudit() {
  const browser = await puppeteer.launch({
    executablePath: browserPath,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--autoplay-policy=no-user-gesture-required']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 2 });

  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 1000));

  // 1. 发现音乐首页 (浅色)
  await page.screenshot({ path: path.join(OUT_DIR, '01_discover_light.png') });
  console.log('📸 01_discover_light.png');

  // 2. 点击播放一首音乐
  await page.click('#playPauseBtn');
  await new Promise(r => setTimeout(r, 800));
  await page.screenshot({ path: path.join(OUT_DIR, '02_discover_playing.png') });
  console.log('📸 02_discover_playing.png');

  // 3. 打开 ⌘K 搜索下拉框
  await page.click('#searchInput');
  await page.type('#searchInput', '周杰伦');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '03_search_dropdown.png') });
  console.log('📸 03_search_dropdown.png');

  // 清除搜索并按 Esc
  await page.keyboard.press('Escape');
  await new Promise(r => setTimeout(r, 300));

  // 4. 歌单广场
  await page.click('[data-nav="playlists"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '04_playlists.png') });
  console.log('📸 04_playlists.png');

  // 5. 巅峰排行榜
  await page.click('[data-nav="toplist"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '05_toplist.png') });
  console.log('📸 05_toplist.png');

  // 6. 热门歌手
  await page.click('[data-nav="artists"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '06_artists.png') });
  console.log('📸 06_artists.png');

  // 7. 歌手详情页 (点击周杰伦卡片)
  await page.click('#artistsFullGrid .soft-card:first-child');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '07_artist_detail.png') });
  console.log('📸 07_artist_detail.png');

  // 返回歌手列表
  await page.click('button[onclick*="backToArtists()"]');
  await new Promise(r => setTimeout(r, 300));

  // 8. 我喜欢的音乐
  await page.click('[data-nav="favorite"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '08_favorites.png') });
  console.log('📸 08_favorites.png');

  // 9. 本地与下载
  await page.click('[data-nav="local"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '09_local.png') });
  console.log('📸 09_local.png');

  // 10. 个性化设置
  await page.click('#settingsBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '10_settings.png') });
  console.log('📸 10_settings.png');
  await page.click('#viewSettings button[onclick*="backToDiscover"]');
  await new Promise(r => setTimeout(r, 300));

  // 11. 巨幕全屏歌词 (点击底栏封面)
  await page.click('#dockCover');
  await new Promise(r => setTimeout(r, 800));
  await page.screenshot({ path: path.join(OUT_DIR, '11_fullscreen_lyrics.png') });
  console.log('📸 11_fullscreen_lyrics.png');

  // 退出巨幕全屏歌词
  await page.keyboard.press('Escape');
  await new Promise(r => setTimeout(r, 500));

  // 12. EQ 模态框 (通过点击声波条)
  await page.click('.dock-eq-bars');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '12_modal_eq.png') });
  console.log('📸 12_modal_eq.png');

  // 关闭 EQ
  await page.click('button[onclick*="closeEqModal"]');
  await new Promise(r => setTimeout(r, 300));

  // 13. 睡眠定时器模态框
  await page.click('#sleepTimerBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '13_modal_sleep_timer.png') });
  console.log('📸 13_modal_sleep_timer.png');

  // 关闭睡眠定时器
  await page.keyboard.press('Escape');
  await new Promise(r => setTimeout(r, 300));

  // 14. 播放队列抽屉
  await page.click('#queueBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '14_drawer_queue.png') });
  console.log('📸 14_drawer_queue.png');

  // 关闭抽屉
  await page.click('#queueDrawer button[onclick*="toggleQueueDrawer"]');
  await new Promise(r => setTimeout(r, 300));

  // 15. 切换深色模式
  await page.click('#themeToggleBtn');
  await new Promise(r => setTimeout(r, 600));
  await page.screenshot({ path: path.join(OUT_DIR, '15_discover_dark.png') });
  console.log('📸 15_discover_dark.png');

  await browser.close();
  console.log('\n🎉 Web Desktop All 15 Visual Frames Captured Successfully!');
}

runAudit().catch(err => {
  console.error('Audit failed:', err);
  process.exit(1);
});
