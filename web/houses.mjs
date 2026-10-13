import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const pw = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 430, height: 930 } });   // a phone, which is the point
const errs = [];
p.on('console', (m) => m.type() === 'error' && errs.push(m.text()));
p.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message));
const base = process.argv[2];

await p.goto(base + '/', { waitUntil: 'networkidle' });
console.log('unauthenticated landed on:', new URL(p.url()).pathname);
await p.fill('#who', 'brendan');
await p.fill('#password', pw.brendan);
await p.click('button[type=submit]');
await p.waitForTimeout(2000);
console.log('after login:', new URL(p.url()).pathname);
console.log('count line:', await p.locator('#count').textContent());
await p.screenshot({ path: process.argv[4], fullPage: false });

// rate the first house
const firstTitle = await p.locator('.house h2').first().textContent();
await p.locator('.house').first().locator('.rating .stars button').nth(3).click();
await p.waitForTimeout(1500);
const on = await p.locator('.house').first().locator('.rating .stars .on').count();
console.log(`rated "${firstTitle.trim()}" -> ${on} stars lit`);

// filters
await p.selectOption('#kind', 'house');
await p.waitForTimeout(400);
console.log('filtered to houses:', await p.locator('#count').textContent());
await p.selectOption('#hoa', 'none');
await p.waitForTimeout(400);
console.log('and no HOA:', await p.locator('#count').textContent());
console.log(errs.length ? 'CONSOLE ERRORS:\n' + errs.join('\n') : 'no console errors');
await b.close();
