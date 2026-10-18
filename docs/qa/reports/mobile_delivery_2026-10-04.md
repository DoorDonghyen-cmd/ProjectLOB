# Galaxy APK와 Drive 전달 — 2026-10-04

사용자 요청으로 최신 작업 트리의 Android APK를 생성하고 ZIP으로 묶어 연결된 Google Drive에 업로드했다. 게임 규칙은 이번 전달 작업에서 변경하지 않았다.

- [모바일 ZIP 다운로드](https://drive.google.com/file/d/13lfDVu3Bd6x1xXvvcJ6FRFEzwZesYT-_/view?usp=drivesdk)
- [모바일 빌드 보관 폴더](https://drive.google.com/drive/folders/1TFdLBn5mCbLWtwg2EP-ZeNW1oCgcWzbO)
- 버전 `0.5.20261004.234301`, code `20261005`, 모델 v11
- ZIP `LastOnBoard-20261004-234301-v20261005.zip`, 101,036,254바이트
- 로컬 `builds/mobile/releases/LastOnBoard-20261004-234301-v20261005/`
- 소스 커밋 `7037ee41b6daf2e553eb5d2ec3498735f3d98c1e` + 현재 미커밋 작업 포함

## 확인한 범위

기존 패키지 `com.lastonboard.prototype`와 서명 SHA-256을 유지했다. 이전 모바일 빌드보다 version code를 올렸으므로 삭제 없이 업데이트 설치할 수 있다. Android 최소24/대상36, ARM64·ARMv7, 가로 화면을 확인했다.

APK 서명 v2/v3, 4바이트·16KiB 정렬, 761항목 CRC와 필수 리소스, 테스트 코드 미포함을 검사했다. 661개 에셋을 격리 공간에 추출해 컴파일된 실제 모델 v11과 메인 씬을 PC Godot에서 실행했다. 5무기의 초기 패·LIFO·확정·부분 냉각을 확인했다. 기존 게임 회귀 결과는 [선택 가치 개편 검증](decision_revision_2026-10-04.md)에 있다.

ZIP에는 APK·INSTALL.md·RELEASE_NOTES.md·빌드/검증 manifest·SHA256SUMS.txt만 포함된다. 저장 데이터·서명 키·QA 프로필·에디터 설정·원본 소스를 포함하지 않는다. 포장 허용 목록/덮어쓰기 거부, 잘못된 이름·대상 폴더·크기·URL·체크섬과 변조된 다운로드 거부의 자동 검사 6개를 통과했다.

Drive에서 파일명·MIME·크기·부모 폴더·소유자 전용 권한을 다시 읽었다. 연결 도구의 정규화 메타데이터가 체크섬을 생략해 파일 전체를 다시 내려받았고, 아래 ZIP SHA-256과 동일함을 확인했다. 실제 업로드 응답/메타데이터와 `upload_receipt.json`, 전달 상태 `uploaded`는 release 폴더 및 `builds/mobile/latest.json`에 보존했다. 공개 공유를 켜지 않았다.

| 파일 | SHA-256 |
|---|---|
| APK | `b88179c622085f57aa8223625df916f0b41d750e939a574f7b00887b5cac4f5a` |
| ZIP·Drive 재다운로드 | `8344717b558334f7ac25b4b019084c7f8f26ef790b0ea0cdf6370979b002ab08` |

## 재사용과 한계

[모바일 전달 절차](../../mobile-delivery.md), `BUILD_MOBILE.cmd`, `tools/build_mobile_release.ps1`, `tools/mobile_release.py`, `tools/mobile_delivery.json`을 추가했다. APK 요청은 에이전트가 빌드부터 Drive 링크까지 수행한다. CMD 단독 실행은 검증된 ZIP 생성까지다. 업로드 실패 시 같은 ZIP을 검증/재사용하며 인증정보를 저장소에 넣지 않는다.

첫 검사에서는 격리 Godot의 기존 Windows 인증서 저장소 오류를 게임 로딩 실패로 집계했다. 해당 알려진 메시지만 검사에서 제외하고 새 빌드로 전체 파이프라인을 재실행했다. 스크립트/파싱/기타 ERROR는 여전히 실패 처리한다. 같은 날 생성한 두 빌드의 버전 코드가 증가하는 것도 확인했다.

실제 Android 기기·에뮬레이터에서 실행한 것은 아니다. Galaxy 설치/성능/터치 체감은 사용자가 이 ZIP으로 확인한다. 커밋·푸시는 수행하지 않았다.
