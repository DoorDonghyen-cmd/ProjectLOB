"""Select comparison/journey dependencies without changing source art."""
import argparse
import json
from pathlib import Path
import re


MODES = json.loads(Path(__file__).with_name("mobile_play_modes.json").read_text(encoding="utf-8"))


def code_identifiers(text):
    # class_name dependencies need not contain a res:// path. Ignore prose,
    # comments and string literals when finding those global script references.
    code = re.sub(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\#[^\n]*', "", text)
    return set(re.findall(r"\b[A-Za-z_]\w*\b", code))


def resources(project, play_mode="weapon-magazine"):
    if play_mode not in {"weapon-magazine", "magazine-journey"}:
        raise ValueError("Resource selection supports only comparison/journey modes")
    pending = [MODES[play_mode]["main_scene"][6:], "redesign/campaign.gd", "assets/ui/title/orvask_icon.svg"]
    classes = {}
    for script in project.rglob("*.gd"):
        relative = script.relative_to(project)
        if any(part.startswith(".") for part in relative.parts) or relative.parts[0] in {"tests", "addons"}:
            continue
        match = re.search(r"^class_name\s+(\w+)", script.read_text(encoding="utf-8-sig"), re.M)
        if match:
            classes[match[1]] = relative.as_posix()
    seen = set()
    while pending:
        relative = pending.pop()
        if relative in seen:
            continue
        seen.add(relative)
        path = project / relative
        if not path.is_file():
            raise ValueError("Selected resource is missing: " + relative)
        if path.suffix not in {".gd", ".tscn", ".tres", ".gdshader"}:
            continue
        text = path.read_text(encoding="utf-8-sig")
        if path.suffix == ".gd":
            pending.extend(classes[name] for name in code_identifiers(text) & classes.keys())
        for uri in re.findall(r'''["'](res://[^"'\n]+)["']''', text):
            dependency = project / uri[6:]
            if dependency.is_file():
                pending.append(uri[6:])
            elif dependency.is_dir() and uri.startswith("res://assets/"):
                # Dynamic world/pixel lookups use these explicit directory roots.
                pending.extend(p.relative_to(project).as_posix() for p in dependency.rglob("*") if p.is_file() and p.suffix in {".png", ".svg", ".tres", ".webp", ".ttf", ".wav", ".ogg"})
    # FileAccess-loaded earned encounters are added by the preset include filter.
    # Inherited old study scene/fixture paths are not invoked by this entry scene.
    return ["res://" + name for name in sorted(seen)]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--play-mode", choices=["weapon-magazine", "magazine-journey"], default="weapon-magazine")
    args = parser.parse_args()
    args.output.write_text(json.dumps(resources(args.project, args.play_mode), indent=2) + "\n", encoding="utf-8")
