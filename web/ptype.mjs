import { chromium } from 'playwright';
const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
const ctx = await b.newContext({ userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36', viewport: { width: 1440, height: 1600 } });
await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
for (const url of process.argv.slice(2)) {
  const p = await ctx.newPage();
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await p.waitForTimeout(4500);
    const t = await p.locator('body').innerText();
    const hits = [...t.matchAll(/(?:property type|home type|style|sub ?type)[:\s]*\n?\s*([A-Za-z \-/]{3,40})/gi)]
      .map((m) => m[1].trim()).slice(0, 4);
    const words = [...t.matchAll(/\b(single[- ]family|townhous\w*|townhom\w*|condo\w*|duplex|co-?op)\b/gi)]
      .map((m) => m[1].toLowerCase());
    const tally = {};
    for (const w of words) tally[w] = (tally[w] || 0) + 1;
    console.log(`\n${url.slice(0, 74)}\n  labelled: ${hits.join(' | ') || '(none)'}\n  words: ${JSON.stringify(tally)}`);
  } catch (e) { console.log(`\n${url.slice(0,74)}\n  ERR ${e.message.split('\n')[0].slice(0,60)}`); }
  await p.close();
  await new Promise((r) => setTimeout(r, 1500));
}
await b.close();
