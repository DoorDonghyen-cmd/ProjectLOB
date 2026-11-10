// State regression checks against the shipped inline script. Browser input and
// layout are verified separately through the public UI; this is not a DOM mock QA.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root, 'docs/qa/reports/ui_prototype_2026-10-31');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
const source = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
new vm.Script(source, { filename: 'index.html:inline' });
function element() {
  return { dataset: {}, style: {}, classList: { add() {}, remove() {} },
    querySelector() { return null; }, querySelectorAll() { return []; },
    appendChild() {}, remove() {}, addEventListener() {}, setAttribute() {},
    clientWidth: 1280, clientHeight: 520, innerHTML: '' };
}
const elements = new Map();
const fixtures = JSON.parse(fs.readFileSync(path.join(root,'qa_runtime/ui_prototype_model/client_fixtures.json'),'utf8'));
const context = vm.createContext({ console, setTimeout, clearTimeout, fixtures,
  location: { hash: '#theme=line' },
  window: { addEventListener() {} },
  document: { documentElement: element(), getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
    querySelectorAll() { return []; }, addEventListener() {}, createElement: element },
  history: { replaceState() {} }, CSS: { escape: (s) => s } });
vm.runInContext(fs.readFileSync(path.join(dir, 'assets/game_data.js'), 'utf8'), context);
vm.runInContext(fs.readFileSync(path.join(dir,'assets/combat_model.js'),'utf8'), context);
vm.runInContext(source.slice(0, source.lastIndexOf('document.fonts.load')), context);
const run = (code) => vm.runInContext(code, context);
const get = (code) => JSON.parse(JSON.stringify(run(code)));
run(`render = () => {}; renderCombat = () => {}; renderOverlay = () => {};
  drawField = () => {}; toast = () => {}; fieldGeom = () => ({s:1,oy:0});
  enemyCenter = () => [300,300];
  const fakeField = document.createElement('div');
  app.querySelector = (selector) => selector === '#field' ? fakeField : null;
  let pendingResponse = null, apiCalls = 0;
  fetch = async (_url, options) => { apiCalls++; return {ok:true,headers:{get:()=> 'application/json'}, json:async()=> pendingResponse ? await pendingResponse : clone(fixtures.preview)}; };
  function setup() { newRun(); G.screen='combat'; C={kind:'boss',title:'test',seed:731042,result:null}; applyCombat(clone(fixtures.opening)); }
`);
let passed = 0;
async function check(name, fn) { await fn(); passed++; console.log('PASS ' + name); }

await check('victory settles once and terminal commands make no requests', async () => {
  run('setup(); win(); win();'); assert.equal(run('G.cr'),95);
  const before=get('C'), requests=run('apiCalls'); await run('fire()'); await run('reload(false)');
  assert.deepEqual(get('C'),before); assert.equal(run('apiCalls'),requests);
  run('setup(); lose();'); const lost=get('C'); await run('fire()'); assert.deepEqual(get('C'),lost);
});
await check('selected rounds block fire, cooling and exchange before the service',async()=>{
  run('setup(); C.selected=[2];'); const before=get('C'),requests=run('apiCalls');
  await run('fire()');await run('combatCommand("cool")');await run('reload(false)');
  assert.deepEqual(get('C'),before);assert.equal(run('apiCalls'),requests);
});
await check('clearing selection discards a late preview without restoring it',async()=>{
  run('setup(); let releasePreview; pendingResponse=new Promise(resolve=>{releasePreview=resolve});');
  const selecting=run('selectRound(2)'); run('clearSelection(); releasePreview(clone(fixtures.preview));'); await selecting;
  assert.deepEqual(get('C.selected'),[]);assert.equal(run('C.preview'),null);assert.equal(run('C.previewBusy'),false);
  run('pendingResponse=null;');
});
await check('details remain available after ejection allowance is exhausted',async()=>{
  run('setup(); C.eject_left=0;'); await run('selectRound(1)');
  assert.equal(run('overlay.type'),'ammo');assert.deepEqual(get('C.selected'),[]);
});
await check('selection never exceeds remaining allowance',async()=>{
  run('setup(); C.eject_left=1;');await run('selectRound(2)');await run('selectRound(3)');
  assert.deepEqual(get('C.selected'),[2]);
});
await check('unavailable workshop tune does not spend a visit', () => {
  run(`newRun(); G.deck=Array(10).fill('basic_p3'); G.screen='place'; G.place=makePlace('workshop');`);
  assert.match(run('placeProblem(G.place,G.place.options[0])'), /개조할/);
  const before=get('G'); run('confirmPlace()'); assert.deepEqual(get('G'),before);
});
await check('workshop valid target and minimum deck are enforced at execution', () => {
  run(`newRun(); G.deck=['basic_p2',...Array(7).fill('basic_p3')]; G.screen='place'; G.place=makePlace('workshop');`);
  assert.match(run('placeProblem(G.place,G.place.options[1])'), /최소 8장/);
  run('confirmPlace()'); assert.equal(run('G.deck[0]'),'basic_p3');
  assert.equal(run('G.deck.length'),8); assert.equal(run('G.visited.length'),1);
});
await check('reward cannot exceed capacity or be confirmed twice', () => {
  run(`newRun(); G.bag=G.deck.length; G.screen='place'; G.place=makePlace('reward');`);
  const before=get('G'); run('confirmPlace()'); assert.deepEqual(get('G'),before);
  run('G.bag++; confirmPlace(); confirmPlace();');
  assert.equal(run('G.deck.length'),11); assert.equal(run('G.visited.length'),1);
});
await check('purchase completes once, presents completed result and guards capacity', () => {
  run(`newRun(); G.cr=34; G.screen='shop'; G.shop=makeShop(); G.shop.pick=1; shopAction('buy'); shopAction('buy'); renderShop();`);
  assert.equal(run('G.cr'),4); assert.equal(run('G.parts.length'),3);
  assert.match(elements.get('app').innerHTML,/구매 완료/);
  assert.doesNotMatch(elements.get('app').innerHTML,/구매 후 -|→ -26/);
  run(`G.shop.pick=0; G.cr=75; G.bag=G.deck.length; shopAction('buy');`);
  assert.equal(run('G.cr'),75); assert.equal(run('G.deck.length'),10);
});
await check('restart ignores an in-flight combat response',async()=>{
  run('setup(); let releaseFire; pendingResponse=new Promise(resolve=>{releaseFire=resolve});');
  const firing=run('fire()');run('newRun(); releaseFire(clone(fixtures.fired));');await firing;
  assert.equal(run('G.screen'),'map');assert.equal(run('C'),null);assert.equal(run('busy'),false);assert.equal(run('G.cr'),75);
  run('pendingResponse=null;');
});
run('clearTimeout(transitionTimer)');
console.log(`PASS ${passed} state regressions; browser interactions require separate evidence.`);
