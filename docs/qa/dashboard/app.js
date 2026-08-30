(function () {
  "use strict";

  const payload = window.QA_DASHBOARD_DATA || { runs: [] };
  const runs = Array.isArray(payload.runs) ? payload.runs : [];
  const state = { runId: runs[0] ? runs[0].run_id : "", filter: "ALL", search: "" };
  let controllerTimer = null;

  const classificationMeta = {
    PASS: { label: "PASS", color: "var(--green)" },
    FAIL: { label: "FAIL", color: "var(--red)" },
    CANDIDATE: { label: "CANDIDATE", color: "var(--amber)" },
    SEEDED: { label: "SEEDED", color: "var(--blue)" },
    SIGNAL: { label: "SIGNAL", color: "var(--violet)" },
    INFRA: { label: "INFRA", color: "var(--blue)" },
    BLOCKED: { label: "BLOCKED", color: "var(--amber)" }
  };

  const roleNames = {
    functional_qa: "기능 QA 리드",
    experience_qa: "경험 테스터",
    combat_simulator: "전투 시뮬레이터"
  };

  const metricNames = {
    shots: "발사",
    hits: "명중",
    effective_hits: "유효 적중",
    damage: "주 피해",
    overkill_damage: "과잉 피해",
    min_distance: "최소 거리",
    reloads: "리로드",
    formula_mismatches: "수식 불일치",
    completed_encounters: "완료 전투"
  };

  const $ = (id) => document.getElementById(id);
  const number = (value) => Number.isFinite(Number(value)) ? Number(value) : 0;
  const currentRun = () => runs.find((run) => run.run_id === state.runId) || runs[0];

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = String(text);
    return element;
  }

  function clear(element) {
    while (element && element.firstChild) element.removeChild(element.firstChild);
  }

  function formatDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value).replace("T", " ").replace("Z", "");
    return new Intl.DateTimeFormat("ko-KR", {
      year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit"
    }).format(date);
  }

  function statusClass(status) {
    return status === "PASS" ? "is-pass" : status === "FAIL" ? "is-fail" : status === "REVIEW" ? "is-review" : "is-blocked";
  }

  function verdictNote(run) {
    if (run.status === "PASS") return "검증 범위 내 승인";
    if (run.status === "FAIL") return "확정 결함 또는 회귀 실패";
    if (run.status === "REVIEW") return "재미·UX·밸런스 개선 논의 필요";
    return "필수 증거 또는 실행 범위 미충족";
  }

  function initialize() {
    initializeController();
    if (!runs.length) {
      $("run-title").textContent = "표시할 QA 실행이 없습니다";
      $("run-subtitle").textContent = "dashboard_data.js를 생성한 뒤 다시 여세요.";
      return;
    }

    const select = $("run-select");
    runs.forEach((run) => {
      const option = node("option", "", `${formatDate(run.created_at)} · ${run.scope}`);
      option.value = run.run_id;
      select.appendChild(option);
    });
    select.value = state.runId;
    select.addEventListener("change", () => {
      state.runId = select.value;
      state.filter = "ALL";
      render();
    });

    $("finding-search").addEventListener("input", (event) => {
      state.search = event.target.value.trim().toLocaleLowerCase("ko");
      renderFindings(currentRun());
    });

    $("data-time").textContent = `DATA ${formatDate(payload.generated_at)}`;
    render();
  }

  function render() {
    const run = currentRun();
    if (!run) return;
    renderHero(run);
    renderCoreFun(run);
    renderSummary(run);
    renderBuild(run);
    renderRegression(run);
    renderCombat(run);
    renderRoles(run);
    renderFilters(run);
    renderFindings(run);
    renderEvidence(run);
    renderHistory();
  }

  function renderHero(run) {
    $("run-title").textContent = run.scope || run.run_id;
    $("run-subtitle").textContent = `${run.mode || "focused"} · seed ${run.build.gameplay_seed} · ${formatDate(run.created_at)}`;
    $("verdict").textContent = run.status;
    $("verdict-note").textContent = verdictNote(run);
    const panel = $("verdict").closest(".verdict-panel");
    panel.className = `verdict-panel ${statusClass(run.status)}`;
  }

  function renderCoreFun(run) {
    const core = run.core_fun || {};
    const labels = {
      CORE_FUN_CONFIRMED: "핵심 재미 확인",
      PROMISING_BUT_THIN: "가능성은 있으나 얕음",
      NOT_DEMONSTRATED: "핵심 재미 확인 안 됨",
      STRUCTURAL_PROBLEM: "구조적 문제"
    };
    $("core-fun-headline").textContent = core.headline || "이 실행에는 핵심 재미 판정이 없습니다.";
    $("core-fun-summary").textContent = core.summary || "동일 탄환의 순서 대조와 실제 장전 이유를 함께 수집해야 합니다.";
    $("core-fun-confidence").textContent = `${labels[core.verdict] || "판정 없음"} · 신뢰도 ${core.confidence || "없음"}`;
    const gates = $("core-fun-gates");
    clear(gates);
    (Array.isArray(core.gates) ? core.gates : []).forEach((gate) => {
      const item = node("article", `core-fun-gate ${gate.passed ? "pass" : "fail"}`);
      item.append(node("span", "gate-state", gate.passed ? "확인" : "미확인"));
      item.append(node("strong", "", gate.question));
      item.append(node("p", "", gate.evidence));
      gates.appendChild(item);
    });
    renderList("core-fun-actions", core.next_actions);
    renderList("core-fun-human", core.human_confirmation);
  }

  function renderList(id, values) {
    const list = $(id);
    clear(list);
    (Array.isArray(values) ? values : []).forEach((value) => list.append(node("li", "", value)));
    if (!list.children.length) list.append(node("li", "", "기록 없음"));
  }

  function renderSummary(run) {
    const grid = $("summary-grid");
    clear(grid);
    const cards = [
      ["PASS", run.counts.pass, "증거가 있는 정상", "var(--green)"],
      ["CONFIRMED BUG", run.counts.fail, "제품 확정 결함", "var(--red)"],
      ["BUG CANDIDATE", run.counts.candidate, "반복 재현 대기", "var(--amber)"],
      ["EXPERIENCE SIGNAL", run.counts.signal, "재미·UX 후보", "var(--violet)"],
      ["INFRA", run.counts.infra, "QA 환경 문제", "var(--blue)"],
      ["BLOCKED", run.counts.blocked, "증거 미충족", "var(--amber)"],
      ["CONFLICT", run.counts.conflict, "역할 판정 상충", "var(--cyan)"]
    ];
    cards.forEach(([label, value, hint, color]) => {
      const card = node("article", "summary-card");
      card.style.setProperty("--tone", color);
      card.append(node("span", "summary-label", label));
      card.append(node("strong", "", number(value)));
      card.append(node("small", "", hint));
      grid.appendChild(card);
    });
  }

  function renderBuild(run) {
    const build = run.build || {};
    const badge = $("dirty-badge");
    badge.textContent = build.dirty_worktree ? "DIRTY SNAPSHOT" : "CLEAN COMMIT";
    badge.className = `micro-badge${build.dirty_worktree ? "" : " clean"}`;
    const meta = $("build-meta");
    clear(meta);
    [
      ["commit", build.commit || "—"],
      ["session", run.run_id],
      ["gameplay seed", build.gameplay_seed],
      ["platform", build.platform || "—"],
      ["engine", build.engine || "—"],
      ["scope", run.scope]
    ].forEach(([label, value]) => {
      const wrapper = node("div", "meta-item");
      wrapper.append(node("dt", "", label));
      wrapper.append(node("dd", "", value));
      meta.appendChild(wrapper);
    });
  }

  function renderRegression(run) {
    const regression = run.regression || {};
    const passed = number(regression.passed);
    const failed = number(regression.failed);
    const warnings = number(regression.warnings);
    const total = passed + failed + warnings;
    $("regression-total").textContent = `${total.toLocaleString("ko-KR")} CHECKS`;
    const numbers = $("regression-numbers");
    clear(numbers);
    [["통과", passed, "pass"], ["실패", failed, "fail"], ["경보", warnings, "warn"]].forEach(([label, value, tone]) => {
      const item = node("div", `regression-number ${tone}`);
      item.append(node("span", "", label));
      item.append(node("strong", "", value.toLocaleString("ko-KR")));
      numbers.appendChild(item);
    });
    const percent = (value) => total ? `${(value / total) * 100}%` : "0%";
    $("regression-pass-bar").style.width = percent(passed);
    $("regression-fail-bar").style.width = percent(failed);
    $("regression-warn-bar").style.width = percent(warnings);
    $("regression-caption").textContent = failed === 0
      ? "실패 0건. 경보는 판정 정본에 따라 제품 FAIL과 분리됩니다."
      : "회귀 실패가 있어 최종 판정이 FAIL로 고정됩니다.";
  }

  function renderCombat(run) {
    const grid = $("combat-metrics");
    clear(grid);
    const metrics = run.combat_metrics || {};
    const keys = Object.keys(metricNames).filter((key) => Object.prototype.hasOwnProperty.call(metrics, key));
    if (!keys.length) {
      grid.append(node("p", "panel-caption", "이 실행에는 전투 텔레메트리가 없습니다."));
      return;
    }
    keys.forEach((key) => {
      const item = node("div", "metric");
      item.append(node("span", "", metricNames[key]));
      const suffix = key === "min_distance" ? "m" : "";
      item.append(node("strong", "", `${metrics[key]}${suffix}`));
      grid.appendChild(item);
    });
  }

  function renderRoles(run) {
    const list = $("role-list");
    clear(list);
    const roles = Array.isArray(run.roles) ? run.roles : [];
    if (!roles.length) {
      list.append(node("p", "panel-caption", "역할별 원본 집계가 없습니다."));
      return;
    }
    roles.forEach((role) => {
      const card = node("article", "role-card");
      const identity = node("div");
      identity.append(node("div", "role-name", roleNames[role.role] || role.role));
      identity.append(node("div", "role-time", formatDate(role.completed_at)));
      const counts = node("div", "role-counts");
      ["PASS", "FAIL", "SIGNAL", "INFRA", "BLOCKED"].forEach((key) => {
        const value = number((role.counts || {})[key]);
        const chip = node("span", `role-count${value ? " active" : ""}`, `${key[0]} ${value}`);
        chip.title = `${key} ${value}`;
        counts.appendChild(chip);
      });
      card.append(identity, counts);
      list.appendChild(card);
    });
  }

  function renderFilters(run) {
    const row = $("filter-row");
    clear(row);
    const findings = Array.isArray(run.findings) ? run.findings : [];
    const filters = ["ALL", "FAIL", "CANDIDATE", "SIGNAL", "SEEDED", "INFRA", "BLOCKED", "PASS"];
    filters.forEach((key) => {
      const count = key === "ALL" ? findings.length : findings.filter((item) => item.classification === key).length;
      const button = node("button", `filter-button${state.filter === key ? " active" : ""}`, `${key} ${count}`);
      button.type = "button";
      button.setAttribute("aria-pressed", String(state.filter === key));
      button.addEventListener("click", () => {
        state.filter = key;
        renderFilters(run);
        renderFindings(run);
      });
      row.appendChild(button);
    });
  }

  function renderFindings(run) {
    const list = $("finding-list");
    clear(list);
    const findings = (Array.isArray(run.findings) ? run.findings : []).filter((finding) => {
      if (state.filter !== "ALL" && finding.classification !== state.filter) return false;
      if (!state.search) return true;
      const haystack = [finding.key, finding.observation, finding.category, finding.issue_type, finding.expected, finding.actual, ...(finding.roles || [])]
        .join(" ").toLocaleLowerCase("ko");
      return haystack.includes(state.search);
    });
    $("finding-empty").hidden = findings.length > 0;
    findings.forEach((finding) => {
      const meta = classificationMeta[finding.classification] || classificationMeta.BLOCKED;
      const card = node("article", "finding");
      card.style.setProperty("--tone", meta.color);
      const top = node("div", "finding-top");
      top.append(node("div", "finding-key", finding.key));
      top.append(node("div", "finding-class", meta.label));
      card.appendChild(top);
      card.append(node("p", "finding-observation", finding.observation || "상세 관찰 없음"));
      const details = node("div", "finding-meta");
      details.append(node("span", "", finding.issue_type || finding.category || "general"));
      details.append(node("span", "", `severity ${finding.severity || "none"}`));
      if (finding.confidence) details.append(node("span", "", finding.confidence));
      if (finding.confirmation_state) details.append(node("span", "", finding.confirmation_state));
      (finding.roles || []).forEach((role) => details.append(node("span", "", roleNames[role] || role)));
      if (finding.artifact_path) details.append(node("span", "", finding.artifact_path));
      card.appendChild(details);
      if (finding.expected || finding.actual) {
        const comparison = node("dl", "finding-comparison");
        if (finding.expected) {
          comparison.append(node("dt", "", "예상"));
          comparison.append(node("dd", "", finding.expected));
        }
        if (finding.actual) {
          comparison.append(node("dt", "", "실제"));
          comparison.append(node("dd", "", finding.actual));
        }
        card.appendChild(comparison);
      }
      if (Array.isArray(finding.reproduction_steps) && finding.reproduction_steps.length) {
        const steps = node("ol", "reproduction-steps");
        finding.reproduction_steps.forEach((step) => steps.append(node("li", "", step)));
        card.append(node("div", "finding-section-label", "재현 단계"), steps);
      }
      list.appendChild(card);
    });
  }

  function renderEvidence(run) {
    const list = $("evidence-list");
    clear(list);
    const links = Array.isArray(run.evidence_links) ? run.evidence_links : [];
    if (!links.length) {
      list.append(node("p", "panel-caption", "연결된 원본 증거가 없습니다."));
      return;
    }
    links.forEach((item) => {
      const link = node(item.href ? "a" : "div", "evidence-link");
      if (item.href) link.href = item.href;
      link.append(node("span", "", item.label));
      link.append(node("span", "evidence-kind", item.kind || item.path || "artifact"));
      list.appendChild(link);
    });
  }

  function renderHistory() {
    const body = $("history-body");
    clear(body);
    runs.forEach((run) => {
      const row = node("tr", run.run_id === state.runId ? "selected" : "");
      row.tabIndex = 0;
      row.setAttribute("aria-label", `${run.scope} 실행 선택`);
      const regression = run.regression || {};
      const cells = [
        formatDate(run.created_at),
        run.scope,
        run.status,
        `${number(regression.passed).toLocaleString("ko-KR")} / ${number(regression.failed)}`
      ];
      cells.forEach((value, index) => {
        const cell = node("td", index === 2 ? "status-cell" : "", value);
        if (index === 2) {
          const meta = run.status === "PASS" ? classificationMeta.PASS : run.status === "FAIL" ? classificationMeta.FAIL : classificationMeta.BLOCKED;
          cell.style.setProperty("--tone", meta.color);
        }
        row.appendChild(cell);
      });
      const selectRun = () => {
        state.runId = run.run_id;
        $("run-select").value = run.run_id;
        state.filter = "ALL";
        render();
        window.scrollTo({ top: 0, behavior: "smooth" });
      };
      row.addEventListener("click", selectRun);
      row.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") selectRun();
      });
      body.appendChild(row);
    });
  }

  async function initializeController() {
    $("qa-start").addEventListener("click", startQA);
    $("qa-cancel").addEventListener("click", cancelQA);
    await pollController();
  }

  async function pollController() {
    try {
      const response = await fetch("/api/qa/status", { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const status = await response.json();
      renderController(status);
      const active = ["queued", "running", "integrating"].includes(status.state);
      clearTimeout(controllerTimer);
      controllerTimer = setTimeout(pollController, active ? 1200 : 5000);
      if (status.state === "completed" && status.request_id) {
        const reloadKey = `qa-reloaded-${status.request_id}`;
        if (!sessionStorage.getItem(reloadKey)) {
          sessionStorage.setItem(reloadKey, "1");
          setTimeout(() => window.location.reload(), 900);
        }
      }
    } catch (error) {
      renderController({
        state: "offline", progress: 0,
        message: location.protocol === "file:"
          ? "현재는 결과 열람 모드입니다. tools/qa_dashboard_controller.ps1을 실행한 뒤 http://127.0.0.1:8765/로 접속하세요."
          : `로컬 QA 컨트롤러에 연결할 수 없습니다: ${error.message}`
      });
      clearTimeout(controllerTimer);
      controllerTimer = setTimeout(pollController, 8000);
    }
  }

  function renderController(status) {
    const active = ["queued", "running", "integrating"].includes(status.state);
    const labels = {
      idle: "실행 대기", queued: "실행 준비", running: "플레이 진행 중", integrating: "보고서 통합 중",
      completed: `완료${status.verdict ? ` · ${status.verdict}` : ""}`,
      failed: "실행 실패", cancelled: "실행 취소", offline: "컨트롤러 오프라인"
    };
    const progress = Math.max(0, Math.min(100, number(status.progress)));
    $("qa-state").textContent = labels[status.state] || status.state || "상태 확인";
    $("qa-progress-label").textContent = `${progress}%`;
    $("qa-progress-bar").style.width = `${progress}%`;
    $("qa-message").textContent = status.error ? `${status.message || "실패"} · ${status.error}` : (status.message || "");
    $("qa-start").disabled = active || status.state === "offline";
    $("qa-cancel").hidden = !active;
    $("controller-dot").classList.toggle("offline", status.state === "offline" || status.state === "failed");
  }

  async function startQA() {
    $("qa-start").disabled = true;
    try {
      const response = await fetch("/api/qa/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          gameplay_seed: number($("qa-seed").value) || 424242,
          target_encounters: number($("qa-encounters").value) || 3
        })
      });
      renderController(await response.json());
      await pollController();
    } catch (error) {
      renderController({ state: "failed", progress: 0, message: "시작 요청 실패", error: error.message });
    }
  }

  async function cancelQA() {
    try {
      const response = await fetch("/api/qa/cancel", { method: "POST" });
      renderController(await response.json());
    } catch (error) {
      renderController({ state: "failed", progress: 0, message: "취소 요청 실패", error: error.message });
    }
  }

  initialize();
}());
