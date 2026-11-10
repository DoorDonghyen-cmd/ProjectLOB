# 단말기 주사선 강화

사용자가 화면의 노이즈/가로선을 더 진하게 요청해 `console_glass.gdshader`의 주사선 강도를0.082에서0.20으로 높였다. 강도는 `scanline_strength` uniform으로 노출했다. 기존3픽셀 주기·화면 유리 마스크·움직이는 주사선과 물리 조작부 경계는 유지한다. 이번 변경은2D 셰이더 한 파일이며 화면 배치·입력·계산 변경이 아니다.

[수정 전](../shop_actions_2026-11-05/stock_1280x800.png) · [1280×800](stock_1280x800.png) · [1008×454](stock_1008x454.png) · [S26비율2340×1080](stock_2340x1080.png).

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_shop_live_checks.ps1 -Report shop_scanlines_2026-11-05` — **216검사 실패0**, 셰이더/실행 오류 없음. 실제 캡처에서 가로선의 명암과 상품명·작은 본문·잔액 가독성을 검토했다. [출력](stdout.log) · [오류](stderr.log). 모바일 비율은 PC 렌더이며 실제 Android 확인·사용자 선호 확인은 별도다.

검증 셰이더 SHA256: `ec89a022b11690fc70b60a95a919f3abe6d080fd5df1ce7dde88932caab56dfc`. 작업 중 날짜가 넘어가 완료 기록은2026-11-06 일지에 남겼다.
