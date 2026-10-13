import { chromium } from 'playwright';
import { readFileSync, writeFileSync, existsSync, appendFileSync } from 'fs';

/* One photo and one set of coordinates per house.
   The photo is downloaded rather than hot-linked: a listing's image url stops working the moment the listing
   is taken down, which is exactly when you most want to remember what the place looked like. */
const houses = JSON.parse(readFileSync(process.argv[2], 'utf8')).houses;
const outDir = process.argv[3];
const log = process.argv[4];
const [shard, shards] = (process.argv[5] || '0/1').split('/').map(Number);
const mine = houses.filter((_, i) => i % shards === shard).filter((h) => h.url);

const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  viewport: { width: 1280, height: 900 } });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));

for (const h of mine) {
  const out = { id: h.id };
  if (existsSync(`${outDir}/${h.id}.jpg`)) { out.photo = 'already'; appendFileSync(log, JSON.stringify(out) + '\n'); continue; }
  const p = await ctx.newPage();
  try {
    await p.goto(h.url, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await p.waitForTimeout(2600);
    const src = await p.evaluate(() => {
      const og = document.querySelector('meta[property="og:image"]')?.content;
      if (og) return og;
      const img = [...document.querySelectorAll('img')]
        .find((i) => i.naturalWidth > 500 && /photo|image|media|ssl/i.test(i.src));
      return img ? img.src : null;
    });
    if (src) {
      const res = await ctx.request.get(src, { timeout: 25000 });
      if (res.ok()) {
        const body = await res.body();
        if (body.length > 4000) { writeFileSync(`${outDir}/${h.id}.jpg`, body); out.photo = body.length; }
      }
    }
    if (!out.photo) out.photo = null;
  } catch (e) { out.err = e.message.split('\n')[0].slice(0, 40); }
  appendFileSync(log, JSON.stringify(out) + '\n');
  console.error(`${(h.address || '').slice(0, 30).padEnd(32)} ${out.photo || out.err || 'none'}`);
  await p.close();
  await new Promise((r) => setTimeout(r, 900 + Math.random() * 700));
}
await b.close();
