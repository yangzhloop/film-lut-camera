#!/usr/bin/env node
/* Run after build.py. Requires Playwright and an installed Chromium.
 * No application dependencies or external network access are needed. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const os = require('node:os');
const { chromium } = require('playwright');

(async () => {
  const htmlPath = path.resolve(__dirname, '../../../docs/prototype/lutli.html');
  const html = fs.readFileSync(htmlPath);
  const server = http.createServer((req, res) => {
    if (req.url === '/favicon.ico') { res.writeHead(204); res.end(); return; }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); res.end(html);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROMIUM_PATH || (fs.existsSync('/usr/bin/chromium') ? '/usr/bin/chromium' : undefined), args: ['--no-sandbox'], timeout: 20000 }).catch(error => { server.close(); throw error; });
  const screenshotDir = process.env.SCREENSHOT_DIR || path.join(os.tmpdir(), 'lutli-prototype-screenshots');
  fs.mkdirSync(screenshotDir, { recursive: true });
  const errors = [], external = [], passed = [];
  const context = await browser.newContext({ viewport: { width: 1366, height: 1000 }, acceptDownloads: true, reducedMotion: 'reduce' });
  context.on('page', page => {
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => { if (/^https?:/.test(request.url()) && !request.url().startsWith(origin)) external.push(request.url()); });
  });
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  const text = selector => page.locator(selector).textContent();
  const visible = selector => page.locator(selector).isVisible();
  const click = selector => page.locator(selector).click();
  const input = (selector, value) => page.locator(selector).evaluate((node, v) => { node.value = String(v); node.dispatchEvent(new Event('input', { bubbles: true })); }, value);
  const settle = () => page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const shot = name => page.screenshot({ path: path.join(screenshotDir, `${name}.png`), fullPage: true });
  const check = (name, condition) => { assert.ok(condition, name); passed.push(name); };
  try {
    await page.goto(origin, { waitUntil: 'load' });
    await page.locator('#scene-loading').waitFor({ state: 'hidden' });
    await settle();
    check('Startup scene renders, Original selected, diffusion Off', (await text('#filter-summary')) === 'Filters Off' && await page.locator('[data-look="original"]').getAttribute('aria-pressed') === 'true');
    await shot('01-desktop-shoot');
    const shutter = await page.locator('#shutter').boundingBox();
    await click('#filters-toggle'); await click('button[data-effect="hdf"]');
    await input('#effect-strength', 68); await click('[data-glow="amber"]'); await settle();
    const expanded = await page.locator('#shutter').boundingBox();
    check('HDF expands with stable shutter geometry', Math.abs(expanded.y - shutter.y) < 1 && await visible('#glow-controls'));
    check('Effect selection does not add button semantics to the phone container', await page.locator('#phone-screen').getAttribute('aria-pressed') === null);
    check('Strength and Amber updates are visible', await text('#effect-strength-value') === '68%' && await text('#glow-name') === 'Amber');
    await shot('02-desktop-hdf');
    await click('button[data-effect="blackMist"]');
    check('Black Mist hides HDF color controls', !await visible('#glow-controls'));
    await input('#effect-strength', 23); await click('button[data-effect="off"]');
    check('Off collapses detail controls', !await visible('#effect-details'));
    await click('button[data-effect="hdf"]');
    check('HDF amount and color survive mode switching', await text('#effect-strength-value') === '68%' && await text('#glow-name') === 'Amber');
    await input('#custom-glow', '#80bfff');
    check('Custom glow input updates the active state', await text('#glow-name') === 'Custom');
    await page.keyboard.press('Escape');
    check('Escape closes tray and restores toolbar focus', !await visible('#diffusion-tray') && await page.locator('#filters-toggle').evaluate(n => n === document.activeElement));
    await click('[data-look="warm400"]');
    check('Selecting a look retains keyboard focus on its replacement button', await page.locator('[data-look="warm400"]').evaluate(n => n === document.activeElement));
    await page.keyboard.press('ArrowRight');
    const arrowRight = await page.locator('[data-look="soft200"]').evaluate(n => n === document.activeElement && n.getAttribute('aria-pressed') === 'true');
    await page.keyboard.press('ArrowLeft');
    check('Arrow keys select and focus adjacent look labels', arrowRight && await page.locator('[data-look="warm400"]').evaluate(n => n === document.activeElement && n.getAttribute('aria-pressed') === 'true'));
    await page.locator('#look-strip').hover(); await page.mouse.wheel(0, 600);
    await page.waitForFunction(() => document.getElementById('look-strip').scrollLeft > 0);
    const stripBox = await page.locator('#look-strip').boundingBox();
    const monoBox = await page.locator('[data-look="mono800"]').boundingBox();
    check('Mouse wheel reaches the final look in the horizontal strip', monoBox.x >= stripBox.x && monoBox.x + monoBox.width <= stripBox.x + stripBox.width + 1);
    await page.mouse.wheel(0, -600);
    await page.waitForFunction(() => document.getElementById('look-strip').scrollLeft === 0);
    await input('#look-intensity', 41);
    await click('#menu-open'); await shot('03-desktop-menu'); await click('#menu-screen [data-back="camera"]');
    await click('#filters-toggle');
    check('LUT intensity and menu navigation preserve diffusion', await text('#effect-strength-value') === '68%' && await text('#glow-name') === 'Custom' && await text('#look-intensity-value') === '41%');
    await page.keyboard.press('Escape');
    await click('#ev-toggle'); await input('#ev-slider', 0.7);
    await click('#wb-toggle'); await click('[data-wb="manual"]'); await input('#temperature', 6200); await input('#tint', -10);
    check('EV and manual WB values update independently', await text('#ev-summary') === '+0.7' && await text('#wb-summary') === '6200K');
    await page.keyboard.press('Escape');

    await click('#library-open'); await click('[data-library-tab="custom"]');
    check('Empty custom library has all five slots available', await text('#slot-count') === '0 of 5 slots used' && await visible('#library-empty'));
    await click('#demo-look'); await page.locator('#top-text').fill('GOLDEN'); await page.locator('#bottom-text').fill('HOUR');
    await click('#top-palette [aria-label="Top color: Green"]');
    check('Label preview reflects text and independent color', await text('#preview-top') === 'GOLDEN' && await text('#preview-bottom') === 'HOUR' && await page.locator('#preview-top').evaluate(n => getComputedStyle(n).backgroundColor) === 'rgb(65, 107, 82)');
    await shot('04-desktop-label');
    await click('#save-label');
    check('Saving demo LUT consumes exactly one slot', await text('#slot-count') === '1 of 5 slots used');
    await click('[aria-label="Edit GOLDEN label"]'); await page.locator('#top-text').fill('NOT SAVED'); await click('#cancel-label');
    check('Dirty editor cancellation requests confirmation', await page.locator('#confirm-dialog').evaluate(n => n.open));
    await click('#confirm-accept');
    check('Discard preserves the existing label', await page.locator('[aria-label="Use GOLDEN HOUR"]').count() === 1);
    await page.locator('#lut-file').setInputFiles({ name: 'bad.cube', mimeType: 'text/plain', buffer: Buffer.from('LUT_3D_SIZE 17\n1 0 0') });
    await page.locator('#library-error').waitFor({ state: 'visible' });
    check('Invalid LUT does not consume a slot', await text('#slot-count') === '1 of 5 slots used');
    const rows = ['TITLE "Identity fixture"', 'LUT_3D_SIZE 17'];
    for (let b = 0; b < 17; b++) for (let g = 0; g < 17; g++) for (let r = 0; r < 17; r++) rows.push(`${r / 16} ${g / 16} ${b / 16}`);
    await page.locator('#lut-file').setInputFiles({ name: 'Imported.cube', mimeType: 'text/plain', buffer: Buffer.from(rows.join('\n')) });
    await page.locator('#editor-screen').waitFor({ state: 'visible' }); await click('#save-label');
    check('Actual .cube import creates a customizable look', await text('#slot-count') === '2 of 5 slots used');
    for (let i = 3; i <= 5; i++) { await click('#demo-look'); await page.locator('#top-text').fill(`LOOK${i}`); await click('#save-label'); }
    check('Capacity is enforced at five custom looks', await text('#slot-count') === '5 of 5 slots used' && await page.locator('#import-lut').isDisabled() && await page.locator('#demo-look').isDisabled());
    await click('[aria-label="Use GOLDEN HOUR"]'); await click('#library-open');
    await click('[aria-label="Delete GOLDEN"]'); await click('#confirm-accept');
    check('Deleting selected custom look frees a slot and selects Original', await text('#slot-count') === '4 of 5 slots used' && await page.locator('#look-strip [data-look="original"]').getAttribute('aria-pressed') === 'true');
    await click('#library-screen [data-back="camera"]');

    await click('#menu-open'); await click('[data-info="camera"]'); await page.getByLabel('Save clean original', { exact: true }).check(); await page.getByLabel('Grid', { exact: true }).check();
    await click('#info-screen [data-back="menu"]'); await click('#menu-screen [data-back="camera"]');
    check('Camera setting enables composition grid', await visible('#grid-overlay'));
    await click('#shutter'); await click('#review-open');
    const captured = await page.locator('#capture-image').getAttribute('src');
    const recipe = await text('#capture-recipe');
    check('Capture includes downloadable filtered and clean photos', captured.startsWith('data:image/jpeg') && await visible('#download-original'));
    const downloadPromise = page.waitForEvent('download'); await click('#download-photo');
    const download = await downloadPromise; await download.saveAs(path.join(screenshotDir, 'sample.jpg'));
    check('Sample JPEG download produces a nonempty file', fs.statSync(path.join(screenshotDir, 'sample.jpg')).size > 1000);
    await click('#review-screen [data-back="camera"]'); await click('#filters-toggle'); await click('button[data-effect="off"]'); await page.keyboard.press('Escape'); await click('[data-look="mono800"]'); await click('#review-open');
    check('Captured image and recipe remain frozen after control changes', captured === await page.locator('#capture-image').getAttribute('src') && recipe === await text('#capture-recipe'));
    await page.reload(); await page.locator('#scene-loading').waitFor({ state: 'hidden' });
    check('Reload resets diffusion and in-memory custom library', await text('#filter-summary') === 'Filters Off' && await page.locator('#look-strip [data-look]').count() === 7);

    const pixelChecks = await page.evaluate(() => {
      const r = window.LutliRenderer.render;
      const source = document.createElement('canvas'); source.width = 160; source.height = 240;
      const s = source.getContext('2d'); s.fillStyle = '#0a0a0a'; s.fillRect(0, 0, 160, 240); s.fillStyle = '#fff'; s.fillRect(64, 104, 32, 32);
      const out = document.createElement('canvas'); out.width = 160; out.height = 240;
      const px = (x, y) => [...out.getContext('2d').getImageData(x, y, 1, 1).data];
      const bytes = () => [...out.getContext('2d').getImageData(0, 0, 160, 240).data];
      const opts = { look: 'warm400', intensity: .8, ev: 0, effect: 'off', temperature: 5500 };
      r(out, source, opts); const base = bytes();
      for (const effect of ['hdf', 'blackMist']) { r(out, source, { ...opts, effect, strength: 0 }); if (JSON.stringify(bytes()) !== JSON.stringify(base)) throw new Error(`${effect} zero bypass`); }
      r(out, source, { ...opts, look: 'original', effect: 'hdf', strength: 1, glow: '#ff0000' });
      const halo = px(98, 120), dark = px(10, 10);
      if (!(halo[0] > halo[1] + 5 && dark.slice(0, 3).every(v => Math.abs(v - 10) <= 1))) throw new Error('HDF locality');
      r(out, source, { ...opts, look: 'original', effect: 'blackMist', strength: 1, glow: '#ff0000' }); const mist = px(98, 120);
      if (!(mist[0] > 10 && Math.abs(mist[0] - mist[2]) <= 1)) throw new Error('Mist neutrality');
      s.fillStyle = '#4080c0'; s.fillRect(0, 0, 160, 240);
      r(out, source, { look: 'original', intensity: 0, effect: 'off' }); const original = px(40, 40);
      r(out, source, { look: 'warm400', intensity: 0, effect: 'off' }); if (JSON.stringify(original) !== JSON.stringify(px(40, 40))) throw new Error('LUT zero bypass');
      const values = new Float32Array(17 ** 3 * 3); let i = 0;
      for (let b = 0; b < 17; b++) for (let g = 0; g < 17; g++) for (let red = 0; red < 17; red++) { values[i++] = b / 16; values[i++] = g / 16; values[i++] = red / 16; }
      r(out, source, { cube: { size: 17, values }, intensity: 1, effect: 'off' }); const swapped = px(40, 40);
      if (!(Math.abs(swapped[0] - 192) <= 1 && Math.abs(swapped[1] - 128) <= 1 && Math.abs(swapped[2] - 64) <= 1 && swapped[3] === 255)) throw new Error('RGB cube sampling');
      return { halo, mist, swapped };
    });
    check('Renderer pixel invariants: zero bypass, tint locality, shadows, neutral Mist and RGB cube sampling', Boolean(pixelChecks));

    for (const [width, height] of [[390, 844], [320, 700]]) {
      await page.setViewportSize({ width, height }); await settle();
      const before = await page.locator('#shutter').boundingBox();
      await click('#filters-toggle'); await click('button[data-effect="hdf"]'); await settle();
      const after = await page.locator('#shutter').boundingBox();
      check(`Mobile ${width}px: no horizontal overflow and shutter stays visible/stationary`, await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth) && Math.abs(before.y - after.y) < 1 && after.y + after.height <= height);
      await shot(`05-mobile-${width}-hdf`); await page.keyboard.press('Escape');
      await click('#library-open'); await click('#demo-look'); await settle();
      check(`Mobile ${width}px: label editor is scrollable and save reachable`, await page.locator('#save-label').isEnabled());
      await page.locator('#save-label').scrollIntoViewIfNeeded(); await shot(`06-mobile-${width}-label`);
      await click('#cancel-label'); await click('#library-screen [data-back="camera"]');
    }
    await page.setViewportSize({ width: 1366, height: 768 }); await settle();
    const shortShutter = await page.locator('#shutter').boundingBox();
    check('Short desktop keeps the whole shutter within the viewport', shortShutter.y + shortShutter.height <= 768);
    await shot('07-desktop-short');
    check('No page JavaScript errors', errors.length === 0);
    check('No external network requests', external.length === 0);
    console.log(JSON.stringify({ status: 'passed', checks: passed.length, passed, pixelChecks, screenshots: screenshotDir, pageErrors: errors, externalRequests: external }, null, 2));
  } catch (error) {
    await shot('failure').catch(() => {});
    console.error(JSON.stringify({ status: 'failed', error: error.message, passed, pageErrors: errors, externalRequests: external, screenshot: path.join(screenshotDir, 'failure.png') }, null, 2));
    process.exitCode = 1;
  } finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
