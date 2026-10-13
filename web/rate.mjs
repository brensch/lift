import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1500, height: 1100 } });
const errs = [];
p.on('console', (m) => m.type() === 'error' && errs.push(m.text()));
p.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message));
p.on('dialog', async (d) => { errs.push('ALERT: ' + d.message()); await d.dismiss(); });
await p.goto(process.argv[2], { waitUntil: 'networkidle', timeout: 40000 });
await p.waitForTimeout(2200);

const ask = p.locator('#houses p.note').first();
console.log('prompt:', (await ask.textContent().catch(() => '(none)')).trim().slice(0, 120));

// click "Brendan" in the inline picker
const pick = p.locator('#houses p.note button', { hasText: 'Brendan' }).first();
console.log('inline picker visible:', await pick.isVisible().catch(() => false));
await pick.click();
await p.waitForTimeout(2500);

// now the first house's own stars should be buttons
const stars = p.locator('#houses table tbody tr').first().locator('button');
const n = await stars.count();
console.log('clickable stars on the first row:', n);
if (n >= 4) {
  await stars.nth(3).click();                      // four of five
  await p.waitForTimeout(2500);
}
const after = await p.locator('#houses table tbody tr').first().innerText();
console.log('first row after rating:\n  ' + after.replace(/\n/g, ' | ').slice(0, 200));
console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no console errors');
await b.close();
