import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const pw = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const base = process.argv[2];
const b = await chromium.launch();
const errs = [];

// 1. a guest
const g = await b.newContext(); const gp = await g.newPage({ viewport: { width: 430, height: 930 } });
gp.on('pageerror', (e) => errs.push('guest PAGEERROR ' + e.message));
await gp.goto(base + '/', { waitUntil: 'networkidle' });
await gp.screenshot({ path: process.argv[4] });
console.log('login page fields:', await gp.locator('input').count(), 'inputs,', await gp.locator('button').count(), 'buttons');
await gp.fill('#guest', 'Brendan');
await gp.click('button[value=guest]');
await gp.waitForTimeout(1200);
console.log('guest claiming "Brendan":', (await gp.locator('.error').textContent().catch(() => 'no error')).trim());
await gp.fill('#guest', 'Steph');
await gp.click('button[value=guest]');
await gp.waitForTimeout(1800);
console.log('guest as Steph ->', new URL(gp.url()).pathname, '|', await gp.locator('.who').innerText());
await gp.locator('.house').first().locator('.rating .stars button').nth(4).click();
await gp.waitForTimeout(1500);
console.log('Steph rated:', (await gp.locator('.house').first().innerText()).replace(/\n/g, ' | ').slice(0, 170));

// 2. a member, in a separate session
const m = await b.newContext(); const mp = await m.newPage({ viewport: { width: 430, height: 930 } });
mp.on('pageerror', (e) => errs.push('member PAGEERROR ' + e.message));
await mp.goto(base + '/login', { waitUntil: 'networkidle' });
await mp.fill('#who', 'brendan');
await mp.fill('#password', pw.brendan);
await mp.click('button[value=member]');
await mp.waitForTimeout(1800);
console.log('member ->', new URL(mp.url()).pathname, '|', await mp.locator('.who').innerText());
await mp.screenshot({ path: process.argv[5] });
console.log('member sees Steph on the first card:', (await mp.locator('.house').first().innerText()).includes('Steph'));
console.log(errs.length ? 'ERRORS: ' + errs.join(' | ') : 'no page errors');
await b.close();
