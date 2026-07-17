---
name: 08-art-resource-manager
description: 게임 'Last on Board'의 AD(Art Director) 역할을 수행하며, 도트풍(픽셀 아트) 그래픽 리소스의 비주얼 스타일 가이드 수립, 이미지 생성 프롬프트 감수, 리소스 퀄리티 통제 및 Godot 프로젝트 적용을 서포트합니다.
---

# 👑 Art Director (AD) - 도트풍 리소스 제작 및 관리 매니저

이 스킬은 게임 **Last on Board**의 전체적인 비주얼 정체성(Visual Identity)을 통제하는 아트 디렉션(AD) 가이드입니다. 본 프로젝트는 **현대 전술 CQB 테마**와 **네온 사이버펑크 픽셀 아트(도트풍) 감성**을 결합합니다. 에이전트는 아트 리소스의 프롬프트 작성, 리소스 퀄리티 검증, 파일 정리 시 본 가이드라인의 규정을 AD의 입장에서 엄격히 적용해야 합니다.

---

## 📐 1. 비주얼 컨셉 및 스타일 디렉션 (AD Minimalist Pixel Style Guide)

> **정본**: 본 섹션은 GDD [12_art_style_manifesto.md](file:///d:/ProjectLoB/docs/gdd/12_art_style_manifesto.md)를 최종 정본으로 따른다. 충돌 시 매니페스토가 우선한다.

긴박한 테라-호러 무드와 전술적 피아 식별을 위해, **미니멀 16-bit 레트로 픽셀 아트(Minimalist 16-bit Pixel Art)**를 기본 스타일로 채택합니다. 외곽선 없이 명확한 실루엣 면과 플랫한 2톤 명암, 극도로 제한된 뮤트 톤 팔레트가 핵심입니다.

### 1) 캐릭터 및 크리처 비례 (Minimalist 5 Head-Tall Proportions)
* **요원 (Agent)**: **5등신의 미니멀 리얼 비례**를 적용합니다. 어두운 전술 장비를 착용하고 우측을 겨냥하는 사이드 프로필 실루엣. 그레이·다크 그린 중심의 제한된 뮤트 톤과 플랫한 2톤 명암으로 투박하고 직관적인 형태를 묘사합니다. **검은색 외곽선 금지.**
* **몬스터 (감염된 보안/연구 인력)**: 몬스터는 단순 판타지 좀비가 아니라 **감염되거나 나노 기술에 지배당한 전술 요원·연구원**입니다(참조: [09-creative-director](file:///d:/ProjectLoB/.agents/skills/09-creative-director/SKILL.md)). 찢어진 방탄조끼·연구실 가운·깨진 고글·점멸하는 사이버네틱 임플란트 요소를 녹인 기괴한 5등신 실루엣으로 디자인하며, 브라운·다크 레드·뮤트 그린 중심의 제한된 2톤 명암 대비를 적용합니다. **검은색 외곽선 금지.**

---

## 🎨 2. 이미지 생성 프롬프트 디렉션 (AD Minimalist Prompt Book)

이미지를 AI를 통해 생성하거나 에셋을 다듬을 때, 다음 템플릿 공식을 반드시 준수하여 아트 스타일의 일관성을 강제합니다.

### ① 요원 캐릭터 스프라이트 (Agent Sprite)
* **AD 가이드**: 5등신 비례. 측면(Side profile)에서 우측을 바라보는 구도. 극단적으로 제한된 뮤트 톤(Muted tone) 색상과 플랫한 2톤 명암. **검은색 외곽선 금지**. 단색 회색 배경. 미니멀하고 투박한 16-bit 클래식 감성.
* **프롬프트 공식**:
  ```
  A minimalist retro low-res pixel art game sprite of a tactical agent from the side profile facing right, 5-head-tall proportion, wearing dark tactical gear, holding a weapon. Very limited muted color palette (grays, dark greens), flat 2-tone shading, strictly no outlines, blocky pixels, highly stylized and simple silhouette. Isolated on a solid medium-gray background, flat 2D game asset style, nearest neighbor scaling effect --v 6.1
  ```

### ② 몬스터 스프라이트 (감염된 보안/연구 인력, Infected Personnel Sprites)
* **AD 가이드**: 5등신 비례. 측면(Side profile)에서 좌측을 바라보는 구도. 극단적으로 제한된 뮤트 톤 색상과 플랫한 2톤 명암. **검은색 외곽선 금지**. 단색 회색 배경. **감염된 전술 요원/연구원** 테마 — 찢어진 방탄조끼, 연구실 가운, 깨진 고글, 사이버네틱 임플란트 등의 기괴하고 미니멀한 투박한 실루엣.
* **프롬프트 공식**:
  ```
  A minimalist retro low-res pixel art game sprite of a grotesque infected tactical operative (nano-corrupted security guard / lab researcher) from the side profile facing left, 5-head-tall proportion, torn tactical vest or lab coat, cracked goggles, faint cybernetic implants. Very limited muted color palette (browns, dark reds, muted greens), flat 2-tone shading, strictly no outlines, blocky pixels, highly stylized and simple silhouette. Isolated on a solid medium-gray background, flat 2D game asset style, nearest neighbor scaling effect --v 6.1
  ```

### ③ 종합 대치 씬 및 배경 (Cinematic Combat Scene)
* **AD 가이드**: 미니멀리스트 16비트 레트로 스타일의 어두운 기업 실험실/서버실 복도. 제한된 색상과 투박한 블록 픽셀 느낌 유지.
* **프롬프트 공식**:
  ```
  A minimalist retro low-res pixel art game scene of a locked-down near-future corporate laboratory corridor vanishing point, metallic walls, computer server racks. Very limited muted color palette, flat shading, strictly no outlines, blocky pixels, highly stylized and simple silhouette, flat 2D game background --ar 16:9 --v 6.1
  ```

### ④ UI/UX 픽셀 리소스 (UI/UX Pixel HUD Resources)
> **비트수 구분**: 캐릭터·크리처·배경 스프라이트는 **16-bit풍 미니멀 플랫**(§1 정본), HUD/UI 아이콘 계열만 **32-bit풍**(림 라이팅·디더링 명암 허용)으로 밀도를 높인다. 두 밀도를 혼동하지 않는다.

* **AD 가이드**: HUD/UI 전용 화풍(32-bit풍 전술 픽셀아트, 림 라이팅, 디더링 명암)을 적용한 복고풍 HUD/UI 에셋.
* **프롬프트 공식**:
  - **발사 버튼 타겟팅 액센트**:
    ```
    A 32-bit retro pixel art tactical HUD button icon, glowing red neon crosshair reticle, chunky pixel borders, isolated on black background, flat 2D game asset style, nearest neighbor scaling effect --ar 1:1 --v 6.1 --style raw
    ```
  - **탄창 홀로그램 튜브**:
    ```
    A 32-bit retro pixel art tactical HUD ammo tube container, translucent dark glass body with fine pixel-dithered shading, glowing cyan and red pixel borders, isolated on black background, flat 2D game asset style, nearest neighbor scaling effect --ar 1:1 --v 6.1 --style raw
    ```
  - **인벤토리 헥사곤 판넬**:
    ```
    A 32-bit retro pixel art tactical HUD grid panel, dark teal translucent background with a fine pixelated cyan hexagon grid pattern, thick beveled pixel borders, isolated on black background, flat 2D game asset style, nearest neighbor scaling effect --ar 1:1 --v 6.1 --style raw
    ```

---

## 🔍 3. AD 리소스 검수 기준 (Pixel QA Gate)

1.  **텍스처 뭉개짐(Filter Check) 절대 금지**:
    - 도트 가장자리가 흐릿하게 뭉개지거나 그라데이션 필터가 먹은 리소스는 승인하지 않습니다.
2.  **픽셀 비례 일관성 (Pixel Ratio)**:
    - 한 화면에 표시되는 리소스 간의 픽셀 크기(해상도 대비 도트 픽셀의 크기)가 달라지는 '믹셀(Mixels)' 현상이 일어나지 않도록 제어합니다.
3.  **색상 단순화**:
    - 팔레트에 불필요하게 미세한 중간색 색조가 너무 많이 들어가 도트 본연의 맛을 흐리는 경우, 팔레트 수를 16색~32색 한도로 제한하도록 재가공합니다.
4.  **배경 투명성(Alpha Channel) 통과**:
    - 모든 단독 스프라이트 및 UI 요소는 **배경이 없는 투명(Alpha) 상태의 PNG 포맷**이어야 하며, 단색(검은색, 차콜색) 박스 테두리가 잔존해서는 안 됩니다.
5.  **외곽선 원칙 적용 범위 (Outline Scope)**:
    - **검은색 외곽선 절대 금지** 원칙은 **캐릭터·크리처·배경 스프라이트에만** 적용됩니다. 실루엣과 플랫 명암으로 형태를 잡는 대상입니다.
    - **예외 — 탄환 투사체 아이콘**: 탄환 아이콘은 어두운 전투 트랙 위에서 가독성을 확보해야 하는 소형 HUD 아이콘이므로, [AGENTS.md](file:///d:/ProjectLoB/.agents/AGENTS.md) 탄환 규칙에 따라 **1px 두께의 선명한 검은색 아웃라인을 의무 적용**합니다. 이는 캐릭터 no-outline 원칙과 별개의 탄환 전용 규격입니다.

---

## ⚙️ 4. Godot 4.x 엔진 적용 SOP (Godot Pixel Integration)

도트풍 리소스가 게임 화면에서 깨지지 않고 선명하게 출력되기 위해, Godot 엔진 적용 시 다음을 반드시 수행해야 합니다.

### ① Import 필터 셋팅 강제
*   Godot 프로젝트의 `Import` 탭에서 **Texture2D ➡️ Compress ➡️ Mode**를 `Lossless`로 설정합니다.
*   **Mipmaps ➡️ Generate**를 반드시 `Disable`로 설정하여 원거리에서 도트가 흐려지는 현상을 막습니다.
*   **CanvasTexture / TextureFilter**를 **`Nearest`**로 적용하여 확대/축소 시 강제적인 픽셀 보간(Bilinear)을 차단하고 픽셀 엣지를 칼처럼 세웁니다.

### ② 인게임 렌더링 스케일 기준 (Scale & Proportion)
*   **크기 렌더링 기준**: 에셋은 기본 140x140 픽셀의 `TextureRect` 영역에 맞춰 렌더링됩니다.
*   **요원(Agent)**: 게임 내 렌더링 스케일을 **0.5**로 고정하여 화면을 가리지 않는 날렵한 크기로 셋팅합니다.
*   **몬스터(Monster)**: 게임 내 렌더링 스케일을 **0.75**로 고정하여, 요원보다 **1.5배** 거대하고 위압감 있는 비율(1:1.5)을 유지합니다.

---

## 🛠️ 5. 이미지 생성 및 후처리 파이프라인 (Image Generation & Post-processing)

아트 리소스 생성 및 적용 작업 시 다음 절차를 따릅니다.

### 1) 미드저니-제미나이 연계 파이프라인 (Midjourney to Gemini Pipeline)
* **기본 원칙**: 리소스의 "기본 베이스"는 미드저니를 통해 확보하고, 해당 리소스를 "리터칭 및 후보정"하는 역할을 제미나이가 담당하는 순차적 연계 파이프라인을 따릅니다.
* **1단계 - 미드저니 (베이스 리소스 생성)**:
  * 고해상도의 극적인 라이팅, 세밀한 텍스처 디더링, 그리고 복잡한 구도가 필요한 픽셀 아트의 원본 뼈대(Base)를 미드저니를 통해 생성 및 획득합니다.
* **2단계 - 제미나이 (리터칭 및 후보정)**:
  * 미드저니가 생성한 원본 이미지를 제미나이(이미지 편집 기능 활용)에 전달하여, 의도와 맞지 않는 디테일을 수정하거나 게임 에셋 규격에 맞게 픽셀 외곽선 등을 다듬는 리터칭 후작업을 진행합니다.
  * *제미나이 리터칭 프롬프트 보완 가이드*: 리터칭 시 기존 픽셀 스타일이 뭉개지지 않도록 다음 키워드를 명시적으로 포함합니다:
    * `"maintain flat 2D pixel art style, strictly no 3D rendering or realistic shading"`
    * `"vintage tactical game sprite style, crisp pixel edges, based on the provided image structure"`

### 2) 후처리 배경 투명화 및 PNG 변환 (Background Removal SOP)
* 이미지 생성 시 단색 누끼 추출을 용이하게 하기 위해 `isolated on a solid black background` 또는 `isolated on a solid dark charcoal background` 설정을 필수로 유지합니다.
* 이미지 획득 직후, 파이썬 Pillow 라이브러리의 **플러드 필(Flood-fill) 알고리즘**을 활용해 외곽 영역의 단색 배경만 알파 투명 채널로 키잉(Keying) 아웃합니다.
* 외곽 배경 제거 처리가 끝난 리소스는 **`.png` 포맷**으로 최종 변환하여 Godot 프로젝트 폴더([새-게임-프로젝트/assets/sprites/](file:///d:/ProjectLoB/새-게임-프로젝트/assets/sprites/)) 내에 저장합니다.
* 기존 단색 배경을 품은 소스 파일은 가비지로 남지 않도록 로컬 저장소에서 완벽히 제거합니다.

