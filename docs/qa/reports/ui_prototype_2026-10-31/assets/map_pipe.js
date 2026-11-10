/* Pipe-schematic map trial (director proposal, 2026-11-01).
   Draws the same map nodes and `next` links as a supply schematic: pipes run up and turn at right
   angles, the region gate is a full-width bulkhead, and a left rail shows all five regions from home
   to the control room. Selecting, details and moving reuse the page's existing actions.
   Switch: toolbar "지도", #map=pipe, or localStorage "orvask-map-style". Loaded after the main script. */
(() => {
  const ICON = { combat: [36, 36], shop: [36, 36], workshop: [36, 36], supply: [36, 36], event: [36, 36], bypass: [36, 36],
    elite: [44, 44], boss: [48, 48], boss_small: [32, 32], home: [28, 26], valve: [26, 26], control: [28, 24] };
  const KIND_NAME = { combat: "전투", elite: "정예", boss: "관문", shop: "상점", workshop: "공방", supply: "탄약고", event: "조우", bypass: "샛길" };
  // Only exceptions the player must know before choosing (route-map: one line, no auto details).
  const NOTE = { elite: "강한 적 · 파츠 보상", workshop: "무료 작업 1회", event: "결과는 고른 뒤 공개", boss: "구역 출구 · 이기면 다음 구역", bypass: "전투 1곳 생략 · 그 보상 없음" };
  const ZONES = ["주거 통로", "축열 주조장", "우수 정원", "귀족 거주구", "중앙 통제구"];
  const ZONE_NOW = 0; // The prototype only has the first region.
  const MAX_GAP = 92, STUB = 6, OFF = 12, STAGGER = 6, CHAMFER = 4;
  const TOUCH_HEIGHT = 44, TOUCH_GAP = 8;
  // Leave room for both staggered bends plus a straight stub at either end.
  const PIPE_ROOM = 2 * (STAGGER + CHAMFER + 2);

  let style = "chart";
  let keyOpen = false;
  let lastViewHeight = 0;
  const chartMap = renderMap;

  const icon = (name, color) => {
    const [w, h] = ICON[name] || ICON.combat;
    const url = `${A}pm_${name}.png`;
    return `<i class="pm-ic pm-${name}" style="width:${w}px;height:${h}px;-webkit-mask-image:url(${url});mask-image:url(${url})${color ? ";color:" + color : ""}"></i>`;
  };
  const even = (v) => Math.round(v / 2) * 2;

  function reachable(starts = G.available) {
    const seen = new Set(), todo = starts.slice();
    while (todo.length) {
      const id = todo.pop(); if (seen.has(id)) continue; seen.add(id);
      const n = nodeById(id); if (n) todo.push(...n.next);
    }
    return seen;
  }
  function placeState(n, ahead) {
    if (n.id === G.current) return "current";
    if (G.available.includes(n.id)) return "reach";
    if (G.visited.includes(n.id)) return "visited";
    return ahead.has(n.id) ? "later" : "off";
  }
  function pipeState(from, to, ahead, branch) {
    const i = G.visited.indexOf(from);
    if (from === "in" ? G.visited[0] === to : i >= 0 && G.visited[i + 1] === to) return "trail";
    const here = from === "in" ? G.current === 0 : from === G.current;
    if (here && G.available.includes(to)) return to === G.selected ? "pick" : "open";
    if ((from === "in" || ahead.has(from)) && ahead.has(to)) return branch.has(from) ? "preview" : "later";
    return "off";
  }

  function railHtml() {
    const zones = ZONES.map((name, i) => ({ name, i })).reverse().map(({ name, i }) => {
      const st = i < ZONE_NOW ? "open" : i === ZONE_NOW ? "now" : "shut";
      const sub = st === "now" ? "지금 여기" : st === "open" ? "공급 연결" : "닫힘";
      return `<div class="pm-stop zone ${st}" data-zone="${i}"><span class="pm-ic-slot">${icon("valve")}</span><span><b>${esc(name)}</b><small>${sub}</small></span></div>`;
    }).join("");
    return `<div class="pm-rail-line"><i class="pm-rail-fill"></i></div><i class="pm-rail-you" aria-hidden="true"></i>
      <div class="pm-stop end" data-end="top"><span class="pm-ic-slot">${icon("control")}</span><span><b>중앙 제어실</b><small>차단 명령</small></span></div>
      ${zones}
      <div class="pm-stop end" data-end="home"><span class="pm-ic-slot">${icon("home")}</span><span><b>우리 동네</b><small>공급 차단</small></span></div>`;
  }

  function keyHtml() {
    const kinds = ["combat", "elite", "event", "shop", "workshop", "supply", "bypass", "boss"];
    return `<div class="kit k-modal pm-key" role="dialog" aria-label="지도 기호">
      <div class="hd"><h3>기호</h3>${btn("slate", "닫기", "", "pmkey", { size: "sm" })}</div>
      <div class="grid">${kinds.map((k) => `<div class="it"><span class="ico">${icon(k)}</span>${KIND_NAME[k]}</div>`).join("")}</div>
      <div class="lines">
      <div class="ln"><i style="background:#f3cf73;box-shadow:0 0 0 2px #3a2c10"></i>지나온 길 · 공급이 이어진 관</div>
      <div class="ln"><i style="background:#5cdddc;height:2px"></i>지금 갈 수 있는 길</div>
      <div class="ln"><i style="background:#3d7f86;height:2px"></i>그 뒤의 길 · 고른 갈래 강조</div>
      <div class="ln"><i style="background:repeating-linear-gradient(90deg,#15363c 0 2px,transparent 2px 6px);height:2px"></i>이제 갈 수 없는 길</div></div></div>`;
  }

  function renderPipeMap() {
    const previous = $(".pm-scroll");
    const scrollState = previous ? { top: previous.scrollTop, selected: $(".pn.sel")?.dataset.id } : null;
    const nodes = D.map.nodes, floors = D.map.floors;
    const ahead = reachable();
    const branch = ahead.has(G.selected) ? reachable([G.selected]) : new Set();
    const gate = nodes.find((n) => n.floor === floors);
    const sel = nodeById(G.selected);
    const reach = !!sel && G.available.includes(sel.id);
    const places = nodes.filter((n) => n !== gate).map((n) => {
      const st = placeState(n, ahead);
      return `<button class="pn ${st}${st === "later" && branch.has(n.id) ? " preview" : ""}${n.id === G.selected ? " sel" : ""} k-${n.kind}" data-a="node" data-id="${n.id}" aria-label="${esc(n.kind_name)} · ${esc(n.name || "")}">${icon(n.kind)}</button>`;
    }).join("");
    const gst = gate ? placeState(gate, ahead) : "off";
    const gateHtml = gate ? `<button class="pm-gate ${gst}${gate.id === G.selected ? " sel" : ""}" data-a="node" data-id="${gate.id}" aria-label="관문 · ${esc(gate.name || "")}">
        ${icon("valve")}${icon("boss")}${icon("boss_small")}<span><b>${esc(gate.name || "관문")}</b><small>이기면 다음 구역</small></span>${icon("valve")}</button>` : "";
    let side = `<div class="label">갈 곳을 고르세요</div>`;
    if (sel) {
      const note = !reach ? `<div class="pm-note calm">연결된 길로만 갈 수 있음</div>` : NOTE[sel.kind] ? `<div class="pm-note">${esc(NOTE[sel.kind])}</div>` : "";
      side = `<div class="label">${reach ? "선택한 장소" : "미리보기"}</div>
        <div class="pm-pick">${icon(sel.kind)}<div><div class="pm-name">${esc(sel.name || sel.kind_name)}</div><div class="pm-kind">${esc(sel.kind_name)}</div></div></div>
        ${note}
        <div class="row">${btn("slate", "기호", "", "pmkey", { size: "mid", attr: `aria-expanded="${keyOpen}"` })}${btn("slate", "자세히", "", "nodeinfo", { size: "mid" })}</div>
        ${reach ? btn("fire", "이동", "", "go", { size: "mid" }) : ""}`;
    }
    app.innerHTML = `<div class="screen pmap">${topBar(D.map.region, "")}
      <div class="body pm-body">
        <div class="pm-rail" aria-label="구역 진행">${railHtml()}</div>
        <div class="kit k-modal pm-board">
          ${gateHtml}
          <div class="pm-scroll"><div class="pm-plane"><svg class="pm-pipes" aria-hidden="true"></svg>${places}</div></div>
          ${keyOpen ? keyHtml() : ""}
        </div>
        <div class="pm-side-col"><div class="kit k-modal pm-side">${side}</div></div>
      </div></div>`;
    for (const w of app.querySelectorAll(".pm-gate .pm-valve")) w.classList.add("pm-wheel");
    const wheels = app.querySelectorAll(".pm-gate .pm-wheel");
    if (wheels[0]) wheels[0].classList.add("l");
    if (wheels[1]) wheels[1].classList.add("r");
    layout(ahead, gate, branch, scrollState);
  }

  function layout(ahead, gate, branch, scrollState) {
    const scroll = $(".pm-scroll"), plane = $(".pm-plane"), svg = $(".pm-pipes");
    if (!scroll) return;
    const floors = D.map.floors, rows = Math.max(1, floors - 1);
    const view = scroll.clientHeight, resized = view !== lastViewHeight;
    lastViewHeight = view;
    // Preserve the full touch target at the edges. The map scrolls rather than crushing rows.
    const halfOf = (kind) => (ICON[kind] || ICON.combat)[1] / 2;
    const rowHalf = (f) => Math.max(18, ...D.map.nodes.filter((n) => n.floor === f).map((n) => halfOf(n.kind)));
    const PAD_TOP = even(Math.max(TOUCH_HEIGHT / 2, rowHalf(rows)) + STUB);
    const PAD_BOTTOM = even(Math.max(TOUCH_HEIGHT / 2, rowHalf(1)) + STUB + 2);
    const fittedGap = Math.min(MAX_GAP, (view - PAD_TOP - PAD_BOTTOM) / Math.max(1, rows - 1));
    const rowY = new Map([[rows, PAD_TOP]]);
    for (let f = rows - 1; f >= 1; f--) {
      const minGap = Math.max(TOUCH_HEIGHT + TOUCH_GAP, rowHalf(f) + rowHalf(f + 1) + 4 + PIPE_ROOM);
      rowY.set(f, rowY.get(f + 1) + even(Math.max(minGap, fittedGap)));
    }
    const H = rowY.get(1) + PAD_BOTTOM;
    plane.style.height = H + "px";
    // The height can introduce a scrollbar; measure width only after reserving that space.
    const W = scroll.clientWidth;
    const x = (lane) => even((W * (lane + 0.5)) / 4);
    const y = (floor) => rowY.get(floor);
    const half = (n) => (ICON[n.kind] || ICON.combat)[1] / 2 + 2;
    for (const el of plane.querySelectorAll(".pn")) {
      const n = nodeById(Number(el.dataset.id));
      el.style.left = x(n.lane) + "px"; el.style.top = y(n.floor) + "px";
    }
    // Right-angle pipe with one small stepped chamfer at each bend.
    const route = (x1, y1, x2, y2, mid) => {
      if (x1 === x2) return `M${x1} ${y1}V${y2}`;
      const d = Math.sign(x2 - x1);
      return `M${x1} ${y1}V${mid + CHAMFER}L${x1 + d * CHAMFER} ${mid}H${x2 - d * CHAMFER}L${x2} ${mid - CHAMFER}V${y2}`;
    };
    const pipes = [];
    for (const n of D.map.nodes) {
      if (n === gate) continue;
      if (n.floor === 1) pipes.push({ st: pipeState("in", n.id, ahead, branch), d: `M${x(n.lane)} ${H}V${y(n.floor) + half(n)}` });
      for (const id of n.next) {
        const m = nodeById(id); if (!m) continue;
        const st = pipeState(n.id, m.id, ahead, branch);
        if (m === gate) { pipes.push({ st, d: `M${x(n.lane)} ${y(n.floor) - half(n)}V0` }); continue; }
        const dir = Math.sign(m.lane - n.lane);
        const x1 = x(n.lane) + dir * OFF, x2 = x(m.lane) - dir * OFF;
        // Bends from neighbouring lanes sit at different heights so two runs never read as one bus.
        const y1 = y(n.floor) - half(n), y2 = y(m.floor) + half(m);
        const mid = even((y1 + y2) / 2) + (n.lane % 2 ? -STAGGER : STAGGER);
        pipes.push({ st, d: route(x1, y1, x2, y2, mid) });
      }
    }
    const order = ["off", "later", "preview", "open", "trail", "pick"];
    pipes.sort((a, b) => order.indexOf(a.st) - order.indexOf(b.st));
    svg.setAttribute("width", W); svg.setAttribute("height", H); svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
    svg.innerHTML = pipes.map(({ st, d }) => {
      if (st === "trail") return `<path class="trail-case" d="${d}"/><path class="trail" d="${d}"/>`;
      if (st === "pick") return `<path class="pick-case" d="${d}"/><path class="pick" d="${d}"/><path class="flow" d="${d}"/>`;
      return `<path class="${st}" d="${d}"/>`;
    }).join("");
    const focus = plane.querySelector(".pn.sel") || plane.querySelector(".pn.current") || plane.querySelector(".pn.reach");
    if (scrollState) scroll.scrollTop = scrollState.top;
    if (focus) {
      const center = parseInt(focus.style.top, 10);
      let top = center - TOUCH_HEIGHT / 2, bottom = center + TOUCH_HEIGHT / 2;
      const current = plane.querySelector(".pn.current");
      if (current) {
        const here = parseInt(current.style.top, 10);
        const bothTop = Math.min(top, here - TOUCH_HEIGHT / 2), bothBottom = Math.max(bottom, here + TOUCH_HEIGHT / 2);
        if (bothBottom - bothTop + 16 <= view) { top = bothTop; bottom = bothBottom; }
      }
      const changed = !scrollState || scrollState.selected !== plane.querySelector(".pn.sel")?.dataset.id;
      const outside = top - 8 < scroll.scrollTop || bottom + 8 > scroll.scrollTop + view;
      // Keep manual scrolling when opening the key; only reveal a newly selected off-screen node.
      // Keep the current place alongside a nearby selection when both fit after a resize.
      if (!scrollState || ((changed || resized) && outside)) scroll.scrollTop = (top + bottom - view) / 2;
    }
    layoutRail();
  }

  function layoutRail() {
    const rail = $(".pm-rail"); if (!rail) return;
    const box = rail.getBoundingClientRect();
    const mid = (el) => { const r = el.querySelector(".pm-ic").getBoundingClientRect(); return r.top + r.height / 2 - box.top; };
    const top = mid(rail.querySelector('[data-end="top"]')), home = mid(rail.querySelector('[data-end="home"]'));
    const zone = (i) => mid(rail.querySelector(`[data-zone="${i}"]`));
    const line = rail.querySelector(".pm-rail-line");
    line.style.top = even(top) + "px"; line.style.height = even(home - top) + "px";
    // Supply restored from home up to the climber: the current region fills by the depth reached.
    const done = G.current ? (nodeById(G.current) || { floor: 0 }).floor / D.map.floors : 0;
    const from = zone(ZONE_NOW), to = ZONE_NOW + 1 < ZONES.length ? zone(ZONE_NOW + 1) : top;
    const reachY = even(from - (from - to) * done);
    rail.querySelector(".pm-rail-fill").style.height = Math.max(0, even(home - reachY)) + "px";
    rail.querySelector(".pm-rail-you").style.top = (reachY - 2) + "px";
  }

  renderMap = function () { return style === "pipe" ? renderPipeMap() : chartMap(); };

  app.addEventListener("click", (ev) => {
    const el = ev.target.closest('[data-a="pmkey"]');
    if (!el || overlay || !G || G.screen !== "map") return;
    keyOpen = !keyOpen; render();
  });
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && keyOpen && !overlay) { keyOpen = false; if (G && G.screen === "map") render(); }
  });

  function setMapStyle(name) {
    style = name === "pipe" ? "pipe" : "chart";
    keyOpen = false;
    try { localStorage.setItem("orvask-map-style", style); } catch (e) { /* file:// may block storage */ }
    document.querySelectorAll("[data-map-set]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.mapSet === style)));
    if (G && G.screen === "map" && !overlay) render();
  }
  document.querySelectorAll("[data-map-set]").forEach((b) => b.addEventListener("click", () => setMapStyle(b.dataset.mapSet)));
  const fromHash = location.hash.match(/map=(\w+)/);
  let saved = null;
  try { saved = localStorage.getItem("orvask-map-style"); } catch (e) { saved = null; }
  setMapStyle(fromHash ? fromHash[1] : saved || "chart");
})();
