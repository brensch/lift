import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1500, height: 2000 } });
const errs = [];
p.on('console', (m) => m.type() === 'error' && errs.push(m.text()));
p.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message));
await p.goto(process.argv[2], { waitUntil: 'networkidle', timeout: 40000 });
await p.waitForTimeout(2500);
const sel = process.argv[4];
if (sel) {
  const el = p.locator(sel).first();
  await el.scrollIntoViewIfNeeded();
  await p.waitForTimeout(600);
  await el.screenshot({ path: process.argv[3] });
} else await p.screenshot({ path: process.argv[3], fullPage: true });
console.log(errs.length ? 'CONSOLE ERRORS:\n' + errs.join('\n') : 'no console errors');
await b.close();
