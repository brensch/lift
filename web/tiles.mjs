import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const pw = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1500, height: 950 } });
const sizes = [];
p.on('response', async (r) => {
  if (!r.url().includes('tile.openstreetmap.org')) return;
  try { sizes.push({ status: r.status(), bytes: (await r.body()).length, referer: r.request().headers().referer || '(none)' }); }
  catch {}
});
await p.goto(process.argv[2] + '/login', { waitUntil: 'networkidle' });
await p.fill('#who', 'brendan'); await p.fill('#password', pw.brendan);
await p.click('button[value=member]');
await p.waitForTimeout(5000);
const blocked = sizes.filter((s) => s.bytes < 9000).length;
console.log(`${sizes.length} tiles fetched; referer sent: ${sizes[0] ? sizes[0].referer : 'n/a'}`);
console.log(`  real tiles: ${sizes.length - blocked}   blocked "403" tiles: ${blocked}`);
console.log(`  median size: ${sizes.length ? sizes.map(s=>s.bytes).sort((a,b)=>a-b)[Math.floor(sizes.length/2)] : 0} bytes`);
await p.screenshot({ path: process.argv[4] });
await b.close();
