"""Export and probe journey resources on desktop, without building an APK.

The source project/settings and existing mobile releases are never modified.
Android device rendering, signing, installation and heat are outside this check.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from mobile_comparison_resources import resources
import mobile_release as delivery


def check(godot, output):
    repo = Path(__file__).resolve().parents[1]
    source = next(p for p in repo.iterdir() if p.is_dir() and (p / "project.godot").is_file())
    output = output.resolve()
    qa = (repo / "qa_runtime").resolve()
    if not output.is_relative_to(qa):
        raise ValueError("Output must stay inside this repository's qa_runtime")
    run = output / datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    stage = run / "project"
    stage.mkdir(parents=True)
    mode = "magazine-journey"
    spec = delivery.PLAY_MODES[mode]
    selected = resources(source, mode)
    hashes = {}
    for uri in selected:
        relative = uri[6:]
        original = source / relative
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, destination)
        hashes[relative] = delivery.digest(original)
        # Preserve approved font/texture import settings, including pixel AA.
        for suffix in [".import", ".uid"]:
            extra = Path(str(original) + suffix)
            if extra.is_file():
                shutil.copy2(extra, str(destination) + suffix)
                hashes[relative + suffix] = delivery.digest(extra)
    for license_file in (source / "assets/fonts").glob("*OFL*.txt"):
        shutil.copy2(license_file, stage / "assets/fonts" / license_file.name)
        hashes[license_file.relative_to(source).as_posix()] = delivery.digest(license_file)
    settings = (source / "project.godot").read_bytes()
    text, count = re.subn(r'^run/main_scene="[^"]*"', 'run/main_scene="' + spec["main_scene"] + '"', settings.decode("utf-8-sig"), flags=re.M)
    delivery.require(count == 1, "Expected one main scene setting")
    (stage / "project.godot").write_text(text, encoding="utf-8")
    exclusions = delivery.read_json(repo / "tools/mobile_export_exclusions.json")["files"]
    # Same Android resource selection and script compilation as the real exporter.
    (stage / "export_presets.cfg").write_text(
        '[preset.0]\nname="Journey Resource Check"\nplatform="Android"\nrunnable=true\n'
        'export_filter="resources"\nexport_files=PackedStringArray(' + ", ".join(json.dumps(p) for p in selected) + ')\n'
        'include_filter="assets/fonts/*OFL*.txt"\nexclude_filter="' + ",".join(["tests/*", *exclusions]) + '"\n'
        'script_export_mode=2\n[preset.0.options]\ngradle_build/use_gradle_build=false\n', encoding="utf-8")
    env = os.environ.copy()
    for var, folder in [("APPDATA", "Roaming"), ("LOCALAPPDATA", "Local")]:
        path = run / folder
        path.mkdir()
        env[var] = str(path)
    temporary = run / "Temp"
    temporary.mkdir()
    env["TEMP"] = env["TMP"] = str(temporary)

    def godot_step(name, args):
        result = subprocess.run([str(godot), "--headless", "--path", str(stage), *args], env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
        (run / (name + "_stdout.log")).write_text(result.stdout, encoding="utf-8")
        (run / (name + "_stderr.log")).write_text(result.stderr, encoding="utf-8")
        (run / (name + "_exit.txt")).write_text(str(result.returncode), encoding="ascii")
        errors = re.search(r"SCRIPT ERROR|Parse Error|ERROR:", result.stderr.replace("ERROR: Failed to read the root certificate store.", ""))
        # Windows editor can exit abnormally after completing a cold import.
        # Retry the same import once; require a clean exit, never suppress it.
        if name == "import" and result.returncode != 0 and not errors:
            return godot_step("import_retry", args)
        delivery.require(result.returncode == 0 and not errors, "Resource check failed at " + name + " (exit " + str(result.returncode) + "); see " + str(run))

    godot_step("import", ["--editor", "--import", "--quit"])
    archive_path = run / "journey-resources.zip"
    godot_step("export", ["--export-pack", "Journey Resource Check", str(archive_path)])
    packed = run / "compiled"
    packed.mkdir()
    manifest = {"play_mode": mode, "main_scene": spec["main_scene"]}
    with zipfile.ZipFile(archive_path) as archive:
        delivery.require(archive.testzip() is None, "Resource archive CRC failure")
        names = archive.namelist()
        delivery.verify_mode_resources(manifest, names, prefix="")
        delivery.require(not any("tests" in Path(n).parts for n in names), "Tests leaked into pack")
        for name in names:
            delivery.require(not Path(name).is_absolute() and ".." not in Path(name).parts and "\\" not in name, "Unsafe pack entry")
        archive.extractall(packed)
    version = int(re.search(r"const VERSION := (\d+)", (source / "redesign/model.gd").read_text(encoding="utf-8-sig"))[1])
    delivery.run_resource_probe(packed, godot, version, manifest, env, run)
    delivery.require((source / "project.godot").read_bytes() == settings, "Source project settings changed")
    delivery.require(all(delivery.digest(source / path) == checksum for path, checksum in hashes.items()), "Selected source changed during validation")
    report = {**manifest, "source_resources": len(selected), "compiled_entries": len(names), "resource_zip_bytes": archive_path.stat().st_size,
              "resource_zip_sha256": delivery.digest(archive_path), "compiled_probe": "write/read passed on desktop", "source_unchanged": True,
              "apk_created": False, "android_device_tested": False, "source_sha256": hashes}
    delivery.write_json(run / "validation.json", report)
    delivery.write_json(output / "latest_check.json", {"run": str(run), "validation": str(run / "validation.json")})
    print(json.dumps({k: v for k, v in report.items() if k != "source_sha256"}))
    print("Evidence: " + str(run))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path("D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe"))
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "qa_runtime/mobile_journey_20261101")
    args = parser.parse_args()
    check(args.godot, args.output)
