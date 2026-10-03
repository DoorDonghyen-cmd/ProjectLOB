#!/usr/bin/env python3
"""Audit Godot UI scenes for distorted or underfilled panel-like texture art."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - exercised only in missing envs.
    raise SystemExit("stretch_audit.py requires Pillow (PIL).") from exc


PANEL_NAME_HINTS = ("panel", "dialog", "dialogue", "button", "card", "bar", "frame")
ASPECT_SAFE_TEXTURE_RECT_MODES = {"2", "3", "4", "5", "6"}
DEFORMING_TEXTURE_RECT_MODES = {"", "0"}
MIN_VISIBLE_WIDTH_COVERAGE = 0.60
MIN_VISIBLE_HEIGHT_COVERAGE = 0.45


@dataclass
class Resource:
    resource_id: str
    path: str
    line: int


@dataclass
class Node:
    name: str
    node_type: str
    parent: str
    line: int
    props: dict[str, str] = field(default_factory=dict)


def parse_attrs(header: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r'(\w+)="([^"]*)"', header)}


def parse_scene(scene_path: Path) -> tuple[dict[str, Resource], list[Node]]:
    resources: dict[str, Resource] = {}
    nodes: list[Node] = []
    current_node: Node | None = None

    for line_no, raw_line in enumerate(scene_path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("[") and line.endswith("]"):
            current_node = None
            if line.startswith("[ext_resource"):
                attrs = parse_attrs(line)
                if attrs.get("type") == "Texture2D" and "id" in attrs and "path" in attrs:
                    resources[attrs["id"]] = Resource(attrs["id"], attrs["path"], line_no)
            elif line.startswith("[node"):
                attrs = parse_attrs(line)
                current_node = Node(
                    name=attrs.get("name", ""),
                    node_type=attrs.get("type", ""),
                    parent=attrs.get("parent", ""),
                    line=line_no,
                )
                nodes.append(current_node)
            continue

        if current_node and "=" in line:
            key, value = line.split("=", 1)
            current_node.props[key.strip()] = value.strip()

    return resources, nodes


def resolve_scene_path(project_root: Path, scene_arg: str) -> Path:
    if scene_arg.startswith("res://"):
        return project_root / scene_arg.removeprefix("res://")

    scene_path = Path(scene_arg)
    if scene_path.is_absolute():
        return scene_path
    return project_root / scene_path


def resolve_resource_path(project_root: Path, resource_path: str) -> Path | None:
    if resource_path.startswith("res://"):
        return project_root / resource_path.removeprefix("res://")
    if resource_path.startswith("user://"):
        return None

    path = Path(resource_path)
    if path.is_absolute():
        return path
    return project_root / path


def parse_float(value: str | None) -> float | None:
    if value is None:
        return None
    value = value.strip().strip('"')
    try:
        return float(value)
    except ValueError:
        return None


def parse_int(value: str | None, default: int = 0) -> int:
    number = parse_float(value)
    if number is None:
        return default
    return int(number)


def parse_ext_resource_id(value: str | None) -> str | None:
    if not value:
        return None
    match = re.search(r'ExtResource\("([^"]+)"\)', value)
    return match.group(1) if match else None


def node_rect(node: Node) -> tuple[float, float] | None:
    left = parse_float(node.props.get("offset_left")) or 0.0
    top = parse_float(node.props.get("offset_top")) or 0.0
    right = parse_float(node.props.get("offset_right"))
    bottom = parse_float(node.props.get("offset_bottom"))
    if right is None or bottom is None:
        return None

    width = right - left
    height = bottom - top
    if width <= 0 or height <= 0:
        return None
    return width, height


def image_info(path: Path) -> dict[str, Any]:
    with Image.open(path) as source:
        width, height = source.size
        has_alpha = "A" in source.getbands()
        rgba = source.convert("RGBA")
        bbox = rgba.getchannel("A").getbbox()

    if bbox:
        bbox_width = bbox[2] - bbox[0]
        bbox_height = bbox[3] - bbox[1]
    else:
        bbox_width = 0
        bbox_height = 0

    return {
        "path": str(path),
        "size": [width, height],
        "has_alpha": has_alpha,
        "bbox": list(bbox) if bbox else None,
        "bbox_size": [bbox_width, bbox_height],
        "texture_aspect": aspect(width, height),
        "bbox_aspect": aspect(bbox_width, bbox_height),
    }


def aspect(width: float, height: float) -> float | None:
    if width <= 0 or height <= 0:
        return None
    return width / height


def aspect_delta(reference: float | None, candidate: float | None) -> float | None:
    if reference is None or candidate is None or reference == 0:
        return None
    return abs(candidate - reference) / reference


def is_panel_like(node: Node) -> bool:
    text = f"{node.name} {node.node_type}".lower()
    return any(hint in text for hint in PANEL_NAME_HINTS)


def is_fixed_size(rect: tuple[float, float], image: dict[str, Any]) -> bool:
    width, height = rect
    tex_width, tex_height = image["size"]
    width_delta = abs(width - tex_width) / tex_width if tex_width else 1.0
    height_delta = abs(height - tex_height) / tex_height if tex_height else 1.0
    return width_delta <= 0.01 and height_delta <= 0.01


def audit_visible_subject(node: Node, rect: tuple[float, float], image: dict[str, Any]) -> list[str]:
    if not is_panel_like(node) or not image["bbox"]:
        return []

    rect_width, rect_height = rect
    bbox_width, bbox_height = image["bbox_size"]
    width_coverage = bbox_width / rect_width if rect_width else 0.0
    height_coverage = bbox_height / rect_height if rect_height else 0.0
    failures: list[str] = []

    if width_coverage < MIN_VISIBLE_WIDTH_COVERAGE:
        failures.append(
            "visible subject is too narrow for panel-like control: "
            f"bbox_width={bbox_width} rect_width={rect_width:.1f} coverage={width_coverage:.1%}"
        )

    if height_coverage < MIN_VISIBLE_HEIGHT_COVERAGE:
        failures.append(
            "visible subject is too short for panel-like control: "
            f"bbox_height={bbox_height} rect_height={rect_height:.1f} coverage={height_coverage:.1%}"
        )

    return failures


def audit_texture_rect(
    node: Node,
    rect: tuple[float, float],
    image: dict[str, Any],
    tolerance: float,
) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    stretch_mode = node.props.get("stretch_mode", "").strip()
    rect_aspect = aspect(*rect)
    bbox_aspect = image["bbox_aspect"] or image["texture_aspect"]
    delta = aspect_delta(bbox_aspect, rect_aspect)

    failures.extend(audit_visible_subject(node, rect, image))

    if not is_panel_like(node):
        return failures, warnings

    if stretch_mode in ASPECT_SAFE_TEXTURE_RECT_MODES:
        return failures, warnings

    if is_fixed_size(rect, image):
        return failures, warnings

    if stretch_mode not in DEFORMING_TEXTURE_RECT_MODES:
        if delta is not None and delta > tolerance:
            warnings.append(
                "panel-like TextureRect uses a non-aspect stretch mode; verify repeated or cropped texture output"
            )
        return failures, warnings

    if delta is not None and delta > tolerance:
        failures.append(
            "panel-like TextureRect would non-uniformly scale texture: "
            f"rect_aspect={rect_aspect:.3f} visible_aspect={bbox_aspect:.3f} delta={delta:.1%}"
        )

    return failures, warnings


def audit_nine_patch(node: Node, image: dict[str, Any]) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    tex_width, tex_height = image["size"]
    left = parse_int(node.props.get("patch_margin_left"))
    right = parse_int(node.props.get("patch_margin_right"))
    top = parse_int(node.props.get("patch_margin_top"))
    bottom = parse_int(node.props.get("patch_margin_bottom"))

    checks = [
        ("left", left, tex_width / 2),
        ("right", right, tex_width / 2),
        ("top", top, tex_height / 2),
        ("bottom", bottom, tex_height / 2),
    ]
    for name, margin, limit in checks:
        if margin > limit:
            failures.append(
                f"NinePatchRect patch_margin_{name}={margin} is larger than half of final texture size"
            )

    if left + right >= tex_width:
        failures.append(
            f"NinePatchRect horizontal margins leave no stretchable center: left+right={left + right}, width={tex_width}"
        )
    if top + bottom >= tex_height:
        failures.append(
            f"NinePatchRect vertical margins leave no stretchable center: top+bottom={top + bottom}, height={tex_height}"
        )

    if is_panel_like(node) and all(value == 0 for value in (left, right, top, bottom)):
        warnings.append("panel-like NinePatchRect has no patch margins")

    return failures, warnings


def texture_resource_props(node: Node) -> list[tuple[str, str]]:
    if node.node_type == "TextureButton":
        props: list[tuple[str, str]] = []
        for key in sorted(node.props):
            if key.startswith("texture_") and key != "texture_click_mask":
                texture_id = parse_ext_resource_id(node.props.get(key))
                if texture_id:
                    props.append((key, texture_id))
        return props

    texture_id = parse_ext_resource_id(node.props.get("texture"))
    return [("texture", texture_id)] if texture_id else []


def audit_scene(project_root: Path, scene_path: Path, tolerance: float) -> dict[str, Any]:
    resources, nodes = parse_scene(scene_path)
    results: list[dict[str, Any]] = []
    failures: list[str] = []
    warnings: list[str] = []

    for node in nodes:
        if node.node_type not in {"TextureRect", "NinePatchRect", "TextureButton"}:
            continue

        entry: dict[str, Any] = {
            "node": node.name,
            "type": node.node_type,
            "line": node.line,
            "panel_like": is_panel_like(node),
            "failures": [],
            "warnings": [],
        }

        rect = node_rect(node)
        if rect:
            entry["rect_size"] = [round(rect[0], 3), round(rect[1], 3)]
            entry["rect_aspect"] = aspect(*rect)
        else:
            entry["warnings"].append("node has no usable offset rect")

        texture_props = texture_resource_props(node)
        if not texture_props:
            entry["warnings"].append("node has no ExtResource texture")
            results.append(entry)
            warnings.extend(format_messages(scene_path, entry, "warnings"))
            continue

        texture_entries: list[dict[str, Any]] = []
        for prop, texture_id in texture_props:
            texture_entry: dict[str, Any] = {"property": prop, "resource_id": texture_id}
            resource = resources.get(texture_id)
            if not resource:
                message = f"{prop} ExtResource not found: {texture_id}"
                texture_entry["failures"] = [message]
                entry["failures"].append(message)
                texture_entries.append(texture_entry)
                continue

            texture_path = resolve_resource_path(project_root, resource.path)
            texture_entry["texture"] = resource.path
            if not texture_path or not texture_path.exists():
                message = f"{prop} file not found or unsupported: {resource.path}"
                texture_entry["failures"] = [message]
                entry["failures"].append(message)
                texture_entries.append(texture_entry)
                continue

            info = image_info(texture_path)
            texture_entry["image"] = info

            node_failures: list[str] = []
            node_warnings: list[str] = []
            if node.node_type in {"TextureRect", "TextureButton"} and rect:
                node_failures, node_warnings = audit_texture_rect(node, rect, info, tolerance)
            elif node.node_type == "NinePatchRect":
                node_failures, node_warnings = audit_nine_patch(node, info)

            texture_entry["failures"] = node_failures
            texture_entry["warnings"] = node_warnings
            entry["failures"].extend([f"{prop}: {message}" for message in node_failures])
            entry["warnings"].extend([f"{prop}: {message}" for message in node_warnings])
            texture_entries.append(texture_entry)

        if len(texture_entries) == 1:
            entry["texture"] = texture_entries[0].get("texture")
            entry["image"] = texture_entries[0].get("image")
        entry["textures"] = texture_entries
        results.append(entry)
        failures.extend(format_messages(scene_path, entry, "failures"))
        warnings.extend(format_messages(scene_path, entry, "warnings"))

    return {
        "project_root": str(project_root),
        "scene": str(scene_path),
        "tolerance": tolerance,
        "failures": failures,
        "warnings": warnings,
        "nodes": results,
    }


def format_messages(scene_path: Path, entry: dict[str, Any], key: str) -> list[str]:
    return [
        f"{scene_path}:{entry['line']} {entry['type']} {entry['node']}: {message}"
        for message in entry[key]
    ]


def print_human(result: dict[str, Any]) -> None:
    if result["failures"]:
        print("Stretch audit failed:")
        for failure in result["failures"]:
            print(f"  - {failure}")
    else:
        print("Stretch audit passed.")

    if result["warnings"]:
        print("Warnings:")
        for warning in result["warnings"]:
            print(f"  - {warning}")

    print(f"Audited {len(result['nodes'])} TextureRect/NinePatchRect/TextureButton nodes.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Audit Godot UI scenes for panel-like texture stretch problems."
    )
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--scene", required=True, help="Scene path, relative path, absolute path, or res:// path.")
    parser.add_argument("--aspect-tolerance", type=float, default=0.10)
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    args = parser.parse_args(argv)

    project_root = args.project_root.resolve()
    scene_path = resolve_scene_path(project_root, args.scene).resolve()
    if not scene_path.exists():
        print(f"Scene not found: {scene_path}", file=sys.stderr)
        return 2

    result = audit_scene(project_root, scene_path, args.aspect_tolerance)
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print_human(result)

    return 1 if result["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
