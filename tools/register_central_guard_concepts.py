"""Measure generated PNGs and record provenance. Never modifies source pixels."""
from pathlib import Path
import hashlib
import json
import argparse
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--variant-b", action="store_true")
args = parser.parse_args()
ART = ROOT / ("새-게임-프로젝트/assets/art/central_guard_alt_20261025" if args.variant_b else "새-게임-프로젝트/assets/art/central_guard_concepts_20261025")
R = "새-게임-프로젝트/assets/art/"
hero = R + "hero_contours_20261025/work_pistol.png"
background = R + "central_ascent_20261024/lower_v1.png"
rusher = str((ART / "guard_rusher_v1.png").relative_to(ROOT)).replace("\\", "/")
specs = [
    ("guard_rusher", "친위 돌격병", "빠른 접근 · 긴 다리", 112, [hero, background, R+"foundry_concepts_20261022/mold_worker_v1.png"], "exec-b2563a29-dd6b-476b-b3c3-769645764d9a.png"),
    ("guard_heavy", "친위 중장병", "고체력 · 넓은 몸통", 132, [rusher, R+"foundry_concepts_20261022/mold_worker_v1.png", hero, background], "exec-9053cb50-1c5b-4de0-ad44-bf7220237f1f.png"),
    ("guard_shield", "친위 방패병", "차폐 · 접이식 문판", 116, [rusher, R+"noble_enemies_20261025/double_door_servant_v2.png", hero, background], "exec-159e8750-6ecd-49ce-8d6d-d851dfb09c07.png"),
    ("guard_artillery", "친위 포격병", "원거리 · 압력통과 포신", 108, [rusher, R+"foundry_concepts_20261022/pressure_worker_v1.png", hero, background], "exec-135d784b-77fb-4639-996c-dedc0a414b29.png"),
]
if args.variant_b:
    rusher_b = R + "central_guard_alt_20261025/guard_rusher_b.png"
    specs = [
        ("guard_rusher", "친위 돌격병", "판스프링 다리 · 타격봉 팔", 112, [hero, background], "exec-b3e3aa58-7bc0-4f87-96e1-b6884e3ee58b.png"),
        ("guard_heavy", "친위 중장병", "금고형 몸통 · 잠금 장치", 132, [rusher_b, R+"foundry_concepts_20261022/mold_worker_v1.png", hero, background], "exec-339d67c3-1502-476a-818e-b46e4404bceb.png"),
        ("guard_shield", "친위 방패병", "겹친 차폐판 · 넓은 전면", 116, [rusher_b, R+"noble_enemies_20261025/double_door_servant_v2.png", hero, background], "exec-0f9849ad-b570-409b-b831-675b4b71c9a2.png"),
        ("guard_artillery", "친위 포격병", "가로 압력통 · 짧은 포신", 108, [rusher_b, R+"foundry_concepts_20261022/pressure_worker_v1.png", hero, background], "exec-c918f634-aec6-4baf-a7a7-f3e5e92a3960.png"),
    ]
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

items, reports, provenance = [], [], []
for key, name, role, height, refs, generated in specs:
    path = ART / (key + ("_b.png" if args.variant_b else "_v1.png"))
    im = Image.open(path)
    assert im.mode == "RGBA", (key, im.mode)
    alpha = im.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= 128 else 0)
    box = mask.getbbox()
    assert box is not None
    x0, y0, x1, y1 = box
    assert x0 > 0 and y0 > 0 and x1 < im.width and y1 < im.height, (key, "clipped")
    # Center of both boot soles; ignores hands and cannon that extend past the body.
    sole = mask.crop((x0, y1-max(32, round((y1-y0)*0.04)), x1, y1)).getbbox()
    foot_x = x0 + (sole[0]+sole[2])/2
    item = dict(id=key, name=name, role=role, file=path.name,
                source=[x0,y0,x1-x0,y1-y0], feet=[foot_x,y1], height=height)
    if args.variant_b:
        item["variant"] = "B"
    items.append(item)
    reports.append(dict(id=key, dimensions=list(im.size), mode=im.mode, sha256=digest(path),
                        opaque_bounds=item["source"], feet=item["feet"],
                        alpha_zero=alpha.histogram()[0], alpha_255=alpha.histogram()[255],
                        alpha_partial=sum(alpha.histogram()[1:255]),
                        edge_alpha_max=max(alpha.crop(b).getextrema()[1] for b in [(0,0,im.width,1),(0,im.height-1,im.width,im.height),(0,0,1,im.height),(im.width-1,0,im.width,im.height)]),
                        display_height=height, display_width=round((x1-x0)*height/(y1-y0),2)))
    provenance.append(dict(id=key, output=path.name, output_sha256=digest(path),
                           generated_source=generated, tool="built-in image_gen", transparent_background=True,
                           prompt=(ART/(key+"_prompt.txt")).read_text(encoding="utf-8"),
                           reference_order=[dict(path=ref, sha256=digest(ROOT/ref)) for ref in refs]))
def write(name, data):
    (ART/name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
write("registration.json", dict(status="concept_preview_only", items=items))
write("asset_report.json", dict(alpha_cutout=0.5, source_pixels_unchanged=True, items=reports))
record = dict(date="2026-10-25", status="director_concepts_user_review_pending",
                              scope="Four stationary ordinary guards; no encounter, stats, animation or campaign changes",
                              reference_roles="Each prompt explicitly states the input image role and order.",
                              items=provenance)
if args.variant_b:
    record["variant"] = "B sealed lockdown alternative; original A preserved"
    record["discarded"] = [dict(output="guard_rusher_b_draft.png",
        output_sha256=digest(ART/"guard_rusher_b_draft.png"),
        generated_source="exec-342d04f2-201e-4ea7-a857-9dcb283c9ee6.png",
        reason="Too similar to A in head shape and pose; body silhouette redesigned.",
        tool="built-in image_gen",
        prompt=(ART/"guard_rusher_draft_prompt.txt").read_text(encoding="utf-8"),
        reference_order=[dict(path=p,sha256=digest(ROOT/p)) for p in [
            hero, background, R+"central_guard_concepts_20261025/guard_rusher_v1.png"]])]
write("provenance.json", record)
print(json.dumps(reports, ensure_ascii=False, indent=2))
