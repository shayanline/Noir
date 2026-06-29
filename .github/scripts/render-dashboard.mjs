// Renders the branch preview dashboard as a static page on the gh-pages branch.
// Zero dependencies, Node built-ins only.
//
//   node render-dashboard.mjs <gh-pages-root>
//
// It rebuilds the whole page from durable truth every time, so it never relies
// on an incremental edit that a concurrent run could drop:
//   - the deployed previews are the folders that carry a _meta.json (master at
//     the root, every other branch under branches/<slug>/),
//   - the open pull request per branch comes from the GitHub API.
// The page is written to <gh-pages-root>/_dashboard/index.html. The only input
// that is not on disk is the PR list, and a stale PR column self heals on the
// next render, so a lost write is never permanent.

import { readdirSync, readFileSync, writeFileSync, existsSync, statSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2];
if (!root) {
  console.error('usage: render-dashboard.mjs <gh-pages-root>');
  process.exit(1);
}

const repo = process.env.GITHUB_REPOSITORY || '';
const repoUrl = repo ? `https://github.com/${repo}` : '';

const readMeta = (p) => {
  try {
    return JSON.parse(readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
};

// master's meta is at the root, every other branch lives under branches/<slug>/.
// Reading only those two places means stray folders on gh-pages are ignored and
// a branch can never inject a row from anywhere else.
function collectMetas(dir) {
  const metas = [];
  const rootMeta = readMeta(join(dir, '_meta.json'));
  if (rootMeta) metas.push(rootMeta);
  const branchesDir = join(dir, 'branches');
  if (existsSync(branchesDir) && statSync(branchesDir).isDirectory()) {
    for (const name of readdirSync(branchesDir)) {
      const sub = join(branchesDir, name);
      if (!statSync(sub).isDirectory()) continue;
      const meta = readMeta(join(sub, '_meta.json'));
      if (meta) metas.push(meta);
    }
  }
  return metas;
}

// Map of head branch to { number, url } for the open pull request. PR links are
// optional, so any problem (missing token, rate limit, transient error) just
// degrades the column to a dash and never fails the render or the deploy. Only
// same repo pull requests count, since a fork PR can share a branch name with a
// local branch, and the lowest numbered PR wins when a branch has more than one.
async function fetchOpenPrs() {
  const token = process.env.GITHUB_TOKEN;
  const map = new Map();
  if (!repo || !token) return map;

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'inkfall-preview-dashboard',
  };
  try {
    for (let page = 1; ; page++) {
      const res = await fetch(
        `https://api.github.com/repos/${repo}/pulls?state=open&per_page=100&page=${page}`,
        { headers },
      );
      if (!res.ok) throw new Error(`GitHub API ${res.status}: ${await res.text()}`);
      const prs = await res.json();
      for (const pr of prs) {
        // Ignore fork PRs: their head ref can collide with a local branch name.
        if (!pr.head.repo || pr.head.repo.full_name !== repo) continue;
        const prev = map.get(pr.head.ref);
        if (!prev || pr.number < prev.number) {
          map.set(pr.head.ref, { number: pr.number, url: pr.html_url });
        }
      }
      if (prs.length < 100) break;
    }
  } catch (err) {
    console.warn(`render-dashboard: could not fetch pull requests, rendering without PR links: ${err.message}`);
    return new Map();
  }
  return map;
}

// Set of branch names that currently exist on the remote. Returns null when the
// repo or token is missing, or on any error, meaning "unknown, do not filter",
// so a transient failure never hides live previews.
async function fetchExistingBranches() {
  const token = process.env.GITHUB_TOKEN;
  if (!repo || !token) return null;

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'inkfall-preview-dashboard',
  };
  const names = new Set();
  try {
    for (let page = 1; ; page++) {
      const res = await fetch(
        `https://api.github.com/repos/${repo}/branches?per_page=100&page=${page}`,
        { headers },
      );
      if (!res.ok) throw new Error(`GitHub API ${res.status}: ${await res.text()}`);
      const branches = await res.json();
      for (const b of branches) names.add(b.name);
      if (branches.length < 100) break;
    }
  } catch (err) {
    console.warn(`render-dashboard: could not list branches, not filtering: ${err.message}`);
    return null;
  }
  return names;
}

// One row per branch: keep the most recently updated meta when a branch somehow
// has more than one deployed folder (for example after the slug scheme changed),
// and drop any folder whose branch no longer exists (master is always kept).
function oneRowPerBranch(metas, existing) {
  const byBranch = new Map();
  for (const m of metas) {
    const prev = byBranch.get(m.branch);
    if (!prev || (m.updated || '') > (prev.updated || '')) byBranch.set(m.branch, m);
  }
  let list = [...byBranch.values()];
  if (existing) list = list.filter((m) => m.branch === 'master' || existing.has(m.branch));
  return list;
}

const order = (a, b) =>
  a.branch === b.branch ? 0
    : a.branch === 'master' ? -1
    : b.branch === 'master' ? 1
    : a.branch.localeCompare(b.branch);

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]),
  );

function row(meta, prs) {
  const pr = prs.get(meta.branch);
  const status = meta.status || 'deployed';
  const prCell = pr
    ? `<a href="${esc(pr.url)}">#${esc(pr.number)}</a>`
    : '<span class="muted">-</span>';
  const commitCell = repoUrl && meta.sha
    ? `<a href="${repoUrl}/commit/${esc(meta.sha)}"><code>${esc(meta.sha)}</code></a>`
    : `<code>${esc(meta.sha || '')}</code>`;
  // The stored stamp is UTC. The visible text is the UTC value, which the inline
  // script below rewrites to relative local time ("2 hours ago") in the viewer's
  // browser. Without script the UTC fallback still reads fine.
  const updatedCell = meta.updated
    ? `<td class="updated" data-utc="${esc(meta.updated)}">${esc(meta.updated)} UTC</td>`
    : '<td class="muted">-</td>';
  return `      <tr>
        <td><code>${esc(meta.branch)}</code></td>
        <td><a href="${esc(meta.url)}">open</a></td>
        <td>${prCell}</td>
        <td><span class="badge ${esc(status)}">${esc(status)}</span></td>
        ${updatedCell}
        <td>${commitCell}</td>
      </tr>`;
}

function page(metas, prs) {
  const now = new Date().toISOString().replace('T', ' ').slice(0, 16);
  const rows = metas.length
    ? metas.map((m) => row(m, prs)).join('\n')
    : '      <tr><td colspan="6" class="muted">No previews are currently deployed.</td></tr>';
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="30">
  <title>Inkfall branch previews</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin: 0; padding: 2.5rem 1.25rem; background: #0c0c0e; color: #e7e7ea;
      font: 15px/1.5 ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
    }
    main { max-width: 1000px; margin: 0 auto; }
    h1 { font-size: 1.4rem; letter-spacing: 0.08em; text-transform: uppercase; margin: 0 0 0.25rem; }
    .sub { color: #9a9aa2; margin: 0 0 1.75rem; font-size: 0.9rem; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 0.6rem 0.75rem; border-bottom: 1px solid #222228; }
    th { color: #9a9aa2; font-weight: 600; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; }
    code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.85em; }
    a { color: #c8b3ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .muted { color: #6a6a72; }
    .badge {
      display: inline-block; padding: 0.1rem 0.55rem; border-radius: 999px;
      font-size: 0.74rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em;
    }
    .badge.deployed { background: #15351f; color: #6ee7a0; }
    .badge.building { background: #3a2f12; color: #f4cd63; animation: pulse 1.2s ease-in-out infinite; }
    .badge.failed { background: #3a1620; color: #ff8597; }
    @keyframes pulse { 50% { opacity: 0.45; } }
  </style>
</head>
<body>
  <main>
    <h1>Inkfall branch previews</h1>
    <p class="sub">Live build of every branch. This page refreshes itself, and rebuilds from the deployed folders on each run. Generated ${esc(now)} UTC.</p>
    <table>
      <thead>
        <tr><th>Branch</th><th>Preview</th><th>PR</th><th>Status</th><th>Updated</th><th>Commit</th></tr>
      </thead>
      <tbody>
${rows}
      </tbody>
    </table>
  </main>
  <script>
    (function () {
      var rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });
      var units = [['year', 31536000], ['month', 2592000], ['week', 604800], ['day', 86400], ['hour', 3600], ['minute', 60]];
      function ago(date) {
        var diff = (date.getTime() - Date.now()) / 1000;
        for (var i = 0; i < units.length; i++) {
          if (Math.abs(diff) >= units[i][1]) return rtf.format(Math.round(diff / units[i][1]), units[i][0]);
        }
        return rtf.format(Math.round(diff), 'second');
      }
      function render() {
        var cells = document.querySelectorAll('.updated[data-utc]');
        for (var i = 0; i < cells.length; i++) {
          var raw = cells[i].getAttribute('data-utc').replace(' ', 'T');
          var date = new Date(/T\d\d:\d\d:\d\d/.test(raw) ? raw + 'Z' : raw + ':00Z');
          if (isNaN(date.getTime())) continue;
          cells[i].textContent = ago(date);
          cells[i].title = date.toLocaleString();
        }
      }
      render();
    })();
  </script>
</body>
</html>
`;
}

const existing = await fetchExistingBranches();
const metas = oneRowPerBranch(collectMetas(root), existing).sort(order);
const prs = await fetchOpenPrs();
const outDir = join(root, '_dashboard');
if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'index.html'), page(metas, prs));
console.log(`rendered ${metas.length} preview row(s) to _dashboard/index.html`);
