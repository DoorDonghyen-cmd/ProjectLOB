/* Presentation adapter only. The localhost service executes Model + Forecast. */
let previewSerial = 0;
const alive = (list) => list.filter(e => e.hp > 0).sort((a,b) => a.d-b.d);
const cardOf = (uid) => C.hand.find(c => c.uid === uid);
const ammoOf = (id) => ({...AMMO[id], ...(C && C.ammo ? C.ammo[id] : {})});
const enemyView = (e, i) => ({...e, uid:i+1, max:e.max_hp, d:e.distance,
  chargeMax:e.charge_max || 0, charge:e.charge || 0, weak:e.weakness === 'electric'});

async function combatRequest(action, extra = {}, state = C) {
  const response = await fetch('/api/combat', {method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({action, session:state && state.session, revision:state && state.revision, ...extra})});
  if (!(response.headers.get('content-type') || '').includes('application/json'))
    throw new Error('전투 서버 연결이 필요합니다. OPEN_UI_PROTOTYPE.cmd로 다시 실행하세요.');
  const result = await response.json();
  if (!response.ok || !result.ok) throw new Error(result.error || '전투 연결을 확인하세요.');
  return result;
}
function applyCombat(result) {
  const v = result.view;
  Object.assign(C, v, {session:result.session, revision:result.revision,
    hand:v.magazine.map((id,i) => ({id,uid:i+1})), enemies:v.enemies.map(enemyView),
    selected:[], preview:null, previewBusy:false, error:'', loaded:true});
  C.baseForecast = v.forecast;
}
async function startCombat(node, retrySeed) {
  if (!node || !['combat','elite','boss'].includes(node.kind)) return;
  screenTransition();
  const my = epoch;
  C = {kind:node.kind, title:node.kind === 'elite' ? '정예 · 약탈단 두목' : node.kind === 'boss' ? '관문 · 약탈단 본대' : '전투 · '+(node.name || '순찰 구역'),
    seed:retrySeed ?? Math.floor(Math.random()*100000000), hand:[],draw:[],used:[],enemies:[],reserve:[],selected:[],
    heat:0,actions:0,result:null,capacity:CAPACITY,heat_limit:HEAT_LIMIT,eject_left:2,commands:{},ammo:{},loaded:false,error:''};
  G.screen='combat'; overlay=null; busy=true; render();
  try {
    const result = await combatRequest('new',{kind:C.kind,deck:G.deck,parts:G.parts,seed:C.seed});
    await tick(my,0); applyCombat(result); busy=false; renderCombat(); return true;
  } catch (error) { if (my !== epoch || error === ABORT) return; busy=false; C.error=error.message; renderCombat(); }
}
function forecast() {
  if (!combatActive() || !C.loaded || C.previewBusy) return null;
  const f = C.selected.length ? C.preview && C.preview.forecast : C.baseForecast;
  if (!f || !f.shots || !f.shots.length) return null;
  return {shots:f.shots, enemies:f.enemies.map(enemyView), heat:f.heat.peak_max,
    overheat:f.heat.forced_probability>0, actions:f.turns, lose:f.phase==='lost', win:['won','reward'].includes(f.phase)};
}
function clearSelection() {
  if (!combatReady() || overlay || !C.selected.length) return;
  previewSerial++; C.selected=[]; C.preview=null; C.previewBusy=false; renderCombat();
}
async function selectRound(uid) {
  if (!combatReady() || overlay || !cardOf(uid)) return;
  if (!C.eject_left) { overlay={type:'ammo',uid}; return renderOverlay(); }
  const index=C.selected.indexOf(uid);
  if (index>=0) C.selected.splice(index,1);
  else if (C.selected.length<C.eject_left) C.selected.push(uid);
  else return toast(`이번 탄창에서 ${C.eject_left}발까지 선택할 수 있습니다.`);
  const serial=++previewSerial, my=epoch;
  C.preview=null; C.previewBusy=!!C.selected.length; renderCombat();
  if (!C.selected.length) return;
  try {
    const result=await combatRequest('preview',{indices:C.selected.map(n=>n-1)});
    if (my!==epoch || serial!==previewSerial) return;
    C.preview=result.view; C.previewBusy=false; renderCombat();
  } catch(error) {
    if (my!==epoch || serial!==previewSerial) return;
    C.previewBusy=false; C.error=error.message; renderCombat();
  }
}
function renderCombat() {
  const focusBefore=focusKey(document.activeElement);
  const scrollBefore=$('.magazine')?.scrollLeft || 0;
  const fc=forecast(), locked=!combatReady(), selected=C.selected.length>0;
  const retained=C.hand.filter(c=>!C.selected.includes(c.uid));
  const next=retained.slice(0,fc ? fc.shots.length : 0).map(c=>c.uid);
  const usedSlots=C.hand.reduce((sum,c)=>sum+(ammoOf(c.id).slots||1),0);
  const cards=C.hand.map(c=>{
    const a=ammoOf(c.id), excluded=C.selected.includes(c.uid), ord=next.indexOf(c.uid)+1;
    return `<button class="kit card k-standby ${excluded?'excluded':ord?'next-round':''}" data-a="card" data-uid="${c.uid}" aria-pressed="${excluded}" aria-label="${c.uid}번 ${esc(a.name)}${excluded?' 제외 선택':''}" ${locked?'disabled':''} style="--slots:${a.slots||1}">
      <span class="ord">${excluded?'제외':ord||''}</span><div class="nm">${esc(a.name)}</div>
      <div class="mid"><img src="${roundSrc(c.id)}" alt=""><div><div class="sl">${esc(a.stat_label)}</div><div class="sv">${esc(a.stat_value)}</div></div></div>
      <div class="ht">열 ${esc(a.heat_label)}${a.anchor?' · '+(a.anchor==='first'?'첫 발':'마지막'):''}${a.slots>1?' · '+a.slots+'칸':''}</div></button>`;
  }).join('') + Array.from({length:Math.max(0,C.capacity-usedSlots)},()=>'<button class="empty-slot" data-a="clear" aria-label="빈 탄창 칸 · 선택 취소"><span>빈칸</span></button>').join('');
  const fireSub=selected?'선택 취소 후 사격':!fc?'':fc.win?'전투 마무리':fc.lose?'사격 후 패배':`${fc.overheat?'과열 · ':''}적 ${fc.actions}행동`;
  const commandSub=(key)=>{const p=C.commands[key];return !p||!p.valid?'':p.lose?'실행 시 패배':p.win?'마무리':`적 ${p.cost}행동`;};
  const exchange=C.emergency?'emergency':'reload';
  const last=C.selected.at(-1) || (C.hand[0] && C.hand[0].uid);
  const peak=fc?fc.heat:C.heat;
  app.innerHTML=`<div class="screen">${topBar(D.map.region,progress(),btn('slate',WEAPON.name,'','weapon',{size:'sm'}))}
    <div id="field"><img class="bg" src="${A}combat_bg.png" alt=""><div class="title">${esc(C.title)}</div><div class="reserve">${C.reserve.length?'후속 '+C.reserve.length+'기':''}</div></div>
    <div class="dock" data-a="clear">
      <div class="strip"><div class="magazine-tools"><span class="label">탄창 <b>${C.hand.length}발 / ${C.capacity}칸</b></span>
        ${btn('slate',last?`${last}번 상세`:'탄 상세','','round-detail',{size:'sm',disabled:!last||locked,attr:`data-uid="${last||0}"`})}
        ${btn('slate',selected?`${C.selected.length}발 빼내기`:'빼내기',C.eject_left?`남은 ${C.eject_left}발`:'사용 완료','eject',{size:'sm',disabled:locked||!selected||C.previewBusy||!C.preview})}
        ${selected?btn('slate','취소','','clear',{size:'sm',disabled:locked}):''}</div>
        <div class="heat-readout"><span class="label">발열</span><span class="kit k-heat gauge"><span class="fill"><u style="width:${Math.min(100,peak/C.heat_limit*100)}%"></u><i style="width:${Math.min(100,C.heat/C.heat_limit*100)}%"></i></span></span>
        <span class="heat-value">${C.heat} / ${C.heat_limit}</span></div>
      </div>
      ${C.error?`<div class="combat-error" role="alert">${esc(C.error)} ${btn('slate','전투 다시 연결','','reconnect',{size:'sm'})}</div>`:''}
      <div class="handrow"><div class="magazine" role="group" aria-label="탄창 · 좌우로 넘겨 보기" style="--capacity:${C.capacity}">${cards}</div>
        <div class="actions"><div class="support-actions">
          ${btn('cool','냉각',commandSub('cool'),'cool',{size:'mid',disabled:locked||selected||!C.commands.cool?.valid})}
          ${btn('reload',C.emergency?'비상 보급':'탄창 교체',commandSub(exchange),exchange,{size:'mid',disabled:locked||selected||!C.commands[exchange]?.valid})}</div>
          ${btn('fire',!C.loaded?'전투 준비 중':fc?`${fc.shots.length}발 사격`:C.hand.length?'사격':'빈 탄창',fireSub,'fire',{size:'big',disabled:locked||selected||!C.hand.length||!C.loaded})}</div>
      </div>
    </div></div>`;
  drawField(fc); renderOverlay();
  const magazine=$('.magazine'); if(magazine) magazine.scrollLeft=scrollBefore;
  if (!overlay && focusBefore) { const target=document.querySelector(focusBefore); if(target && !target.disabled) target.focus({preventScroll:true}); }
}
async function fire() { return combatCommand('fire'); }
async function reload(emergency) { return combatCommand(emergency?'emergency':'reload'); }
async function combatCommand(action) {
  if (!combatReady() || overlay) return;
  if (action==='eject') { if (!C.selected.length || C.previewBusy || !C.preview) return; }
  else if (C.selected.length || (action==='fire'?!C.hand.length:!C.commands[action]?.valid)) return;
  const my=epoch;
  busy=true; C.error=''; renderCombat();
  try {
    const result=await combatRequest(action,{indices:C.selected.map(n=>n-1)});
    await tick(my,0);
    if (action==='fire') await animateShots(my,result.shots);
    else if (action!=='eject') await tick(my,280);
    applyCombat(result);
    busy=false;
    if (['won','reward'].includes(C.phase)) return win();
    if (C.phase==='lost') return lose();
    renderCombat();
    if (result.overheat) toast('과열 · 강제 냉각 · 남은 탄 보존');
  } catch(error) {
    if (my!==epoch || error===ABORT) return;
    busy=false; C.error=error.message; renderCombat();
  }
}
async function animateShots(my,shots) {
  for (const shot of shots) {
    const f=$('#field'), g=fieldGeom(), muzzle=[152*g.s,399*g.s+g.oy];
    const flash=document.createElement('div'); flash.className='flash'; flash.style.left=muzzle[0]+'px'; flash.style.top=muzzle[1]+'px'; f.appendChild(flash); setTimeout(()=>flash.remove(),180);
    const impacts=[{target:shot.target,damage:shot.damage,hp:shot.hp},...(shot.secondary||[])].filter(hit=>hit.damage>0);
    if (!impacts.length) {
      const say=document.createElement('div'); say.className='say'; say.textContent=AMMO[shot.id].name;
      say.style.left=muzzle[0]+'px'; say.style.top=(muzzle[1]-40)+'px'; f.appendChild(say); setTimeout(()=>say.remove(),900);
    }
    for (const hit of impacts) {
      const target=C.enemies[hit.target]; if (!target) continue;
      const [tx,ty]=enemyCenter(target.uid), dx=tx-muzzle[0],dy=ty-muzzle[1];
      const tracer=document.createElement('div'); tracer.className='tracer';
      tracer.style.cssText=`left:${muzzle[0]}px;top:${muzzle[1]}px;width:${Math.hypot(dx,dy)}px;transform:rotate(${Math.atan2(dy,dx)}rad);z-index:70`;
      f.appendChild(tracer); setTimeout(()=>tracer.remove(),180);
      await tick(my,90);
      const pop=document.createElement('div'); pop.className='pop'+(hit.hp<=0?' kill':''); pop.textContent=hit.damage+(hit.hp<=0?' 처치':'');
      pop.style.cssText=`left:${tx}px;top:${ty-40}px;z-index:80`; f.appendChild(pop); setTimeout(()=>pop.remove(),820);
      const el=f.querySelector(`.enemy[data-uid="${target.uid}"]`); if(el) el.classList.add(hit.hp<=0?'dead':'hit');
      const tag=f.querySelector(`.tag[data-uid="${target.uid}"]`);
      if(tag) {tag.querySelector('.hp').textContent=Math.max(0,hit.hp);tag.querySelector('.bar i').style.width=Math.max(0,hit.hp)/target.max*100+'%';}
      await tick(my,180);
    }
    await tick(my,220);
  }
}
function win() {
  if (!combatActive()) return;
  C.result='win'; busy=false;
  const gain=C.kind==='elite'?12:C.kind==='boss'?20:6;
  G.cr+=gain; overlay={type:'win',gain}; renderCombat();
}
function lose() {
  if (!combatActive()) return;
  C.result='lose'; busy=false; overlay={type:'lose'}; renderCombat();
}
