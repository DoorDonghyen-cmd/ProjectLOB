# Galaxy APK와 Drive 전달 — 2026-10-05

사용자 요청으로 현재 작업 트리의 Android APK를 생성하고 ZIP으로 묶어 기존 Google Drive 폴더에 업로드했다. 재다운로드한 파일의 SHA-256까지 확인했다.

- [모바일 ZIP 다운로드](https://drive.google.com/file/d/1UTMy6of0LEjSksHLhauognYCZAIAHE4m/view?usp=drivesdk)
- 버전 `0.5.20261005.232901`, code `20261007`, 전투 모델 v12
- ZIP `LastOnBoard-20261005-232901-v20261007.zip`, 104,028,908바이트
- APK 105,230,863바이트
- 로컬 `builds/mobile/releases/LastOnBoard-20261005-232901-v20261007/`
- 소스 커밋 `7037ee41b6daf2e553eb5d2ec3498735f3d98c1e`와 미커밋 작업 포함

## 포함한 변경

[변경 내역](../../releases/2026-10-05-mobile.md). v12의 탄창·총기·파츠 연계, 주인공과 기존 적7종의 v2 도트 표현, 주인공4키포즈 및 전투 반응, 실제 거리에 맞는 적·투사체 배치를 포함한다. 최근 재정리한 몬스터 컨셉·명칭은 기획 단계이며 신규 몬스터 구현으로 포함하지 않았다.

## 검증

- 기존 패키지 `com.lastonboard.prototype`, 서명, ARM64·ARMv7 지원을 유지했다. 이전 전달본보다 version code가 높다. 기존 앱을 삭제하지 않고 업데이트한다.
- APK 서명·4바이트/16KiB 정렬·패키지 정보를 검사했다. 785개 항목 CRC와 필수 리소스 및 테스트 코드 미포함을 확인했다.
- 추출한 실제 컴파일 리소스 685개로 PC Godot에서 메인 씬과 모델 v12를 격리 저장으로 실행했다. 5무기의 초기 패·LIFO·확정·부분 냉각 검사를 통과했다.
- 현재 주인공·적7종·주인공4키포즈에 쓰는 텍스처9개가 APK에 포함되고 이전 배우 v1 시안8개는 제외된 것을 확인했다.
- 전달 도구 자동 검사7개 통과. 신규 검사는 제한을 초과한 ZIP에 업로드 요청을 발급하지 않는지 확인한다.
- Drive 메타데이터의 파일명·MIME·크기·부모 폴더와 소유자 권한을 읽었다. 공유 권한은 바꾸지 않았다. 원격 파일을 다시 내려받아 로컬 ZIP과 SHA-256을 대조했다.
- `upload_response.json`, `drive_metadata.json`, `upload_receipt.json`과 전달 상태 `uploaded`를 release 폴더 및 `builds/mobile/latest.json`에 기록했다.

| 파일 | SHA-256 |
|---|---|
| APK | `ef775cc099467c9959f0b97a6d69c581dcfa5a9372d4a8a9925de282d00fdd68` |
| ZIP·Drive 재다운로드 | `c4131debe52d88f0593e053c6b6b729de5c69323de00584cc9d9020928953ab0` |

## 전달 중 수정과 한계

첫 ZIP(code `20261006`, 106,850,391바이트)은 Drive 연결 도구의 100MiB 제한으로 업로드 호출 전에 거절됐다. 게임 리소스의 참조를 검색해 현재 쓰지 않는 `actor_cohesion_20261005/*_v1.png`만 export에서 제외하고 새 버전으로 빌드했다. 원본은 보존했고 현행 v2·별도 폴더의 동작 v1·32/64비트 지원은 유지했다. 앞으로 포장 단계에서 크기 상한을 검사한다. [전달 절차](../../mobile-delivery.md).

Android 기기·에뮬레이터에서 설치·실행한 검사는 아니다. Galaxy의 성능·터치·화면 체감은 사용자의 플레이 테스트로 확인한다. 게임 규칙·사용자 저장 변경, 커밋·푸시는 수행하지 않았다.
