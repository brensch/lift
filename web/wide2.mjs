import { chromium } from 'playwright';
// Every id verified against the page title before anything is read from it. The first attempt guessed these and
// pulled listings from Siletz OR, Castle Rock WA and McFarland KS while claiming they were Saratoga and Campbell.
const CITIES = [['Cupertino','4561'], ['Sunnyvale','19457'], ['Mountain-View','12739'], ['Santa-Clara','17675'],
                ['San-Jose','17420'], ['Palo-Alto','14325'], ['Campbell','2673'], ['Los-Gatos','11234'],
                ['Los-Altos','11018']];
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  viewport: { width: 1440, height: 1800 }, locale: 'en-US', timezoneId: 'America/Los_Angeles' });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
const all = [];
for (const [city, id] of CITIES) {
  const want = city.replace(/-/g, ' ');
  for (const pageNo of [1, 2]) {
    const page = await ctx.newPage();
    try {
      await page.goto(`https://www.redfin.com/city/${id}/CA/${city}/filter/property-type=house+townhouse,`
        + `min-beds=3,min-sqft=1750-sqft,max-price=2.1M` + (pageNo > 1 ? `/page-${pageNo}` : ''),
        { waitUntil: 'domcontentloaded', timeout: 45000 });
      await page.waitForTimeout(4500);
      const title = await page.title();
      if (!title.includes(want) || !/\bCA\b/.test(title)) { console.error(`${city} p${pageNo}: WRONG PAGE (${title.slice(0,40)})`); await page.close(); continue; }
      for (let i = 0; i < 8; i++) { await page.mouse.wheel(0, 3000); await page.waitForTimeout(600); }
      const rows = await page.evaluate((city) => [...document.querySelectorAll('.HomeCardContainer')].map(card => {
        const link = (card.querySelector('a[href*="/home/"]') || {}).href || '';
        const t = card.innerText || '';
        // Redfin prints "N beds  M baths  S sq ft" together; take sq ft only when it follows a bath count, so a
        // lot size printed elsewhere on the card cannot be mistaken for interior area.
        const spec = t.match(/([\d.]+)\s*beds?[\s|]*([\d.]+)\s*baths?[\s|]*([\d,]+)\s*sq\s?ft/i);
        const price = (t.match(/\$([\d,]{6,})/) || [])[1];
        const addr = (link.match(/\/CA\/[^/]+\/([^/]+)-\d{5}\//) || [])[1];
        return (price && link && spec && addr) ? { city, url: link, address: addr.replace(/-/g, ' '),
          price: +price.replace(/,/g, ''), beds: +spec[1], baths: +spec[2], sqft: +spec[3].replace(/,/g, '') } : null;
      }).filter(Boolean), city);
      console.error(`${city} p${pageNo}: ${rows.length} with full specs`);
      all.push(...rows);
    } catch (e) { console.error(`${city} p${pageNo}: ${e.message.split('\n')[0].slice(0, 40)}`); }
    await page.close();
    await new Promise(r => setTimeout(r, 2200));
  }
}
const seen = new Set();
const unique = all.filter(x => !seen.has(x.url) && seen.add(x.url));
console.error(`\n${all.length} cards, ${unique.length} unique`);
console.log(JSON.stringify(unique));
await b.close();
