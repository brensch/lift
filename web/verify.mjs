import { chromium } from 'playwright';
const b = await chromium.launch();
// Brendan's view
const c1 = await b.newContext(); const p1 = await c1.newPage({ viewport: { width: 1500, height: 900 } });
await p1.goto(process.argv[2], { waitUntil: 'networkidle' }); await p1.waitForTimeout(2000);
await p1.locator('#houses p.note button', { hasText: 'Brendan' }).first().click();
await p1.waitForTimeout(2500);
// Alyssa's view, a separate browser session at the same time
const c2 = await b.newContext(); const p2 = await c2.newPage({ viewport: { width: 1500, height: 900 } });
await p2.goto(process.argv[2], { waitUntil: 'networkidle' }); await p2.waitForTimeout(2000);
await p2.locator('#houses p.note button', { hasText: 'Alyssa' }).first().click();
await p2.waitForTimeout(2500);
const head = async (p) => (await p.locator('#houses table thead').first().innerText()).replace(/\n/g, ' | ');
const cols = async (p) => (await head(p)).split('|').map((x) => x.trim()).filter((x) => /Brendan|Alyssa/.test(x)).join('   /   ');
console.log('Brendan session headers:', await cols(p1));
console.log('Alyssa  session headers:', await cols(p2));
const clickable = async (p) => (await p.locator('#houses table tbody tr').first().locator('button').count());
console.log('clickable stars — Brendan:', await clickable(p1), ' Alyssa:', await clickable(p2));
await b.close();
