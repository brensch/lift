import { chromium } from 'playwright';
import { readFileSync, writeFileSync, appendFileSync } from 'fs';

// Stage 2: open every candidate's own listing page and read the facts from it.
// Nothing here is carried over from the search card except the url. A card shows a lot size where a
// floor area should be, rounds the price, and never shows HOA dues or the year -- and on this task a
// card's sqft has already been wrong once. The detail page is the evidence; the card is only a lead.
const all = JSON.parse(readFileSync(process.argv[2], 'utf8'));
// Shard so several processes can share the list without overlapping, and so a crash or a timeout
// costs one shard's tail rather than the whole run.
const [shard, shards] = (process.argv[4] || '0/1').split('/').map(Number);
const rows = all.filter((_, i) => i % shards === shard);
const CONC = 3;

const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const mk = async () => {
  const ctx = await b.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    viewport: { width: 1440, height: 1800 }, locale: 'en-US', timezoneId: 'America/Los_Angeles' });
  await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
  return ctx;
};

const money = (s) => { const m = (s || '').match(/\$([\d,]+)/); return m ? +m[1].replace(/,/g, '') : null; };
const out = [];
let cursor = 0, done = 0;

async function worker(ctx) {
  for (;;) {
    const i = cursor++;
    if (i >= rows.length) return;
    const row = rows[i];
    const page = await ctx.newPage();
    const r = { ...row, ok: false };
    delete r.text;
    try {
      await page.goto(row.url, { waitUntil: 'domcontentloaded', timeout: 45000 });
      await page.waitForTimeout(3500);
      const body = await page.locator('body').innerText();
      const L = body.split('\n').map((s) => s.trim()).filter(Boolean);

      const grab = (label, re) => {
        for (let k = 0; k < L.length; k++)
          if (new RegExp(`^${label}$`, 'i').test(L[k])) { const m = (L[k + 1] || '').match(re); if (m) return m; }
        return null;
      };
      // The listing's own address line is the one fact that resolves which city this is actually in:
      // a Redfin city page happily returns homes over the boundary, so the search's city is a lead only.
      const full = L.slice(0, 60).find((x) => /,\s*CA\s*\d{5}/.test(x)) || '';
      const addr = full.match(/^(.+?),\s*([A-Za-z .'-]+),\s*CA\s*(\d{5})/);
      r.address = addr ? addr[1].trim() : null;
      r.listed_city = addr ? addr[2].trim() : null;
      r.zip = addr ? addr[3] : null;
      const head = L.slice(0, 60).join('\n');
      r.price = money((head.match(/\$[\d,]{7,}/) || [])[0]);
      // Redfin abbreviates these to bd/ba, each on its own line above the unit.
      const bd = head.match(/(\d+(?:\.\d+)?)\s*\n?bd\b/i);   r.beds = bd ? +bd[1] : null;
      const ba = head.match(/(\d+(?:\.\d+)?)\s*\n?ba\b/i);   r.baths = ba ? +ba[1] : null;
      // sqft only where it reads as a floor area, never a lot size -- the two sit side by side.
      const sq = head.match(/([\d,]{3,7})\s*\n?sq ft\b(?![^\n]*lot)/i);
      r.sqft = sq ? +sq[1].replace(/,/g, '') : null;
      const ptIdx = L.findIndex((x) => /^Property Type$/i.test(x));
      r.ptype = ptIdx > 0 ? L[ptIdx - 1] : null;
      const hoa = grab('HOA Dues', /\$([\d,]+)/) || grab('HOA dues', /\$([\d,]+)/);
      r.hoa = hoa ? +hoa[1].replace(/,/g, '') : null;
      const yr = grab('Year Built', /(\d{4})/) || grab('Year built', /(\d{4})/);
      r.year = yr ? +yr[1] : null;
      const lot = body.match(/([\d,]{3,9})\s*(?:sq ft|square feet)\s*lot/i);
      r.lot = lot ? +lot[1].replace(/,/g, '') : null;
      r.mello = /mello[- ]roos/i.test(body);
      r.status = /^FOR SALE$/im.test(head) ? 'for sale'
        : /\bsold on\b/i.test(head) ? 'sold'
        : /pending|contingent|accepting backup/i.test(head) ? 'pending' : 'unknown';
      r.ok = !!(r.address && r.listed_city && r.price && r.sqft && r.beds && r.baths);
    } catch (e) { r.err = e.message.split('\n')[0].slice(0, 40); }
    out.push(r);
    appendFileSync(process.argv[3], JSON.stringify(r) + '\n');
    done++;
    if (done % 10 === 0) console.error(`  ${done}/${rows.length}`);
    await page.close();
    await new Promise((res) => setTimeout(res, 700 + Math.random() * 600));
  }
}
const ctxs = await Promise.all(Array.from({ length: CONC }, mk));
await Promise.all(ctxs.map(worker));
console.error(`\nshard ${shard}: ${out.filter((x) => x.ok).length}/${out.length} validated`);
await b.close();
