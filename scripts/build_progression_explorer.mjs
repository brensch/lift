#!/usr/bin/env node
// Builds the progression explorer: one self-contained HTML page showing what
// the planning rules (core/src/plan.rs) told scripted lifters, session by
// session, with the audit flags the Rust test raised; and the Rotation tab,
// a lifter who starts whatever Home suggests (core/src/volume.rs), day by
// day, with the rotation check.
//
// The data is testdata/progression_scenarios.json, written by the core's own
// test driving the real API (core/tests/progression_scenarios.rs) — there is
// no second implementation of the rules here, only rendering.
//
// Usage:
//   make progression-explorer                      # regenerate + build
//   node scripts/build_progression_explorer.mjs [out.html] [data.json]
//
// Defaults: out .tmp/progression-explorer.html (not committed), data
// testdata/progression_scenarios.json. No dependencies.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = resolve(process.argv[2] ?? join(root, ".tmp/progression-explorer.html"));
const dataPath = resolve(process.argv[3] ?? join(root, "testdata/progression_scenarios.json"));
const data = JSON.parse(readFileSync(dataPath, "utf8"));

// The data goes in a JSON script tag; only "</" could end it early.
const payload = JSON.stringify(data).replace(/<\//g, "<\\/");

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Progression Explorer</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;700&family=Space+Mono:wght@400;700&display=swap">
<style>
:root {
  --ground: #DBDAD2;
  --panel: #EDECE5;
  --ink: #111111;
  --muted: #4A4A44;
  --hairline: #B7B6AC;
  --signal: #FF4F00;
  --resting: #3C5FB0;
  --yapping: #D94F8C;
  --effort: #D99A00;
  --signal-soft: rgba(255, 79, 0, 0.12);
  --yapping-soft: rgba(217, 79, 140, 0.14);
  --effort-soft: rgba(217, 154, 0, 0.16);
  --resting-soft: rgba(60, 95, 176, 0.12);
  --sans: 'Space Grotesk', system-ui, sans-serif;
  --mono: 'Space Mono', ui-monospace, monospace;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --ground: #151513;
    --panel: #20201D;
    --ink: #EDECE5;
    --muted: #A8A79E;
    --hairline: #46463F;
    --signal: #FF6A26;
    --resting: #7E9BE0;
    --yapping: #EC7FAE;
    --effort: #E8B23C;
    --signal-soft: rgba(255, 106, 38, 0.16);
    --yapping-soft: rgba(236, 127, 174, 0.16);
    --effort-soft: rgba(232, 178, 60, 0.16);
    --resting-soft: rgba(126, 155, 224, 0.16);
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --ground: #151513;
  --panel: #20201D;
  --ink: #EDECE5;
  --muted: #A8A79E;
  --hairline: #46463F;
  --signal: #FF6A26;
  --resting: #7E9BE0;
  --yapping: #EC7FAE;
  --effort: #E8B23C;
  --signal-soft: rgba(255, 106, 38, 0.16);
  --yapping-soft: rgba(236, 127, 174, 0.16);
  --effort-soft: rgba(232, 178, 60, 0.16);
  --resting-soft: rgba(126, 155, 224, 0.16);
  color-scheme: dark;
}
* { box-sizing: border-box; }
html, body { margin: 0; }
body {
  background: var(--ground);
  color: var(--ink);
  font: 15px/1.5 var(--sans);
  -webkit-text-size-adjust: 100%;
}
main { max-width: 1080px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font: 700 28px/1.1 var(--mono); letter-spacing: -0.02em; margin: 0 0 6px; }
h2 { font: 700 20px/1.2 var(--sans); margin: 0 0 4px; }
h3 { font: 700 16px/1.25 var(--sans); margin: 0; }
p { margin: 0 0 10px; }
.lede { color: var(--muted); max-width: 70ch; }
.mono, code { font-family: var(--mono); font-size: 0.92em; }
.panel {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 10px;
  padding: 16px;
  margin: 16px 0;
}
details.rules summary { cursor: pointer; font-weight: 700; }
details.rules ul { margin: 10px 0 0; padding-left: 20px; }
details.rules li { margin-bottom: 6px; max-width: 75ch; }
.tabs {
  display: flex; gap: 6px; overflow-x: auto; padding: 4px 0 8px;
  scrollbar-width: thin; position: sticky; top: 0; z-index: 2;
  background: var(--ground);
}
.tab {
  flex: none; font: 500 13px/1 var(--sans); color: var(--ink);
  background: var(--panel); border: 1px solid var(--hairline);
  border-radius: 999px; padding: 8px 12px; cursor: pointer; white-space: nowrap;
}
.tab[aria-selected="true"] { background: var(--ink); color: var(--ground); border-color: var(--ink); }
.tab .count { font-family: var(--mono); margin-left: 6px; color: var(--signal); }
.tab[aria-selected="true"] .count { color: var(--signal); }
.meta { display: flex; flex-wrap: wrap; gap: 6px 16px; color: var(--muted); font-size: 13px; margin-top: 6px; }
.flags { margin: 12px 0 0; padding: 0; list-style: none; }
.flags li {
  border-left: 4px solid var(--hairline); padding: 6px 10px; margin: 6px 0;
  background: var(--ground); border-radius: 0 6px 6px 0; font-size: 14px;
}
.flags li.violation { border-color: var(--signal); background: var(--signal-soft); }
.flags li.warning { border-color: var(--effort); background: var(--effort-soft); }
.flags li .k { font: 700 12px/1 var(--mono); text-transform: uppercase; margin-right: 6px; }
.ok { color: var(--muted); font-size: 14px; margin: 10px 0 0; }
.scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; margin-top: 10px; }
table { border-collapse: collapse; width: 100%; min-width: 760px; font-size: 13px; }
table.narrow { min-width: 560px; }
td.date { white-space: nowrap; }
th, td { text-align: left; vertical-align: top; padding: 6px 8px; border-bottom: 1px solid var(--hairline); }
th { font: 700 11px/1.2 var(--mono); text-transform: uppercase; color: var(--muted); white-space: nowrap; }
td.num, th.num { text-align: right; font-family: var(--mono); white-space: nowrap; }
td.plan { font-family: var(--mono); white-space: nowrap; }
tr.flagged td { background: var(--effort-soft); }
tr.flagged.violation td { background: var(--signal-soft); }
.sets { display: flex; flex-wrap: wrap; gap: 3px; min-width: 150px; }
.set {
  font: 12px/1 var(--mono); padding: 3px 5px; border-radius: 4px;
  border: 1px solid var(--hairline); white-space: nowrap;
}
.set.rung { border-style: dashed; color: var(--muted); }
.set.miss { border-color: var(--yapping); background: var(--yapping-soft); color: var(--ink); }
.chips { display: flex; flex-wrap: wrap; gap: 4px; min-width: 180px; }
.chip {
  font: 11px/1.2 var(--mono); padding: 3px 6px; border-radius: 4px;
  background: var(--ground); border: 1px solid var(--hairline); white-space: nowrap;
}
.chip b { font-weight: 700; }
.chip.MAX_UP { border-color: var(--signal); }
.chip.MAX_FROM_MISS { border-color: var(--yapping); background: var(--yapping-soft); }
.chip.HELD { border-color: var(--muted); }
.chip.TIME_OFF { border-color: var(--effort); background: var(--effort-soft); }
.chip.FIRST_TIME { border-color: var(--resting); background: var(--resting-soft); }
.chip.USER_SET { border-color: var(--ink); border-width: 2px; }
.chip.SETS_FROM_TIME { color: var(--muted); }
.chip.WEIGHT_UP, .chip.REPS_UP { border-color: var(--signal); background: var(--signal-soft); }
.chip.WEIGHT_DOWN, .chip.REPS_DOWN { border-color: var(--yapping); background: var(--yapping-soft); }
.chip.SAME_AS_LAST { border-color: var(--muted); background: var(--ground); }
.detail { display: block; color: var(--muted); font: 11px/1.3 var(--sans); margin-top: 2px; white-space: normal; max-width: 34ch; }
.changes { font: 11px/1.4 var(--mono); color: var(--muted); min-width: 120px; }
.note { color: var(--muted); font-size: 12px; }
.lift-head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; }
.lift-head .meta { margin: 0; }
svg.chart { width: 100%; min-width: 600px; height: auto; display: block; margin-top: 10px; }
td.nowrap { white-space: nowrap; }
svg.chart text { font: 11px var(--mono); fill: var(--muted); }
.legend { display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 12px; color: var(--muted); margin-top: 6px; }
.legend span { display: inline-flex; align-items: center; gap: 5px; }
.legend i { display: inline-block; width: 12px; height: 12px; }
.sw-line { border-top: 2px solid var(--resting); height: 0 !important; }
.sw-planned { border-top: 2px dashed var(--muted); height: 0 !important; }
.sw-dot { background: var(--signal); border-radius: 50%; }
.sw-miss { border: 2px solid var(--yapping); border-radius: 50%; }
.sw-off { background: var(--effort-soft); border: 1px solid var(--effort); }
.sw-user { background: var(--ink); transform: rotate(45deg) scale(0.8); }
.sw-ramp { width: 0 !important; height: 0 !important; border-left: 6px solid transparent; border-right: 6px solid transparent; border-bottom: 11px solid var(--resting); }
footer { color: var(--muted); font-size: 12px; margin-top: 32px; }
.week { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 6px; margin-top: 8px; }
.wday { font: 700 11px/1.2 var(--mono); text-transform: uppercase; color: var(--muted); padding: 0 2px; }
.cell { background: var(--ground); border: 1px solid var(--hairline); border-radius: 6px; padding: 6px; min-height: 64px; font-size: 12px; }
.cell.rest { border-style: dashed; color: var(--muted); }
.cell b { display: block; font-size: 13px; }
.cell .note { display: block; }
.cell.fallback { border-color: var(--effort); background: var(--effort-soft); }
.cell.waiting { border-color: var(--resting); background: var(--resting-soft); }
.bars { display: grid; grid-template-columns: 96px 1fr 44px; gap: 4px 8px; align-items: center; font-size: 13px; margin-top: 8px; max-width: 520px; }
.bar { height: 6px; background: var(--ground); border-radius: 6px; position: relative; overflow: hidden; }
.bar i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--resting); border-radius: 6px; }
td.won { font-weight: 700; }
@media (max-width: 600px) { .week { grid-template-columns: repeat(2, minmax(0, 1fr)); } .wday { display: none; } }
@media (max-width: 600px) {
  h1 { font-size: 22px; }
  .panel { padding: 12px; }
}
</style>
</head>
<body>
<main>
  <h1>Progression Explorer</h1>
  <p class="lede">What Schlift's planning rules tell scripted lifters, session by session: every plan, what was lifted, why the weight moved and where each lift's estimated max ended up. Every number comes from the real core (<code>core/src/plan.rs</code>) driven through its API the way the app drives it.</p>
  <details class="rules panel">
    <summary>The rules in brief</summary>
    <ul>
      <li><b>One number per lift.</b> Each lift has an estimated max: the most it could be lifted once (for bodyweight lifts, the most reps in a set). A set shows <code>weight × (1 + (reps + reserve + ½ × (set − 1)) / 30)</code>; reserve is 1 rep when the set hit its target, 0 when it fell short.</li>
      <li><b>After a session.</b> Every rep hit: the max goes up to what the sets show with one more rep each (MAX_UP), or stays (HELD) when that is no higher — as when the lifter lowered the weight. A rep missed: the max drops to the best any set showed, never higher than before (MAX_FROM_MISS). Stopped early, or the lift removed: unchanged (HELD).</li>
      <li><b>Time off</b>, per lift, when a workout is planned: 21+ days away cuts the max to 90%, 42+ days to 80% (TIME_OFF).</li>
      <li><b>First time</b> (FIRST_TIME): a calibration ramp of 5-rep sets from 60% of the starting weight the strength slider gave, about +10% a rung, up to six rungs. The missed rung (or the sixth) gives the max and the working sets follow from it.</li>
      <li><b>Override</b> (USER_SET): a weight × reps (optionally sets) from the template editor becomes the max that prescribes it; the progression carries on from there.</li>
      <li><b>Classes.</b> Heavy barbell compounds 5–8 reps, 3:00 rest, a warmup ladder. Other loaded lifts 8–12 reps, 2:00. Bodyweight and core 5–15 reps, 1:30.</li>
      <li><b>Sets from the time budget</b> (SETS_FROM_TIME, default 60 min): every lift gets 2 sets, then one at a time up to 5 to the lift whose muscles are furthest below 10 hard sets this week, until the next set would pass the budget. A set costs 40 s plus the class's rest, warmups 4 min, moving between lifts 2 min, until ten of the lifter's own timings of a kind replace the default. If two sets each do not fit, the card says how long the workout needs.</li>
      <li><b>Against last time</b> (the first reason): heavier (WEIGHT_UP), lighter (WEIGHT_DOWN), more reps (REPS_UP), fewer (REPS_DOWN) or the same (SAME_AS_LAST) than the lift's last session, and why: every rep hit, a rep missed, stopped early, time off, or the number of sets (when last time's sets would have moved it another way).</li>
      <li><b>Weight and reps from the max.</b> Stay at the last weight for as many reps as the max covers across the planned sets (one rep in reserve, half a rep more per extra set); past the top of the range, one weight step up; short of the bottom, down to the heaviest weight it covers at the bottom.</li>
    </ul>
  </details>
  <nav class="tabs" role="tablist" id="tabs"></nav>
  <section id="scenario"></section>
  <footer id="footer"></footer>
</main>
<script type="application/json" id="data">${payload}</script>
<script>
(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('data').textContent);
  var scenarios = data.scenarios;
  var tabs = document.getElementById('tabs');
  var view = document.getElementById('scenario');
  var NS = 'http://www.w3.org/2000/svg';

  function esc(v) {
    return String(v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function el(tag, attrs, html) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (html != null) e.innerHTML = html;
    return e;
  }
  function svg(tag, attrs) {
    var e = document.createElementNS(NS, tag);
    Object.keys(attrs || {}).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    return e;
  }
  function liftOf(sc, ex) {
    return sc.lifts.find(function (l) { return l.exercise === ex; });
  }
  function wt(lift, w, unit) {
    return lift.bodyweight ? 'BW' : w + ' ' + unit;
  }
  function maxText(lift, m, unit) {
    if (m == null || m === 0) return '—';
    return lift.bodyweight ? m + ' reps' : m + ' ' + unit;
  }
  function serious(sc) {
    return sc.flags.filter(function (f) { return f.severity !== 'info'; }).length;
  }
  function flagsFor(sc, n, ex) {
    return sc.flags.filter(function (f) { return f.session === n && f.exercise === ex; });
  }
  var VERSUS = ['WEIGHT_UP', 'WEIGHT_DOWN', 'REPS_UP', 'REPS_DOWN', 'SAME_AS_LAST'];
  function reasonChip(lift, r, unit) {
    var arrow;
    if (r.kind === 'SETS_FROM_TIME') arrow = r.before + '→' + r.after + ' sets';
    else if (r.kind === 'FIRST_TIME') arrow = lift.bodyweight ? '' : 'ramp ' + r.after + ' ' + unit;
    else if (VERSUS.indexOf(r.kind) >= 0) arrow = maxText(lift, r.before, unit) + ' → ' + maxText(lift, r.after, unit);
    else arrow = (r.before ? maxText(lift, r.before, unit) : '—') + ' → ' + maxText(lift, r.after, unit);
    return '<span class="chip ' + esc(r.kind) + '" title="' + esc(r.detail) + '"><b>' + esc(r.kind) + '</b> ' + esc(arrow) +
      (r.detail ? '<span class="detail">' + esc(r.detail) + '</span>' : '') + '</span>';
  }

  function chart(sc, lift) {
    var unit = sc.unit;
    var pts = [];
    sc.sessions.forEach(function (s) {
      var l = s.lifts.find(function (x) { return x.exercise === lift.exercise; });
      if (!l) return;
      var work = l.done.filter(function (d) { return d.kind === 'work'; });
      var top = null;
      work.forEach(function (d) {
        var v = lift.bodyweight ? d.reps : d.weight;
        if (top == null || v > top) top = v;
      });
      var kinds = l.decision.reasons.map(function (r) { return r.kind; });
      pts.push({
        day: s.day, n: s.n, max: l.max_after, planned: l.decision.max || null, top: top,
        miss: work.some(function (d) { return !d.hit; }),
        off: kinds.indexOf('TIME_OFF') >= 0, user: kinds.indexOf('USER_SET') >= 0,
        ramp: l.decision.calibration, removed: l.removed || work.length === 0,
        lowered: l.changes.some(function (c) { return c.cause === 'USER_ADJUST' && c.after < c.before; })
      });
    });
    if (!pts.length) return null;
    var W = 900, H = 260, L = 52, R = 14, T = 14, B = 30;
    var days = pts.map(function (p) { return p.day; });
    var d0 = Math.min.apply(null, days), d1 = Math.max.apply(null, days);
    if (d1 === d0) d1 = d0 + 1;
    var vals = [];
    pts.forEach(function (p) { [p.max, p.top, p.planned].forEach(function (v) { if (v != null) vals.push(v); }); });
    var lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals);
    var pad = Math.max((hi - lo) * 0.12, lift.bodyweight ? 1 : 5);
    lo = Math.max(0, lo - pad); hi = hi + pad;
    function x(d) { return L + (d - d0) / (d1 - d0) * (W - L - R); }
    function y(v) { return T + (1 - (v - lo) / (hi - lo)) * (H - T - B); }
    var s = svg('svg', { viewBox: '0 0 ' + W + ' ' + H, class: 'chart', role: 'img',
      'aria-label': lift.name + ': estimated max and heaviest lifted per session' });
    // Time off: a band from the previous session to the one planned with it.
    pts.forEach(function (p, i) {
      if (p.off && i > 0) {
        s.appendChild(svg('rect', { x: x(pts[i - 1].day), y: T, width: Math.max(2, x(p.day) - x(pts[i - 1].day)),
          height: H - T - B, fill: 'var(--effort-soft)', stroke: 'none' }));
      }
    });
    // Grid and axis.
    var steps = 4;
    for (var g = 0; g <= steps; g++) {
      var v = lo + (hi - lo) * g / steps;
      var yy = y(v);
      s.appendChild(svg('line', { x1: L, x2: W - R, y1: yy, y2: yy, stroke: 'var(--hairline)', 'stroke-width': 1 }));
      var t = svg('text', { x: L - 6, y: yy + 4, 'text-anchor': 'end' });
      t.textContent = Math.round(v * 10) / 10;
      s.appendChild(t);
    }
    var ylab = svg('text', { x: L - 6, y: H - 8, 'text-anchor': 'end' });
    ylab.textContent = lift.bodyweight ? 'reps' : unit;
    s.appendChild(ylab);
    var lastLabel = -Infinity;
    pts.forEach(function (p) {
      if (x(p.day) - lastLabel < 22) return;
      lastLabel = x(p.day);
      var t = svg('text', { x: x(p.day), y: H - 8, 'text-anchor': 'middle' });
      t.textContent = p.n;
      s.appendChild(t);
    });
    function line(key, attrs) {
      var d = '';
      var pen = false;
      pts.forEach(function (p) {
        var v = p[key];
        if (v == null) { pen = false; return; }
        d += (pen ? 'L' : 'M') + x(p.day).toFixed(1) + ' ' + y(v).toFixed(1) + ' ';
        pen = true;
      });
      if (d) s.appendChild(svg('path', Object.assign({ d: d, fill: 'none' }, attrs)));
    }
    line('planned', { stroke: 'var(--muted)', 'stroke-width': 1.5, 'stroke-dasharray': '4 3' });
    line('max', { stroke: 'var(--resting)', 'stroke-width': 2.5, 'stroke-linejoin': 'round' });
    pts.forEach(function (p) {
      var cx = x(p.day);
      if (p.max != null) s.appendChild(svg('circle', { cx: cx, cy: y(p.max), r: 2.5, fill: 'var(--resting)' }));
      if (p.top != null) {
        var cy = y(p.top);
        s.appendChild(svg('circle', { cx: cx, cy: cy, r: 4.5, fill: p.miss ? 'var(--panel)' : 'var(--signal)',
          stroke: p.miss ? 'var(--yapping)' : 'var(--signal)', 'stroke-width': p.miss ? 2.5 : 1 }));
        if (p.lowered) {
          s.appendChild(svg('path', { d: 'M' + (cx - 4) + ' ' + (cy + 8) + 'l4 5l4 -5', fill: 'none', stroke: 'var(--ink)', 'stroke-width': 1.5 }));
        }
      }
      if (p.user) {
        var uy = y(p.planned || p.top || lo);
        s.appendChild(svg('rect', { x: cx - 4.5, y: uy - 4.5, width: 9, height: 9, fill: 'var(--ink)',
          transform: 'rotate(45 ' + cx + ' ' + uy + ')' }));
      }
      if (p.ramp) {
        var ry = T + 2;
        s.appendChild(svg('path', { d: 'M' + (cx - 6) + ' ' + (ry + 10) + 'L' + cx + ' ' + ry + 'L' + (cx + 6) + ' ' + (ry + 10) + 'Z', fill: 'var(--resting)' }));
      }
    });
    return s;
  }

  function legend() {
    return '<div class="legend">' +
      '<span><i class="sw-line"></i>estimated max after the session</span>' +
      '<span><i class="sw-planned"></i>max the plan started from</span>' +
      '<span><i class="sw-dot"></i>heaviest lifted (reps for bodyweight)</span>' +
      '<span><i class="sw-miss"></i>a set missed</span>' +
      '<span><i class="sw-off"></i>time off</span>' +
      '<span><i class="sw-user"></i>override</span>' +
      '<span><i class="sw-ramp"></i>calibration ramp</span>' +
      '<span>⌄ weight lowered by the lifter</span>' +
      '</div>';
  }

  function workoutTable(sc) {
    var names = function (s) {
      return s.lifts.map(function (l) { return liftOf(sc, l.exercise).name + ' ' + l.decision.sets; }).join(' · ');
    };
    var rows = sc.sessions.map(function (s) {
      var flagged = sc.flags.some(function (f) { return f.session === s.n && f.exercise == null && f.severity !== 'info'; });
      var needs = s.needs_minutes != null ? ' <span class="note">needs ' + s.needs_minutes + ' min</span>' : '';
      return '<tr' + (flagged ? ' class="flagged"' : '') + '><td class="num">' + s.n + '</td><td class="mono date">' + esc(s.date) +
        '</td><td>' + s.template + '</td><td class="num">' + s.budget_minutes + '</td><td class="num">' + s.estimated_minutes + needs +
        '</td><td class="num">' + s.actual_minutes + '</td><td class="nowrap">' + esc(names(s)) + '</td><td class="mono note nowrap">' +
        'set ' + s.costs.set_seconds + 's · rest ' + s.costs.rest_heavy + '/' + s.costs.rest_standard + '/' + s.costs.rest_bodyweight +
        's · warmups ' + s.costs.warmup_seconds + 's · move ' + s.costs.between_seconds + 's</td><td class="note">' + esc(s.note) + '</td></tr>';
    }).join('');
    return '<div class="panel"><h3>Workouts</h3><p class="note">Budget, the plan\\'s estimate and the clock, in minutes; the sets each lift was given; the timings the estimate used (heavy/standard/bodyweight rest).</p><div class="scroll"><table><thead><tr><th class="num">#</th><th>Date</th><th>Tpl</th><th class="num">Budget</th><th class="num">Est.</th><th class="num">Took</th><th>Sets</th><th>Timings</th><th>Note</th></tr></thead><tbody>' + rows + '</tbody></table></div></div>';
  }

  function previewTable(sc) {
    if (!sc.previews.length) return '';
    var rows = sc.previews.map(function (p) {
      var over = p.needs_minutes != null;
      return '<tr' + (over ? ' class="flagged"' : '') + '><td>' + esc(p.template) + '</td><td class="num">' + p.budget_minutes +
        '</td><td class="num">' + p.estimated_minutes + '</td><td>' + (over ? 'needs ' + p.needs_minutes + ' min' : 'fits') + '</td><td class="mono">' +
        p.lifts.map(function (l) {
          var lift = liftOf(sc, l.exercise) || { name: l.exercise.toLowerCase().replace(/_/g, ' ') };
          return esc(lift.name) + ' ' + l.sets + '×' + l.reps;
        }).join(' · ') + '</td></tr>';
    }).join('');
    return '<div class="panel"><h3>Home preview by budget</h3><p class="note">After the last session, each template as Home would plan it at each budget: the sets every lift gets and the estimated minutes. Where two sets each do not fit, the card says how long it needs.</p><div class="scroll"><table class="narrow"><thead><tr><th>Template</th><th class="num">Budget</th><th class="num">Est.</th><th>Card</th><th>Sets per lift</th></tr></thead><tbody>' + rows + '</tbody></table></div></div>';
  }

  function liftPanel(sc, lift) {
    var unit = sc.unit;
    var rows = [];
    sc.sessions.forEach(function (s) {
      var l = s.lifts.find(function (x) { return x.exercise === lift.exercise; });
      if (!l) return;
      var d = l.decision;
      var flags = flagsFor(sc, s.n, lift.exercise);
      var cls = flags.length ? ' class="flagged' + (flags.some(function (f) { return f.severity === 'violation'; }) ? ' violation' : '') + '"' : '';
      var plan = (d.calibration ? 'ramp → ' : '') + d.sets + ' × ' + d.reps + ' @ ' + wt(lift, d.weight, unit) +
        '<br><span class="note">' + Math.round(d.estimated_seconds / 6) / 10 + ' min · rest ' + d.rest_seconds + 's' +
        (d.max ? ' · from ' + maxText(lift, d.max, unit) : '') + '</span>';
      var done = l.done.map(function (x) {
        var c = 'set' + (x.kind === 'rung' ? ' rung' : '') + (x.hit ? '' : ' miss');
        var label = (x.kind === 'rung' ? 'r' : '') + x.reps + (lift.bodyweight ? '' : '@' + x.weight);
        var tip = (x.kind === 'rung' ? 'rung ' : 'set ') + x.n + ': ' + x.reps + '/' + x.target_reps + ' reps' + (lift.bodyweight ? '' : ' at ' + x.weight + ' ' + unit);
        return '<span class="' + c + '" title="' + esc(tip) + '">' + esc(label) + '</span>';
      }).join('');
      if (l.removed) done += '<span class="note">skipped</span>';
      else if (l.undone) done += '<span class="note">' + l.undone + ' not done</span>';
      if (l.warmups_done) done += '<span class="note">+' + l.warmups_done + ' warmups</span>';
      var reasons = d.reasons.map(function (r) { return reasonChip(lift, r, unit); }).join('');
      var changes = l.changes.map(function (c) {
        return esc(c.cause.replace(/_/g, ' ').toLowerCase()) + ' ' + (lift.bodyweight ? '' : c.before + '→' + c.after) + ' <span>@' + c.minute + 'm</span>';
      }).join('<br>') || '—';
      var after = l.outcome
        ? '<span class="chip ' + esc(l.outcome.kind) + '"><b>' + esc(l.outcome.kind) + '</b></span><br>' + maxText(lift, l.max_after, unit)
        : maxText(lift, l.max_after, unit);
      rows.push('<tr' + cls + '><td class="num">' + s.n + '<br><span class="note">' + esc(s.date.slice(5)) + '</span></td><td class="plan">' + plan +
        '</td><td><div class="sets">' + done + '</div></td><td><div class="chips">' + reasons + '</div></td><td class="changes">' + changes +
        '</td><td class="num">' + after + '</td></tr>');
      flags.forEach(function (f) {
        rows.push('<tr' + cls + '><td></td><td colspan="5"><span class="mono">' + esc(f.severity.toUpperCase()) + ' · ' + esc(f.kind) + '</span> — ' + esc(f.detail) + '</td></tr>');
      });
    });
    var panel = el('div', { class: 'panel' });
    var range = lift.rep_low + '–' + lift.rep_high + ' reps';
    var start = lift.starting_weight != null ? ' · slider start ' + lift.starting_weight + ' ' + unit : '';
    panel.innerHTML = '<div class="lift-head"><h3>' + esc(lift.name) + '</h3><div class="meta"><span>' + esc(lift.class) + ' · ' + range + start + '</span></div></div>';
    var c = chart(sc, lift);
    if (c) {
      var wrap = el('div', { class: 'scroll' });
      wrap.appendChild(c);
      panel.appendChild(wrap);
    }
    panel.insertAdjacentHTML('beforeend', legend() + '<div class="scroll"><table><thead><tr><th class="num">#</th><th>Planned</th><th>Done</th><th>Why</th><th>Weight log</th><th class="num">Max after</th></tr></thead><tbody>' + rows.join('') + '</tbody></table></div>');
    return panel;
  }


  var rotation = data.rotation;
  var ROTATION_ID = 'rotation';

  function rotationWhy(d) {
    if (d.fallback) return 'nothing recovered and behind: the one done least recently';
    if (d.first_lift_recovering) return 'every first lift recovering: ' + d.first_lift_recovering.muscle + ' back soonest (' + d.first_lift_recovering.hours + 'h)';
    return d.behind.map(function (b) { return b.muscle + ' ' + b.sets + '/' + b.target; }).join(', ');
  }
  function rotationOut(d) {
    return d.recovering.map(function (r) { return r.muscle + ' ' + r.hours + 'h'; }).join(', ');
  }

  function renderRotation() {
    var r = rotation;
    var head = el('div', { class: 'panel' });
    var order = { violation: 0, warning: 1, info: 2 };
    var flags = r.flags.slice().sort(function (a, b) { return order[a.severity] - order[b.severity] || a.session - b.session; });
    var shown = flags.filter(function (f) { return f.severity !== 'info'; });
    var info = flags.filter(function (f) { return f.severity === 'info'; });
    function item(f) {
      return '<li class="' + f.severity + '"><span class="k">' + esc(f.severity) + ' · ' + esc(f.kind) + '</span>' +
        (f.session ? 'day ' + f.session + ': ' : '') + esc(f.detail) + '</li>';
    }
    var counts = {};
    r.days.forEach(function (d) { counts[d.template] = (counts[d.template] || 0) + 1; });
    head.innerHTML = '<h2>' + esc(r.title) + '</h2><p>' + esc(r.description) + '</p>' +
      '<div class="meta">' + Object.keys(counts).map(function (k) { return '<span>' + esc(k) + ' ×' + counts[k] + '</span>'; }).join('') + '</div>' +
      '<h3 style="margin-top:14px">Audit flags</h3>' +
      (shown.length ? '<ul class="flags">' + shown.map(item).join('') + '</ul>' : '<p class="ok">No violations or warnings: no repeats while another template had work, no template opening on a muscle still recovering while another was ready, Full Body at most 40%.</p>') +
      (info.length ? '<details><summary class="note" style="cursor:pointer;margin-top:8px">' + info.length + ' info</summary><ul class="flags">' + info.map(item).join('') + '</ul></details>' : '');
    view.appendChild(head);

    // Calendar: one row per week, Monday first.
    var cal = el('div', { class: 'panel' });
    var names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var html = '<h3>Calendar</h3><p class="note">Each training day: the template Home suggested and started, the muscles that won it (sets this week / target), and what was ruled out as still recovering. A template whose first lift\\'s muscle is recovering is left out. Blue: every first lift recovering, the one back soonest. Amber: the fallback.</p>';
    var weeks = {};
    r.days.forEach(function (d) {
      var t = Date.parse(d.date + 'T00:00:00Z') / 86400000;
      var monday = t - ((t + 3) % 7);
      (weeks[monday] = weeks[monday] || {})[(t + 3) % 7] = d;
    });
    Object.keys(weeks).sort(function (a, b) { return a - b; }).forEach(function (w) {
      html += '<div class="week">' + names.map(function (n) { return '<div class="wday">' + n + '</div>'; }).join('');
      for (var i = 0; i < 7; i++) {
        var d = weeks[w][i];
        if (!d) { html += '<div class="cell rest">rest</div>'; continue; }
        var out = rotationOut(d);
        html += '<div class="cell' + (d.fallback ? ' fallback' : d.first_lift_recovering ? ' waiting' : '') + '"><span class="note">' + esc(d.date.slice(5)) + ' · #' + d.n + '</span><b>' + esc(d.template) + '</b>' +
          esc(rotationWhy(d)) + (out ? '<span class="note">recovering: ' + esc(out) + '</span>' : '') + '</div>';
      }
      html += '</div>';
    });
    cal.innerHTML = html;
    view.appendChild(cal);

    // Timeline: every rotation template's score each day.
    var templates = r.days[0].candidates.map(function (c) { return c.template; });
    var rows = r.days.map(function (d) {
      return '<tr><td class="num">' + d.n + '</td><td class="mono date">' + esc(d.weekday + ' ' + d.date.slice(5)) + '</td><td><b>' + esc(d.template) + '</b><span class="detail">' + esc(rotationWhy(d)) + '</span></td>' +
        d.candidates.map(function (c) {
          var last = c.last_days == null ? 'never' : c.last_days + 'd ago';
          var wait = c.first_recovering ? ' ⏸ ' + c.first_recovering.muscle + ' ' + c.first_recovering.hours + 'h' : '';
          return '<td class="num' + (c.template === d.template ? ' won' : '') + '" title="' + esc(c.behind.join(', ')) + '">' + c.score + '<span class="detail">' + esc(last + wait) + '</span></td>';
        }).join('') +
        '<td class="note">' + esc(rotationOut(d) || '—') + '</td><td class="num">' + d.working_sets + '</td><td class="num">' + d.minutes + '</td></tr>';
    }).join('');
    view.insertAdjacentHTML('beforeend', '<div class="panel"><h3>Timeline</h3><p class="note">Each rotation template\\'s score that day (the sets its recovered primary muscles are below 10, summed; hover for which) and when it was last started. A template whose first lift\\'s muscle is recovering is left out (marked ⏸). Ties: within 20% of the best; the least recent wins.</p><div class="scroll"><table><thead><tr><th class="num">#</th><th>Day</th><th>Picked · why</th>' +
      templates.map(function (t) { return '<th class="num">' + esc(t) + '</th>'; }).join('') +
      '<th>Ruled out</th><th class="num">Sets</th><th class="num">Min</th></tr></thead><tbody>' + rows + '</tbody></table></div></div>');

    // The rotation check.
    var max = Math.max.apply(null, r.check.volume.map(function (v) { return v.sets; }).concat([1]));
    var bars = r.check.volume.map(function (v) {
      return '<span>' + esc(v.muscle) + '</span><span class="bar"><i style="width:' + (100 * v.sets / max).toFixed(1) + '%"></i></span><span class="num mono">' + v.sets + '</span>';
    }).join('');
    var warnings = r.check.warnings.map(function (w) {
      var text = w.kind === 'GAP' ? 'nothing trains ' + w.muscles.join(', ')
        : w.kind === 'OVERLAP' ? w.templates.join(' and ') + ' share ' + w.shared + ' of ' + w.of + ' lifts'
        : 'fewer than two templates in rotation';
      return '<li class="warning"><span class="k">' + esc(w.kind) + '</span>' + esc(text) + '</li>';
    }).join('');
    view.insertAdjacentHTML('beforeend', '<div class="panel"><h3>Rotation check</h3><p class="note">One pass through the rotation, each template once at three sets a lift (primary 1, secondary ½), as the template list shows it.</p><div class="bars">' + bars + '</div>' +
      (warnings ? '<ul class="flags">' + warnings + '</ul>' : '<p class="ok">Nothing wrong.</p>') + '</div>');
  }

  function render(id) {
    var isRotation = rotation && id === ROTATION_ID;
    var sc = scenarios.find(function (s) { return s.id === id; }) || scenarios[0];
    var current = isRotation ? ROTATION_ID : sc.id;
    Array.prototype.forEach.call(tabs.children, function (b) {
      var on = b.dataset.id === current;
      b.setAttribute('aria-selected', on ? 'true' : 'false');
      if (on) tabs.scrollLeft = Math.max(0, b.offsetLeft - tabs.offsetLeft - 16);
    });
    view.innerHTML = '';
    if (isRotation) {
      renderRotation();
      try { history.replaceState(null, '', '#' + ROTATION_ID); } catch (e) { /* a sandboxed frame may refuse */ }
      return;
    }
    var head = el('div', { class: 'panel' });
    var order = { violation: 0, warning: 1, info: 2 };
    var flags = sc.flags.slice().sort(function (a, b) { return order[a.severity] - order[b.severity] || a.session - b.session; });
    var shown = flags.filter(function (f) { return f.severity !== 'info'; });
    var info = flags.filter(function (f) { return f.severity === 'info'; });
    function item(f) {
      var lift = f.exercise ? liftOf(sc, f.exercise) : null;
      return '<li class="' + f.severity + '"><span class="k">' + esc(f.severity) + ' · ' + esc(f.kind) + '</span>' +
        (f.session ? 'session ' + f.session : 'Home preview') + (lift ? ', ' + esc(lift.name) : '') + ': ' + esc(f.detail) + '</li>';
    }
    head.innerHTML = '<h2>' + esc(sc.title) + '</h2><p>' + esc(sc.description) + '</p>' +
      '<div class="meta"><span>' + sc.sessions.length + ' sessions</span><span>unit ' + esc(sc.unit) + '</span><span>slider ' + sc.strength + '%</span>' +
      (sc.rest_factor !== 1 ? '<span>rests ×' + sc.rest_factor + '</span>' : '') + '</div>' +
      '<h3 style="margin-top:14px">Audit flags</h3>' +
      (shown.length ? '<ul class="flags">' + shown.map(item).join('') + '</ul>' : '<p class="ok">No violations or warnings.</p>') +
      (info.length ? '<details><summary class="note" style="cursor:pointer;margin-top:8px">' + info.length + ' info</summary><ul class="flags">' + info.map(item).join('') + '</ul></details>' : '');
    view.appendChild(head);
    view.insertAdjacentHTML('beforeend', previewTable(sc) + workoutTable(sc));
    sc.lifts.forEach(function (lift) { view.appendChild(liftPanel(sc, lift)); });
    try { history.replaceState(null, '', '#' + sc.id); } catch (e) { /* a sandboxed frame may refuse */ }
  }

  scenarios.forEach(function (sc) {
    var n = serious(sc);
    var b = el('button', { class: 'tab', role: 'tab', type: 'button', 'data-id': sc.id },
      esc(sc.title) + (n ? '<span class="count">' + n + '</span>' : ''));
    b.addEventListener('click', function () { render(sc.id); window.scrollTo(0, 0); });
    tabs.appendChild(b);
  });
  if (rotation) {
    var rn = serious(rotation);
    var rb = el('button', { class: 'tab', role: 'tab', type: 'button', 'data-id': ROTATION_ID },
      'Rotation' + (rn ? '<span class="count">' + rn + '</span>' : ''));
    rb.addEventListener('click', function () { render(ROTATION_ID); window.scrollTo(0, 0); });
    tabs.appendChild(rb);
  }
  var total = scenarios.reduce(function (a, sc) { return a + serious(sc); }, 0) + (rotation ? serious(rotation) : 0);
  document.getElementById('footer').textContent = 'Generated from testdata/progression_scenarios.json (' + data.generated_by + '). ' +
    total + ' warnings and violations across ' + scenarios.length + ' scenarios.';
  render((location.hash || '').slice(1));
})();
</script>
</body>
</html>
`;

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, page);
console.log(
  `wrote ${out} (${(page.length / 1024).toFixed(0)} KB, ${data.scenarios.length} scenarios)`,
);
