import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const pw = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const b = await chromium.launch();
for (const [label, vp] of [['desktop', { width: 1600, height: 950 }], ['phone', { width: 430, height: 930 }]]) {
  const ctx = await b.newContext({ viewport: vp });
  const p = await ctx.newPage();
  const bad = [];
  p.on('console', (m) => m.type() === 'error' && bad.push('console: ' + m.text().slice(0, 90)));
  p.on('pageerror', (e) => bad.push('PAGEERROR ' + e.message.slice(0, 90)));
  p.on('requestfailed', (r) => bad.push('failed: ' + r.url().slice(0, 80) + ' — ' + (r.failure()?.errorText || '')));
  p.on('response', (r) => { if (r.status() >= 400) bad.push(`${r.status()} ${r.url().slice(0, 80)}`); });
  await p.goto(process.argv[2] + '/login', { waitUntil: 'networkidle' });
  await p.fill('#who', 'brendan'); await p.fill('#password', pw.brendan);
  await p.click('button[value=member]');
  await p.waitForTimeout(4000);
  const box = await p.locator('#map').boundingBox();
  const tiles = await p.locator('#map img.leaflet-tile').count();
  const pins = await p.locator('.leaflet-marker-icon').count();
  console.log(`${label}: map box ${box ? Math.round(box.width) + 'x' + Math.round(box.height) : 'MISSING'} | tiles ${tiles} | pins ${pins}`);
  console.log('   ' + (bad.length ? bad.slice(0, 4).join('\n   ') : 'no errors'));
  await ctx.close();
}
await b.close();
