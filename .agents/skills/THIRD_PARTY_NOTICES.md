# Third-party agent skills

프로젝트 개발 절차에 사용하는 외부 스킬 문서와 도구의 출처다. 게임 실행 파일에는 포함되지 않는다.

## Claude Code Game Studios — selective adaptation

- Source: https://github.com/Donchitos/Claude-Code-Game-Studios
- Reviewed snapshot: `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, framework 1.2.0.
- Adapted: 2026-10-31. License: MIT; original copyright and terms in `CCGS_LICENSE`.
- Referenced skills: `prototype`/spike mode, `vertical-slice`, `propagate-design-change`, `playtest-report`, `balance-check`, `perf-profile`, `soak-test`, `team-audio`, `test-evidence-review`, `regression-suite`, `release-checklist`, `asset-spec`, `asset-audit`; role guidance from `level-designer`, `systems-designer`, `economy-designer`, `analytics-engineer`.
- Local destinations: existing `00-project-manager`, `08-art-resource-manager`, `09-creative-director`, `10-balance-designer`, `12-combat-simulator`, `14-localization-text-manager`, `15-gameplay-qa-lead`, `16-gameplay-experience-tester`. Active-project procedures are in `docs/direction/development-workflow.md`, `docs/direction/magazine-journey.md` and `docs/qa/protocols/`.
- The active worktree is the source; the workspace discovery mirror receives the same adapted skill files. These are LoB-specific procedures, not an installation of the upstream Claude framework or its 49-agent organization.
- No upstream hooks, Claude tool/model settings, automatic delegation, per-file approvals, new GDD/ADR registries, production-code isolation/rewrite requirements, assertion-count quality gates or full-launch gates for internal test APKs were imported. Real combat models, canonical direction documents, existing delivery authorization and separate human/device evidence remain authoritative.

## awesome-gamedev-agent-skills

- Source: https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- Installed paths: `godot-ui-control`, `godot-animation`, `game-ui-ux`, `game-feel`
- License: Apache License 2.0
- License copy: `AWESOME_GAMEDEV_LICENSE`
- Notice copy: `AWESOME_GAMEDEV_NOTICE`
- Installed: 2026-09-21

## godot-ui-integration

- Source: https://github.com/zimo-xiao-zheng/godot-ui-integration
- Installed path: `godot-ui-integration`
- License: MIT
- License copy: `godot-ui-integration/LICENSE`
- Installed: 2026-09-21

## Impeccable

- Source: https://github.com/pbakaus/impeccable
- Installed: 2026-10-02, `impeccable` skill 4.5.0; engine 0.1.11.
- Source commit: `508d7e8955de3b3caf2d8676e85206723d41a887`, path `plugin/skills/impeccable`.
- License: Apache License 2.0; copy in `impeccable/LICENSE`.
- Engine binaries are local, Git-ignored hard links. No automatic web detector hook was installed.
- The former 2026-09-21 adaptation remains historical; current project rules are in `docs/direction/` and `AGENTS.md`.

## 2026-10-02 additions and discovery

- Added `create-game-assets`, `godot-nodes-scenes`, `godot-tilemap`, and `godot-shaders` from awesome-gamedev commit `d4b0e35550c55ae70bdfcab4ef5a0e94610438a9` using the skill-installer helper.
- Preserved the five existing 2026-09-21 skill folders, including their scripts and references.
- Mirrored these ten external skills into `D:/ProjectLoB/.agents/skills` so the conversation workspace can discover them. The active worktree remains the source copy; verify hashes when refreshing mirrors.
- Exact versions, sources and SKILL.md hashes are in `tools/art_tooling.lock.json` in the active worktree.
