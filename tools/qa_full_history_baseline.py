"""Run a legacy expectation suite against an isolated full-history-copy oracle."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
source = next(p for p in repo.iterdir() if (p / "project.godot").exists())
dest = repo / "qa_runtime/playtest_revision_20261026/full_history_oracle"
dest.mkdir(parents=True, exist_ok=True)
(dest / "project.godot").write_bytes((source / "project.godot").read_bytes())
queue = ["tests/ammo_expansion_rules_runner.gd"]
queue.extend(p.relative_to(source).as_posix() for p in (source / "scripts").rglob("*.gd"))
(dest / ".godot").mkdir(exist_ok=True)
class_cache = source / ".godot/global_script_class_cache.cfg"
if class_cache.exists():
    (dest / ".godot/global_script_class_cache.cfg").write_bytes(class_cache.read_bytes())
seen = set()
while queue:
    name = queue.pop()
    if name in seen:
        continue
    seen.add(name)
    original = source / name
    if not original.is_file():
        continue  # Dynamic resource paths are resolved by the original code.
    raw = original.read_bytes()
    target = dest / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if original.suffix in {".gd", ".tscn", ".tres"}:
        text = raw.decode("utf-8-sig").replace("\r\n", "\n")
        queue.extend(re.findall(r'"res://([^"\n]+)"', text))
        if name == "redesign/model.gd":
            text = re.sub(r'static func simulation_state\(state: Dictionary\) -> Dictionary:\n.*?(?=\nfunc preview\()',
                          'static func simulation_state(state: Dictionary) -> Dictionary:\n\treturn state.duplicate(true)\n', text, flags=re.S)
        target.write_text(text, encoding="utf-8", newline="\n")
    else:
        target.write_bytes(raw)
print(f"Full-copy oracle: {len(seen)} source dependencies copied to {dest}")
