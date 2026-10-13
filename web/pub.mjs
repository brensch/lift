import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 430, height: 930 } });
const errs = [];
p.on('console', (m) => m.type() === 'error' && errs.push(m.text()));
p.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message));
await p.goto(process.argv[2], { waitUntil: 'networkidle', timeout: 40000 });
await p.waitForTimeout(2000);
console.log('landed on:', new URL(p.url()).pathname, '| count:', await p.locator('#count').textContent());
// no name yet: rating should prompt
p.once('dialog', async (d) => { console.log('prompt with no name:', d.message()); await d.dismiss(); });
await p.locator('.house').first().locator('.rating .stars button').nth(3).click();
await p.waitForTimeout(800);
// now put a name in and rate
await p.fill('#me', 'Steph');
await p.locator('#me').blur();
await p.waitForTimeout(600);
await p.locator('.house').first().locator('.rating .stars button').nth(3).click();
await p.waitForTimeout(1500);
const first = await p.locator('.house').first().innerText();
console.log('first card after rating as Steph:\n  ' + first.replace(/\n/g, ' | ').slice(0, 260));
await p.screenshot({ path: process.argv[3] });
console.log(errs.length ? 'ERRORS: ' + errs.join(' | ') : 'no console errors');
await b.close();
