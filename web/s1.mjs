import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

// Cities within roughly 20-30 minutes' drive of the Gridmatic office in Cupertino.
// ids came from crawling Redfin's own county pages, never guessed -- a guessed id silently
// returns a different state's listings, which has already happened once on this task.
const CITIES = [
  ['Cupertino', '4561', 30], ['Sunnyvale', '19457', 34], ['Santa-Clara', '17675', 34],
  ['Saratoga', '17960', 28], ['Campbell', '2673', 30], ['Los-Gatos', '11234', 30],
  ['Mountain-View', '12739', 30], ['Los-Altos', '11018', 24], ['San-Jose', '17420', 60],
  ['Palo-Alto', '14325', 26], ['Milpitas', '12204', 30],
];
const TYPES = [['house', 'house'], ['townhouse', 'townhouse'], ['condo', 'condo']];
const FILTER = 'min-beds=3,max-price=2.5M,min-sqft=1.45k';

const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  viewport: { width: 1440, height: 2400 }, locale: 'en-US', timezoneId: 'America/Los_Angeles' });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));

const seen = new Map();
for (const [city, id, cap] of CITIES) {
  for (const [tKey, tName] of TYPES) {
    let added = 0;
    for (let pg = 1; pg <= 7; pg++) {
      const base = `https://www.redfin.com/city/${id}/CA/${city}/filter/property-type=${tKey},${FILTER}`;
      const url = pg === 1 ? base : `${base}/page-${pg}`;
      const page = await ctx.newPage();
      let n = 0;
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
        await page.waitForTimeout(3600);
        const title = await page.title();
        // The city id must be confirmed against the page itself before a single card is read.
        if (!title.toLowerCase().includes(city.replace(/-/g, ' ').toLowerCase())) {
          console.error(`  !! ${city} ${tName} p${pg}: title mismatch "${title.slice(0, 50)}"`);
          await page.close(); break;
        }
        await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
        await page.waitForTimeout(1800);
        const cards = await page.evaluate(() => [...document.querySelectorAll('.HomeCardContainer, [class*="HomeCard"]')]
          .map((c) => {
            const a = c.querySelector('a[href*="/home/"]');
            if (!a) return null;
            return { url: new URL(a.getAttribute('href'), location.origin).href, text: c.innerText };
          }).filter(Boolean));
        for (const c of cards) {
          const key = c.url.split('?')[0].toLowerCase();
          if (seen.has(key)) continue;
          seen.set(key, { url: c.url.split('?')[0], city: city.replace(/-/g, ' '), kind: tName, text: c.text });
          n++; added++;
        }
      } catch (e) { console.error(`  !! ${city} ${tName} p${pg}: ${e.message.split('\n')[0].slice(0, 40)}`); }
      await page.close();
      if (n === 0) break;                       // no new rows on this page: the list is exhausted
      await new Promise((r) => setTimeout(r, 1500));
      if (added >= cap) break;
    }
    console.error(`${city.padEnd(15)} ${tName.padEnd(10)} +${added}`);
  }
}
writeFileSync(process.argv[2], JSON.stringify([...seen.values()]));
console.error(`\nTOTAL ${seen.size} unique listings`);
await b.close();
