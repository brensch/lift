import { chromium } from 'playwright';
const CITIES = [
  ['Palo-Alto','14325'], ['Los-Altos','11018'], ['Menlo-Park','11961'], ['Cupertino','4561'],
  ['Mountain-View','12739'], ['Saratoga','17960'], ['Los-Gatos','11234'], ['Sunnyvale','19457'],
  ['Santa-Clara','17675'], ['Campbell','2673'], ['San-Mateo','17490'], ['Burlingame','2350'],
  ['Redwood-City','15525'], ['Milpitas','12204'], ['Fremont','6671'], ['San-Jose','17420'],
  ['Pleasanton','14986'], ['Hayward','8439'], ['Oakland','13654'], ['Berkeley','1590'],
  ['Morgan-Hill','12625'], ['Gilroy','7521'], ['Newark','13111'],
];
const TYPES = [['house', 'house'], ['attached', 'townhouse+condo']];
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  viewport: { width: 1440, height: 1800 }, locale: 'en-US', timezoneId: 'America/Los_Angeles' });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
const all = [];
for (const [city, id] of CITIES) {
  const want = city.replace(/-/g, ' ');
  for (const [kind, filter] of TYPES) {
    const page = await ctx.newPage();
    try {
      await page.goto(`https://www.redfin.com/city/${id}/CA/${city}/filter/property-type=${filter},min-beds=3,min-sqft=1500-sqft`,
        { waitUntil: 'domcontentloaded', timeout: 40000 });
      await page.waitForTimeout(4200);
      const title = await page.title();
      if (!title.includes(want) || !/\bCA\b/.test(title)) { console.error(`${city}/${kind}: WRONG PAGE`); await page.close(); continue; }
      for (let i = 0; i < 7; i++) { await page.mouse.wheel(0, 3000); await page.waitForTimeout(550); }
      const rows = await page.evaluate((a) => [...document.querySelectorAll('.HomeCardContainer')].map(card => {
        const link = (card.querySelector('a[href*="/home/"]') || {}).href || '';
        const t = card.innerText || '';
        const spec = t.match(/([\d.]+)\s*beds?[\s|]*([\d.]+)\s*baths?[\s|]*([\d,]+)\s*sq\s?ft/i);
        const price = (t.match(/\$([\d,]{6,})/) || [])[1];
        const addr = (link.match(/\/CA\/[^/]+\/([^/]+)-\d{5}\//) || [])[1];
        return (price && link && spec && addr) ? { city: a[0], kind: a[1], url: link,
          address: addr.replace(/-/g, ' '), price: +price.replace(/,/g, ''),
          beds: +spec[1], baths: +spec[2], sqft: +spec[3].replace(/,/g, '') } : null;
      }).filter(Boolean), [want, kind]);
      console.error(`${city.padEnd(15)} ${kind.padEnd(9)} ${rows.length}`);
      all.push(...rows);
    } catch (e) { console.error(`${city}/${kind}: ${e.message.split('\n')[0].slice(0, 36)}`); }
    await page.close();
    await new Promise(r => setTimeout(r, 1800));
  }
}
const seen = new Set();
console.error(`\n${all.length} cards`);
console.log(JSON.stringify(all.filter(x => !seen.has(x.url + x.kind) && seen.add(x.url + x.kind))));
await b.close();
