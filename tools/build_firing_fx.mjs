// Flash-only remix of pixelfx's MIT projectile lobe recipe. No casing, pellets,
// smoke emitters or runtime JavaScript is shipped into Godot.
import { existsSync, mkdirSync, writeFileSync, copyFileSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
let source;
for (let p = repo; ; p = dirname(p)) {
  if (existsSync(join(p, '.tools/pixelfx/source/src/fx/index.js'))) { source = join(p, '.tools/pixelfx/source'); break; }
  if (p === dirname(p)) throw new Error('Run the pinned pixelfx installer first.');
}
const { flashShape, flash } = await import(pathToFileURL(join(source, 'src/fx/projectiles/_lib.js')));
const { rng, fit } = await import(pathToFileURL(join(source, 'src/core/index.js')));
const { renderFrames, spriteSheet, contactSheet } = await import(pathToFileURL(join(source, 'tools/lib/fxlib.mjs')));
const profiles = [
  { id: 'single', spike: [18, 21], diag: [7, 10], cross: [3, 5], back: [1, 2], size: 1 },
  { id: 'burst', spike: [28, 31], diag: [3, 5], cross: [2, 3], back: [0, 1], size: 1 },
  { id: 'scatter', spike: [16, 19], diag: [16, 22], cross: [7, 10], back: [1, 2], size: 1.15 },
  { id: 'heavy', spike: [21, 25], diag: [10, 14], cross: [6, 8], back: [1, 3], size: 1.3 },
  { id: 'amplifier', spike: [38, 42], diag: [3, 4], cross: [1, 2], back: [0, 1], size: 1 },
];
const meta = { name: 'LoB gun muzzle flashes', desc: 'One pulse per resolved shot', tags: ['muzzle'], size: [96, 64], origin: [20, 32], duration: 5 / 48, fps: 48, loop: false, bg: 'none', options: { seed: 17 } };
const frames = [];
for (const [index, spec] of profiles.entries()) {
  const mod = { meta, create(o) {
    let t = 0;
    return { update(dt) { t += dt; }, draw(p) {
      const step = Math.round(t * 48);
      if (step >= 4) return;
      const lobes = flashShape(rng(o.seed + index * 31), step < 2 ? 1 : 2, spec);
      // The long needle has no sideways star; the broad flash is escaping gas,
      // not extra projectiles. Keep the source image neutral for runtime tint.
      if (spec.id === 'amplifier') lobes.splice(2);
      flash(p, 0, 0, 0, lobes,
        fit(step < 2 ? ['#ffffff', '#eeefec', '#c5c7c4', '#767b7e'] : ['#dddeda', '#bcbeba', '#8c9293', '#555c60'], 4),
        17 + index);
    } };
  } };
  const rendered = renderFrames({ id: spec.id, meta, mod }, { fps: 48, seed: 17, bg: 'none', actor: false });
  if (rendered.frames.length !== 6) throw new Error('Expected six frames per gun');
  frames.push(...rendered.frames);
}
const fx = { id: 'lob/muzzle-five-guns', meta, mod: { meta } };
const rendered = { w: 96, h: 64, fps: 48, n: frames.length, frames, margin: 0 };
const sheet = spriteSheet(fx, rendered, 'muzzle');
const out = join(repo, '새-게임-프로젝트/assets/art/firing_fx_20261106');
const qa = join(repo, 'qa_runtime/firing_fx_20261106');
mkdirSync(out, { recursive: true }); mkdirSync(qa, { recursive: true });
writeFileSync(join(out, 'muzzle.png'), sheet.png);
sheet.json.meta.profiles = profiles.map((p, i) => ({ gun: p.id, first: i * 6, frames: 6 }));
writeFileSync(join(out, 'muzzle_source.json'), JSON.stringify(sheet.json, null, 2) + '\n');
writeFileSync(join(qa, 'muzzle_contact.png'), contactSheet(fx, rendered, { max: 30, width: 1500, zoom: 2 }));
copyFileSync(join(source, 'LICENSE'), join(out, 'LICENSE.txt'));
copyFileSync(join(repo, 'tools/notices/pixelfx/NOTICE.md'), join(out, 'NOTICE.md'));
const sha = file => createHash('sha256').update(readFileSync(file)).digest('hex');
writeFileSync(join(out, 'provenance.json'), JSON.stringify({ source: 'https://github.com/patch-gg/pixelfx', version: '0.3.0', commit: 'a84159688af3ca37a4be05a0d422b94451b2e24e', recipe: 'src/fx/projectiles/_lib.js flashShape/flash', build: 'node tools/build_firing_fx.mjs', frames: 30, seed: 17, pivot: [20,32], profiles: profiles.map(p=>p.id), sha256: { atlas: sha(join(out,'muzzle.png')), metadata: sha(join(out,'muzzle_source.json')), builder: sha(fileURLToPath(import.meta.url)), upstream_recipe: sha(join(source,'src/fx/projectiles/_lib.js')) }, exclusions: ['stock actor', 'smoke', 'casing', 'projectiles', 'runtime JavaScript'] }, null, 2) + '\n');
console.log(`Built ${sheet.json.meta.size.w}x${sheet.json.meta.size.h}, 30 flash frames`);
