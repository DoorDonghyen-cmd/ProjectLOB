// Bake pinned pixelfx recipes for Godot. No particle simulation or JS at runtime.
import { existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
let source;
for (let p = repo; ; p = dirname(p)) {
  if (existsSync(join(p, '.tools/pixelfx/source/src/fx/index.js'))) { source = join(p, '.tools/pixelfx/source'); break; }
  if (p === dirname(p)) throw new Error('Install the pinned pixelfx tool first.');
}
const { loadEffect, renderFrames, spriteSheet, contactSheet } = await import(pathToFileURL(join(source, 'tools/lib/fxlib.mjs')));
const { fit } = await import(pathToFileURL(join(source, 'src/core/index.js')));
const { burn, hotFirst, noiseFor } = await import(pathToFileURL(join(source, 'src/fx/fire/_lib.js')));
const out = join(repo, '새-게임-프로젝트/assets/art/surface_fx_20261106');
const qa = join(repo, 'qa_runtime/surface_fx_20261106');
mkdirSync(out, { recursive: true }); mkdirSync(qa, { recursive: true });
const provenance = { source: 'https://github.com/patch-gg/pixelfx', version: '0.3.0', commit: 'a84159688af3ca37a4be05a0d422b94451b2e24e', build: 'node tools/build_surface_fx.mjs', assets: {}, excluded: ['stock actor', 'torch bracket/handle', 'runtime JavaScript', 'runtime particles/RNG'] };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function save(name, fx, rendered, pivot, options) {
  const sheet = spriteSheet(fx, rendered, name);
  writeFileSync(join(out, name + '.png'), sheet.png);
  sheet.json.meta.contact = pivot;
  writeFileSync(join(out, name + '_source.json'), JSON.stringify(sheet.json, null, 2) + '\n');
  writeFileSync(join(qa, name + '_contact.png'), contactSheet(fx, rendered, { max: 6, zoom: 2 }));
  provenance.assets[name] = { recipe: fx.id, options, pivot, frames: rendered.n, cell: [rendered.w, rendered.h], columns: sheet.json.meta.pixelfx.columns, size: sheet.json.meta.size, sha256: hash(sheet.png) };
}
const shield = await loadEffect('impacts/shield-block');
const shieldOptions = { seed: 12, palette: ['#18272e','#263d48','#365362','#527786','#8aafb2','#b1c9c8','#d1ddd4','#ede9d2'], sparks: ['#f0ddab','#d0b67a','#ae875a','#765c47'] };
// Upstream dome impact (lon1.18, lat0.5) is distinct from its floor pivot.
save('shield', shield, renderFrames(shield,{ fps:20, seed:12, options:shieldOptions, actor:false, bg:'none' }), [40+3+28*Math.cos(0.5)*Math.sin(1.18),88-44*Math.sin(0.5)], shieldOptions);
const metal = await loadEffect('impacts/bullet-impact');
const metalOptions = { seed:6, height:24, stone:'#5a6466', palette:['#25343b','#546160','#8c8b76','#b3a579','#d0bd86','#e7d5a9','#f1ead0'] };
save('metal', metal, renderFrames(metal,{fps:20,seed:6,options:metalOptions,actor:false,bg:'none'}),[116,60],metalOptions);
const fireOptions = { seed:29, palette:['#2a2522','#563c31','#81503b','#ab6544','#d48b54','#e5ac6e','#f1c890','#f4dfb0','#f5e9cf'] };
const meta = { name:'LoB low fire', desc:'Flame-only loop, no prop', size:[64,64], origin:[32,56], duration:1, fps:12, loop:true, bg:'none', options:fireOptions };
const mod = { meta, draw(p,t,o) {
  burn(p,t,[[-4,0,0.65,1.9,1],[4,0,0.7,2.2,0],[0,0,1,2.8,0]],{ H:hotFirst(fit(o.palette,9)), D:1, NL:noiseFor(1), S:o.seed, x:0, y:0, height:20, spread:5, lean:0.08, puffs:2, licks:2, smoke:1, smokeSize:1, smokeLife:[0.5,0.8], embers:3, glowR:14, glow:0.25, wind:1 });
} };
save('fire', {id:'lob/fire-only (fire/_lib.js burn)',meta,mod}, renderFrames({id:'lob/fire-only',meta,mod},{fps:12,seed:29,bg:'none',actor:false}),[32,56],fireOptions);
copyFileSync(join(source,'LICENSE'),join(out,'LICENSE.txt'));
copyFileSync(join(repo,'tools/notices/pixelfx/NOTICE.md'),join(out,'NOTICE.md'));
provenance.builder_sha256=hash(readFileSync(fileURLToPath(import.meta.url)));
writeFileSync(join(out,'provenance.json'),JSON.stringify(provenance,null,2)+'\n');
console.log(Object.entries(provenance.assets).map(([id,a])=>`${id}: ${a.frames} frames, ${a.size.w}x${a.size.h}, pivot ${a.pivot}`).join('\n'));
