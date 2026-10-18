"""Validate/package a local Android build and record a verified Drive delivery.

OAuth and upload are handled by the connected Google Drive app, not this script.
Only explicitly selected release files can enter the distributable ZIP.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from urllib.parse import urlparse

REPO = Path(__file__).resolve().parents[1]
APK_NAME = "LastOnBoard-city.apk"


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def digest(path, algorithm="sha256"):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_architectures(manifest, names):
    abis = manifest.get("architectures", [])
    require(isinstance(abis, list) and abis and len(abis) == len(set(abis)), "Missing or duplicate APK architectures")
    require(set(abis) <= {"arm64-v8a", "armeabi-v7a"}, "Unsupported APK architecture")
    actual = {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith("/libgodot_android.so")}
    require(actual == set(abis), "APK architectures differ from manifest")


def verify(release, godot):
    manifest = read_json(release / "build_manifest.json")
    config = read_json(REPO / "tools/mobile_delivery.json")
    apk = release / APK_NAME
    require(digest(apk) == manifest["sha256"].lower(), "APK SHA-256 mismatch")
    require(apk.stat().st_size == manifest["size_bytes"], "APK size mismatch")
    require(manifest["package"] == config["package_id"], "Package ID changed")
    signature = (release / "signature.log").read_text(encoding="utf-8-sig")
    match = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-f]+)", signature)
    require(match and match[1] == config["signing_certificate_sha256"], "Signing certificate changed; existing app cannot update")
    assets = release / "package_probe" / ("assets-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f"))
    assets.mkdir(parents=True)
    with zipfile.ZipFile(apk) as archive:
        require(archive.testzip() is None, "Corrupt APK ZIP entry")
        names = archive.namelist()
        verify_architectures(manifest, names)
        for name in ["assets/project.binary", "assets/redesign/model.gdc", "assets/redesign/content.gdc", "assets/redesign/screen.gdc", "assets/redesign/main.tscn.remap"]:
            require(name in names, "Required APK resource missing: " + name)
        asset_names = [name for name in names if name.startswith("assets/") and not name.endswith("/")]
        require(not any("tests" in PurePosixPath(name).parts for name in asset_names), "Test code exported")
        for name in asset_names:
            relative = PurePosixPath(name).relative_to("assets")
            require(not relative.is_absolute() and ".." not in relative.parts and "\\" not in str(relative), "Unsafe archive path")
            destination = assets.joinpath(*relative.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(name) as src, destination.open("wb") as dst:
                shutil.copyfileobj(src, dst)
    project = next(p for p in REPO.iterdir() if p.is_dir() and (p / "project.godot").is_file())
    model_text = (project / "redesign/model.gd").read_text(encoding="utf-8-sig")
    version = int(re.search(r"const VERSION := (\d+)", model_text)[1])
    # Desktop Godot loads the actual compiled APK resources with isolated user data.
    env = os.environ.copy()
    for variable, suffix in [("APPDATA", "Roaming"), ("LOCALAPPDATA", "Local")]:
        folder = release / "package_probe" / suffix
        folder.mkdir(exist_ok=True)
        env[variable] = str(folder)
    result = subprocess.run([str(godot), "--headless", "--path", str(assets), "--script", str(REPO / "tools/mobile_package_probe.gd"), "--", str(version)], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=90)
    (release / "package_probe/stdout.log").write_text(result.stdout, encoding="utf-8")
    (release / "package_probe/stderr.log").write_text(result.stderr, encoding="utf-8")
    diagnostic = (result.stdout + result.stderr).replace("ERROR: Failed to read the root certificate store.", "")
    require(result.returncode == 0 and "MOBILE_PACKAGE_PROBE_PASS" in result.stdout and not re.search(r"SCRIPT ERROR|Parse Error|ERROR:", diagnostic), "Packaged resource smoke test failed; see package_probe logs")
    report = {"apk_sha256": digest(apk), "crc_valid": True, "entries": len(names), "assets": len(asset_names), "signing_certificate_sha256": match[1], "model_version": version, "compiled_resource_probe": "passed on desktop Godot", "android_device_tested": False}
    write_json(release / "validation.json", report)
    print(json.dumps(report))


def package(release):
    manifest = read_json(release / "build_manifest.json")
    validation = read_json(release / "validation.json")
    config = read_json(REPO / "tools/mobile_delivery.json")
    apk = release / APK_NAME
    require(digest(apk) == validation["apk_sha256"] == manifest["sha256"].lower(), "APK changed after validation")
    # This allowlist deliberately excludes QA profiles, settings, logs and source.
    files = [APK_NAME, "INSTALL.md", "RELEASE_NOTES.md", "build_manifest.json", "validation.json"]
    checksums = "".join(f"{digest(release / name)}  {name}\n" for name in files)
    (release / "SHA256SUMS.txt").write_text(checksums, encoding="ascii")
    files.append("SHA256SUMS.txt")
    target = release / f"{release.name}.zip"
    with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in files:
            archive.write(release / name, arcname=name)
    with zipfile.ZipFile(target) as archive:
        require(archive.testzip() is None and set(archive.namelist()) == set(files), "Invalid delivery ZIP")
    limit = config["drive"].get("max_upload_bytes")
    require(limit is None or target.stat().st_size <= limit, "Delivery ZIP exceeds the Drive connector upload limit; reduce unused exported resources and create a new build")
    request = {"schema_version": 1, "build_id": release.name, "status": "ready_for_upload", "version_name": manifest["version_name"], "version_code": manifest["version_code"], "apk_path": str(apk), "zip_path": str(target), "file_name": target.name, "mime_type": "application/zip", "size_bytes": target.stat().st_size, "sha256": digest(target), "md5": digest(target, "md5"), "parent_folder_id": config["drive"]["folder_id"]}
    write_json(release / "delivery_request.json", request)
    print(json.dumps(request))


def validate_remote(request, metadata, downloaded=None):
    """Accept raw Drive metadata or the connector's normalized result."""
    if "structuredContent" in metadata:
        require(not metadata.get("isError"), "Drive returned an error")
        metadata = metadata["structuredContent"]
    require(metadata.get("id"), "No Drive file ID")
    require(metadata.get("name", metadata.get("title")) == request["file_name"], "Drive filename mismatch")
    require(metadata.get("mimeType", metadata.get("mime_type")) == "application/zip", "Drive MIME mismatch")
    require(int(metadata.get("size") or -1) == request["size_bytes"], "Drive size mismatch")
    require(not metadata.get("trashed", False), "Drive file is trashed")
    parents = metadata.get("parents", metadata.get("parent_ids")) or []
    require(request["parent_folder_id"] and request["parent_folder_id"] in parents, "Wrong Drive destination")
    url = metadata.get("webViewLink") or metadata.get("url") or metadata.get("display_url")
    parsed = urlparse(url or "")
    require(parsed.scheme == "https" and parsed.hostname == "drive.google.com" and metadata["id"] in parsed.path.split("/"), "No observed Drive file URL")
    checks = {"sha256Checksum": "sha256", "md5Checksum": "md5"}
    checked = False
    for key, local in checks.items():
        if metadata.get(key):
            require(metadata[key].lower() == request[local].lower(), "Drive checksum mismatch")
            checked = True
    if downloaded:
        require(digest(downloaded) == request["sha256"], "Downloaded ZIP differs from local ZIP")
        checked = True
    require(checked, "Connector omitted checksums; fetch the raw file and verify it with --downloaded")
    return {"file_id": metadata["id"], "url": url, "parent_folder_id": request["parent_folder_id"], "size_bytes": request["size_bytes"], "sha256": request["sha256"], "verification": "metadata and checksum verified", "verified_at": datetime.now(timezone.utc).isoformat()}


def record_upload(release, metadata_path, downloaded=None):
    request = read_json(release / "delivery_request.json")
    require(digest(request["zip_path"]) == request["sha256"], "Local ZIP changed since packaging")
    receipt = validate_remote(request, read_json(metadata_path), downloaded)
    write_json(release / "upload_receipt.json", receipt)
    request.update(status="uploaded", drive=receipt)
    write_json(release / "delivery_request.json", request)
    latest = REPO / "builds/mobile/latest.json"
    if not latest.exists() or read_json(latest)["build_id"] == request["build_id"]:
        write_json(latest, request)
    print(json.dumps(receipt))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["verify", "package", "record-upload"])
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--downloaded", type=Path)
    args = parser.parse_args()
    release = args.release.resolve()
    if args.action == "verify":
        require(args.godot and args.godot.is_file(), "--godot executable required")
        verify(release, args.godot)
    elif args.action == "package":
        package(release)
    else:
        require(args.metadata, "--metadata is required")
        record_upload(release, args.metadata, args.downloaded)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.TimeoutExpired, zipfile.BadZipFile) as error:
        sys.exit(str(error))
