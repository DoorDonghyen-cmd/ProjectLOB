"""Loopback-only mockup + real Godot combat adapter. No campaign saves are read."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json
import os
import secrets
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "docs/qa/reports/ui_prototype_2026-10-31"
PROJECT = ROOT / "새-게임-프로젝트"
RUNTIME = ROOT / "qa_runtime/ui_prototype_model"
GODOT = Path("D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe")
sessions = {}
session_lock = threading.Lock()


def resolve(payload):
    RUNTIME.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=RUNTIME) as temp:
        folder = Path(temp)
        request = folder / "request.json"
        response = folder / "response.json"
        request.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        env = dict(os.environ, LOB_UI_REQUEST=str(request), LOB_UI_RESPONSE=str(response),
                   LOB_UI_DATA=str(WEB / "assets/game_data.json"),
                   APPDATA=str(folder / "appdata"), LOCALAPPDATA=str(folder / "localdata"))
        result = subprocess.run([str(GODOT), "--headless", "--path", str(PROJECT),
                                 "--script", "res://tests/ui_prototype_model.gd"],
                                env=env, capture_output=True, timeout=20,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if not response.exists() or b"SCRIPT ERROR" in result.stderr:
            (RUNTIME / "last_error.log").write_bytes(result.stdout + result.stderr)
            raise RuntimeError("전투 계산을 완료하지 못했습니다. 다시 시도하세요.")
        return json.loads(response.read_text(encoding="utf-8"))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def json_response(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        origin = self.headers.get("Origin")
        allowed = f"http://127.0.0.1:{self.server.server_port}"
        if self.path != "/api/combat" or (origin and origin != allowed) or self.headers.get("Content-Type") != "application/json":
            return self.json_response({"ok":False, "error":"잘못된 요청입니다."}, 403)
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length < 32768: raise ValueError("요청 크기를 확인하세요.")
            payload = json.loads(self.rfile.read(length))
            action = payload.get("action")
            if action == "new":
                result = resolve({k:payload[k] for k in ("action", "deck", "parts", "kind", "seed") if k in payload})
                if not result["ok"]: return self.json_response(result, 400)
                sid = secrets.token_urlsafe(24)
                with session_lock:
                    # Tabs own independent sessions; stale preview/commands cannot cross tabs.
                    for key in list(sessions):
                        if time.monotonic() - sessions[key]["updated"] > 7200: del sessions[key]
                    if len(sessions) >= 128: raise ValueError("열린 전투가 너무 많습니다. 잠시 후 다시 시도하세요.")
                    sessions[sid] = dict(state=result.pop("state"), rev=0, updated=time.monotonic(), lock=threading.Lock())
                return self.json_response(dict(result, session=sid, revision=0))
            if action not in ("fire", "cool", "reload", "emergency", "eject", "preview"):
                raise ValueError("알 수 없는 조작입니다.")
            sid = payload.get("session", "")
            with session_lock: session = sessions.get(sid)
            if not session: raise ValueError("전투가 만료되었습니다. 다시 시작하세요.")
            with session["lock"]:
                if payload.get("revision") != session["rev"]: raise ValueError("이미 처리된 조작입니다. 전투를 다시 시작하세요.")
                result = resolve(dict(action=action, state=session["state"], indices=payload.get("indices", [])))
                if not result["ok"]: return self.json_response(result, 400)
                state = result.pop("state")
                if action != "preview":
                    session["state"] = state
                    session["rev"] += 1
                session["updated"] = time.monotonic()
                self.json_response(dict(result, session=sid, revision=session["rev"]))
        except (ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
            self.json_response({"ok":False, "error":str(error)}, 400)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    print(f"UI prototype + Godot model: http://127.0.0.1:{args.port}/index.html", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
