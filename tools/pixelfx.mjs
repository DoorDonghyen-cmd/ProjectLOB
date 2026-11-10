// Project entry point; upstream source stays untouched outside the Godot project.
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, resolve, join, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
let source;
for (let parent = repo; ; parent = dirname(parent)) {
  const candidate = join(parent, '.tools/pixelfx/source');
  if (existsSync(join(candidate, 'src/fx/index.js'))) { source = candidate; break; }
  if (parent === dirname(parent)) break;
}
if (!source) {
  console.error('pixelfx is not installed. See docs/art/pixel-tools.md.');
  process.exit(1);
}
const [action = 'help', ...args] = process.argv.slice(2);
if (action === 'gallery') {
  const port = Number(args[0] ?? 8766);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid port');
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
    '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
    '.png': 'image/png', '.gif': 'image/gif', '.svg': 'image/svg+xml',
    '.woff2': 'font/woff2', '.md': 'text/plain; charset=utf-8' };
  createServer(async (req, res) => {
    try {
      let path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      if (path === '/_lob_pixelfx') {
        res.writeHead(200, { 'content-type': 'application/json' });
        return res.end(JSON.stringify({ tool: 'LoB pixelfx', version: 1 }));
      }
      if (path === '/') { res.writeHead(302, { location: '/gallery/' }); return res.end(); }
      if (path.endsWith('/')) path += 'index.html';
      const file = resolve(source, '.' + path);
      // Only the gallery and code needed for its effects are served, on loopback.
      if (!file.startsWith(source + sep) || !['gallery', 'src'].includes(path.split('/')[1])) {
        res.writeHead(403); return res.end();
      }
      const body = await readFile(file);
      res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream',
        'cache-control': 'no-store' });
      res.end(body);
    } catch { res.writeHead(404); res.end('not found'); }
  }).listen(port, '127.0.0.1', () => console.log(`http://127.0.0.1:${port}/gallery/`));
} else if (['list', 'render', 'check'].includes(action)) {
  if (action === 'render' && !args.some(a => a === '--out')) {
    args.push('--out', join(repo, 'qa_runtime/pixelfx_exports'));
  }
  const result = spawnSync(process.execPath, [join(source, `tools/${action}.mjs`), ...args],
    { stdio: 'inherit', cwd: process.cwd() });
  if (result.error) console.error(result.error.message);
  process.exit(result.status ?? 1);
} else {
  console.log('PIXELFX.cmd list [search words]\nPIXELFX.cmd render impacts/bullet-impact --sheet\nPIXELFX.cmd check impacts/bullet-impact\nOPEN_PIXELFX.cmd  (gallery on 127.0.0.1:8766)');
  if (!['help', '--help', '-h'].includes(action)) process.exitCode = 1;
}
