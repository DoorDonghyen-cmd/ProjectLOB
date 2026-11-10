"""Promote the approved editor-visible shop layout; production never creates demo state."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT = next(p.parent for p in ROOT.glob('*/project.godot'))
source = (PROJECT / 'redesign/samples/shop_wireframe_preview.tscn').read_text(encoding='utf-8')
source = source.replace('res://redesign/samples/shop_wireframe_preview.gd', 'res://redesign/shop_screen.gd')
header, *nodes = re.split(r'(?=\[node )', source)
wrapper = '''[node name="ShopScreen" type="Control"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
script = ExtResource("logic")

'''
result = [header, wrapper]
for index, node in enumerate(nodes):
    if index == 0:
        node = node.replace('[node name="ShopWireframePreview" type="Control"]', '[node name="Canvas" type="Control" parent="."]')
        node = node.replace('script = ExtResource("logic")\n', '')
        node = node.replace('anchors_preset = 15', 'anchors_preset = 0').replace('anchor_right = 1.0\n', '').replace('anchor_bottom = 1.0\n', '')
        node += 'offset_right = 1600.0\noffset_bottom = 900.0\n\n'
    else:
        node = re.sub(r'parent="([^"]+)"', lambda m: 'parent="Canvas' + ('' if m[1] == '.' else '/' + m[1]) + '"', node, count=1)
    if 'name="Reset"' in node:
        node = node.replace('name="Reset"', 'name="Menu"').replace('text = "초기화"', 'text = "메뉴"')
    if 'name="PreviewBadge"' in node:
        node = node.replace('name="PreviewBadge"', 'name="RunNotice"').replace('text = "상점 시안"', 'text = "연습 · 저장 안 함"')
        node += 'visible = false\n\n'
    if 'name="Exit"' in node:
        node = node.replace('text = "시안 닫기  →"', 'text = "맵으로 계속  →"')
        result.append('''[node name="LegacyServices" type="HBoxContainer" parent="Canvas/Safe/Layout/Rows/Footer/InspectorFooter"]
layout_mode = 2
theme_override_constants/separation = 12
visible = false

''')
        for name, text in [('LegacyCompress', '영구 압축'), ('LegacyTune', '탄환 개조')]:
            result.append(f'''[node name="{name}" type="Button" parent="Canvas/Safe/Layout/Rows/Footer/InspectorFooter/LegacyServices"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 44)
theme_override_font_sizes/font_size = 20
text = "{text}"

''')
    # Preserve entry-visible narrative, but let long regional stories scroll by touch.
    if 'name="Copy"' in node and 'parent="Canvas/Safe/Layout/Rows/Overview/Market/Story"' in node:
        result.append('''[node name="StoryScroll" type="ScrollContainer" parent="Canvas/Safe/Layout/Rows/Overview/Market/Story"]
layout_mode = 2
custom_minimum_size = Vector2(330, 212)
size_flags_horizontal = 3
horizontal_scroll_mode = 0

''')
        node = node.replace('parent="Canvas/Safe/Layout/Rows/Overview/Market/Story"', 'parent="Canvas/Safe/Layout/Rows/Overview/Market/Story/StoryScroll"')
        node = node.replace('custom_minimum_size = Vector2(330, 0)', 'custom_minimum_size = Vector2(0, 0)')
        node = node.replace('alignment = 1', 'alignment = 0')
    elif 'parent="Canvas/Safe/Layout/Rows/Overview/Market/Story/Copy' in node:
        node = node.replace('/Story/Copy', '/Story/StoryScroll/Copy')
    if any(f'name="{key}"' in node for key in ['Name', 'Description', 'ItemName', 'Composition', 'Weapon', 'PartName']):
        node += 'text_overrun_behavior = 3\n\n'
    if 'name="Change"' in node:
        node += 'max_lines_visible = 3\ntext_overrun_behavior = 3\n\n'
    if 'name="Cost"' in node:
        node += 'max_lines_visible = 2\ntext_overrun_behavior = 3\n\n'
    result.append(node)

def button(name, parent, text, width=120):
    return f'''[node name="{name}" type="Button" parent="{parent}"]
layout_mode = 2
custom_minimum_size = Vector2({width}, 44)
theme_override_font_sizes/font_size = 20
text = "{text}"

'''
result.append(button('Settings', 'Canvas/Safe/Layout/Header', '설정', 92))
result.append(button('Manage', 'Canvas/Safe/Layout/Rows/Overview/Inspector/Loadout/Inset/Content/TitleRow', '파츠 관리', 120))
(PROJECT / 'redesign/shop_screen.tscn').write_text(''.join(result), encoding='utf-8')
print('Authored production shop_screen.tscn from the approved layout.')
