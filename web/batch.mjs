import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const rows = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(l => l.split('\t'));
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  viewport: { width: 1440, height: 1600 }, locale: 'en-US', timezoneId: 'America/Los_Angeles' });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
const out = [];
for (const [name, url] of rows) {
  const page = await ctx.newPage();
  const f = { name, url, hoa: null, year: null, mello: false };
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await page.waitForTimeout(4200);
    const lines = (await page.locator('body').innerText()).split('\n').map(s => s.trim());
    for (let i = 0; i < lines.length; i++) {
      if (/^HOA dues$/i.test(lines[i])) { const m = (lines[i+1]||'').match(/\$([\d,]+)/); if (m) { f.hoa = +m[1].replace(/,/g,''); break; } }
    }
    for (let i = 0; i < lines.length; i++) {
      if (/^year built$/i.test(lines[i]) && /^\d{4}$/.test(lines[i+1]||'')) { f.year = +lines[i+1]; break; }
    }
    f.mello = /mello[- ]roos/i.test(lines.join(' '));
  } catch (e) { f.err = e.message.split('\n')[0].slice(0, 26); }
  console.error(`${name.slice(0,26).padEnd(28)} HOA=${f.hoa === null ? '?' : '$'+f.hoa}  built=${f.year||'?'}${f.mello?'  MELLO':''}${f.err?'  '+f.err:''}`);
  out.push(f);
  await page.close();
  await new Promise(r => setTimeout(r, 2400));
}
console.log(JSON.stringify(out));
await b.close();
