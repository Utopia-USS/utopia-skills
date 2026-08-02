// Render chip HTML pages to transparent PNGs (@2x) via headless Chrome.
// Usage: node render.mjs <jobs.json> <dims.json>
//   jobs.json = [{ pkg, html, out }]
//   dims.json <- { pkg: { w, h } }  (natural @1x CSS dimensions)
//
// Needs: puppeteer-core (npm i puppeteer-core) + a local Chrome.
// Chrome path: $CHROME env var, else common macOS/Linux locations.
import puppeteer from 'puppeteer-core';
import fs from 'fs';

const CANDIDATES = [
  process.env.CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
].filter(Boolean);
const CHROME = CANDIDATES.find((p) => { try { return fs.existsSync(p); } catch { return false; } });
if (!CHROME) { console.error('No Chrome found. Set $CHROME to the binary path.'); process.exit(1); }

const [, , jobsPath, dimsPath] = process.argv;
const jobs = JSON.parse(fs.readFileSync(jobsPath, 'utf8'));

const browser = await puppeteer.launch({
  executablePath: CHROME, headless: true,
  args: ['--no-sandbox', '--force-color-profile=srgb', '--hide-scrollbars'],
});
const dims = {};
for (const j of jobs) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 900, deviceScaleFactor: 2 });
  await page.goto('file://' + j.html, { waitUntil: 'networkidle0' });
  await page.evaluate(async () => { await document.fonts.ready; });
  const fontOk = await page.evaluate(() =>
    document.fonts.check('700 24px Ubuntu') && document.fonts.check('500 13px Ubuntu'));
  if (!fontOk) {
    console.error(`Ubuntu web font failed to load for "${j.pkg}" (offline?). ` +
      'The chip would render with a fallback face - aborting to avoid a wrong brand asset.');
    await browser.close();
    process.exit(1);
  }
  const el = await page.$('#cap');
  const box = await el.boundingBox();
  await el.screenshot({ path: j.out, omitBackground: true });
  dims[j.pkg] = { w: Math.round(box.width), h: Math.round(box.height) };
  console.log('  rendered', j.pkg, dims[j.pkg].w + 'x' + dims[j.pkg].h);
  await page.close();
}
fs.writeFileSync(dimsPath, JSON.stringify(dims, null, 2));
await browser.close();
