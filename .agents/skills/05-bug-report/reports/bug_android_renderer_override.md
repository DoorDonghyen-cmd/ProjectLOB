# AND-01: 모바일 렌더러 불일치와 패키지 검사 실패

2026-09-12 / Verified(패키지 검증 범위) / 보통 / prototype/core-redesign.

## 재현
기존 설정은 일반 rendering_method만 gl_compatibility로 지정했다. Android에서는 rendering_method.mobile의 Mobile 기본값을 사용했고, APK에 Vulkan feature가 추가됐다. Godot4.7 템플릿 exporter가 추가한 required 속성이 문자열로 기록되어 aapt36.1 badging 검사에 타입 오류가 발생했다. 실제 기기 설치 실패로 재현한 것은 아니다.

## 수정과 검증
모바일 렌더러를 gl_compatibility로 명시해 의도한 렌더러를 고정했다. 최종 APK에 Vulkan 항목이 없고 GL ES3/가로 방향이 기록된다. aapt 패키지 조회, apksigner v2/v3, zipalign, CRC 통과. PC 터치34검증 통과. 실제 Android 실행은 미검증.

정본 docs/walkthrough_android_test_2026-09-12.md 및 docs/qa/reports/android_package_2026-09-12.json. 게임 규칙/모델 변경 없음.
