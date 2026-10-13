import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const urls = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({ userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36', viewport: { width: 1440, height: 1800 } });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
for (const u of urls) {
  const p = await ctx.newPage();
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await p.waitForTimeout(3800);
    const t = await p.locator('body').innerText();
    const hits = [...t.matchAll(/[^.\n]{0,90}(55\+|55 \+|senior community|age.restrict|active adult|The Villages)[^.\n]{0,90}/gi)].map(m => m[0].trim());
    console.log(`\n${u.split('/').slice(-3).join('/')}\n  ${hits.length ? hits.slice(0,3).join('\n  ') : 'no age-restriction language found'}`);
  } catch (e) { console.log(`${u}: ERR ${e.message.slice(0,40)}`); }
  await p.close();
  await new Promise(r => setTimeout(r, 1500));
}
await b.close();
