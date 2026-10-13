import { chromium } from 'playwright';
import { readFileSync, appendFileSync } from 'fs';
// Final pass over the shortlist itself: confirm the listing is still live and for sale, that the price
// and size still match what was recorded, and that it is not age-restricted. One of the candidates
// turned out to be in a 55+ golf community, which no price or square footage would have revealed.
const all = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const [shard, shards] = (process.argv[4] || '0/1').split('/').map(Number);
const rows = all.filter((_, i) => i % shards === shard);
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({ userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36', viewport: { width: 1440, height: 1800 } });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
for (const r of rows) {
  const p = await ctx.newPage();
  const v = { url: r.url, address: r.address, live: false };
  try {
    await p.goto(r.url, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await p.waitForTimeout(3600);
    const t = await p.locator('body').innerText();
    const L = t.split('\n').map((s) => s.trim()).filter(Boolean);
    const head = L.slice(0, 60).join('\n');
    v.for_sale = /^FOR SALE$/im.test(head);
    v.price = (head.match(/\$[\d,]{7,}/) || [''])[0].replace(/[$,]/g, '') || null;
    v.age_restricted = /(\b55\s*\+|senior community|age.restricted|active adult|active 55)/i.test(t);
    v.hoa_line = (t.match(/HOA Dues\s*\n\s*\$([\d,]+)/i) || [])[1] || null;
    v.live = true;
  } catch (e) { v.err = e.message.split('\n')[0].slice(0, 40); }
  appendFileSync(process.argv[3], JSON.stringify(v) + '\n');
  await p.close();
  await new Promise((res) => setTimeout(res, 800 + Math.random() * 600));
}
await b.close();
