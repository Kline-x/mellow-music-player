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
console.log(`[Mobile Audit] Using browser: ${browserPath}`);

const BASE_URL = 'http://localhost:8088/mobile.html';
const OUT_DIR = path.resolve('docs/evidence/web-mobile-audit');
fs.mkdirSync(OUT_DIR, { recursive: true });

async function runMobileAudit() {
  const browser = await puppeteer.launch({
    executablePath: browserPath,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--autoplay-policy=no-user-gesture-required']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });

  await page.goto(BASE_URL, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 1000));

  // 1. 移动端发现主页
  await page.screenshot({ path: path.join(OUT_DIR, '01_mobile_discover.png') });
  console.log('📸 01_mobile_discover.png');

  // 2. 每日推荐二级页
  await page.click('[onclick*="openMobileDailyRecommend()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '02_mobile_daily_recommend.png') });
  console.log('📸 02_mobile_daily_recommend.png');
  await page.click('#mViewDailyRecommend button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 3. 歌单广场二级页
  await page.click('[onclick*="openMobilePlaylistSquare()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '03_mobile_playlists_square.png') });
  console.log('📸 03_mobile_playlists_square.png');
  await page.click('#mViewPlaylistSquare button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 4. 排行榜二级页
  await page.click('[onclick*="openMobileToplist()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '04_mobile_toplist.png') });
  console.log('📸 04_mobile_toplist.png');
  await page.click('#mViewToplist button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 5. 声音电台二级页
  await page.click('[onclick*="openMobileRadio()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '05_mobile_radio.png') });
  console.log('📸 05_mobile_radio.png');
  await page.click('#mViewRadio button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 6. 私人 FM 二级页
  await page.click('[onclick*="openMobilePersonalFM()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '06_mobile_fm.png') });
  console.log('📸 06_mobile_fm.png');
  await page.click('#mViewPersonalFM button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 7. Tab 2: 探索全库
  await page.click('#mTabExplore');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '07_mobile_explore.png') });
  console.log('📸 07_mobile_explore.png');

  // 8. Tab 3: 我的资料库
  await page.click('#mTabLibrary');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '08_mobile_library.png') });
  console.log('📸 08_mobile_library.png');

  // 9. 资料库下级: 本地与下载
  await page.click('div[onclick*="openMobileLocal()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '09_mobile_local_music.png') });
  console.log('📸 09_mobile_local_music.png');
  await page.click('#mViewLocal button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 10. 资料库下级: 热门歌手与歌手主页
  await page.click('div[onclick*="openMobileArtists()"]');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '10_mobile_artists.png') });
  console.log('📸 10_mobile_artists.png');

  // 点击周杰伦卡片进入详情
  await page.click('#mArtistsGrid > div:first-child');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '11_mobile_artist_detail.png') });
  console.log('📸 11_mobile_artist_detail.png');
  await page.click('button[onclick*="closeMobileArtistDetail()"]');
  await new Promise(r => setTimeout(r, 300));
  await page.click('#mViewArtists button[onclick*="closeMobileSubView()"]');
  await new Promise(r => setTimeout(r, 300));

  // 12. Tab 4: 个人中心与设置
  await page.click('#mTabProfile');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '12_mobile_profile.png') });
  console.log('📸 12_mobile_profile.png');

  // 13. 返回发现页并打开全屏播放器
  await page.click('#mTabDiscover');
  await new Promise(r => setTimeout(r, 300));
  await page.click('#miniPlayerDock');
  await new Promise(r => setTimeout(r, 600));
  await page.screenshot({ path: path.join(OUT_DIR, '13_mobile_fullscreen_player.png') });
  console.log('📸 13_mobile_fullscreen_player.png');

  // 14. 切换到全屏纯字歌词大幕
  await page.click('#mModeToggleBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '14_mobile_fullscreen_lyrics.png') });
  console.log('📸 14_mobile_fullscreen_lyrics.png');

  // 切回黑胶
  await page.click('#mModeToggleBtn');
  await new Promise(r => setTimeout(r, 300));

  // 15. 打开播放队列底部抽屉
  await page.click('#mQueueBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '15_mobile_queue_sheet.png') });
  console.log('📸 15_mobile_queue_sheet.png');
  await page.click('#mQueueSheet button[onclick*="closeMobileQueue"]');
  await new Promise(r => setTimeout(r, 300));

  // 16. 打开 EQ 模态框
  await page.click('#mEqBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '16_mobile_eq_modal.png') });
  console.log('📸 16_mobile_eq_modal.png');
  await page.click('#mEqModal button[onclick*="closeMobileEqModal"]');
  await new Promise(r => setTimeout(r, 300));

  // 17. 打开睡眠定时器模态框
  await page.click('#mSleepTimerBtn');
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT_DIR, '17_mobile_sleep_timer.png') });
  console.log('📸 17_mobile_sleep_timer.png');
  await page.click('#mSleepTimerModal button[onclick*="closeMobileSleepTimer"]');
  await new Promise(r => setTimeout(r, 300));

  // 关闭全屏播放器
  await page.click('#mFullLyrics button[onclick*="closeFullscreenLyrics"]');
  await new Promise(r => setTimeout(r, 400));

  // 18. 切换深色模式
  await page.click('button[onclick*="toggleTheme()"]');
  await new Promise(r => setTimeout(r, 600));
  await page.screenshot({ path: path.join(OUT_DIR, '18_mobile_discover_dark.png') });
  console.log('📸 18_mobile_discover_dark.png');

  await browser.close();
  console.log('\n🎉 Web Mobile All 18 Visual Frames Captured Successfully!');
}

runMobileAudit().catch(err => {
  console.error('Mobile audit failed:', err);
  process.exit(1);
});
