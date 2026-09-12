# 갤럭시 테스트 APK

사용자의 갤럭시 테스트 요청에 따라 다수전 개선판(8828839)을 Android APK로 제공한다. 기존 규칙/그래픽/Windows 빌드는 유지한다.

- 기존 Godot 4.7 Android 템플릿과 설치된 JDK17/Android SDK를 사용한다. Gradle 소스 빌드가 아닌 템플릿 APK 내보내기다.
- 테스트용 패키지 `com.lastonboard.prototype`, ARM64/ARMv7, 가로 회전, 기존 GL Compatibility를 사용한다. APK는 테스트 서명으로 서명한다.
- 프로젝트/사용자 내보내기 설정을 영구 변경하지 않고 임시 프리셋과 격리된 에디터 설정을 사용한다. 키 파일/비밀번호를 저장소에 복사하지 않는다.
- 터치 입력으로 시작·장전·확정·사격·정보·다수전 개별 적 확인을 PC에서 시뮬레이션한다. 휴대폰의 실제 GPU/터치 체감 확인과 구분한다.
- APK 패키지/ABI/최소 OS/가로 방향/리소스 포함 및 서명/정렬을 도구로 확인한다. 연결된 기기나 에뮬레이터가 없으면 APK의 실제 Android 실행 검증은 미완료로 명시한다.
- `builds/android-test/LastOnBoard-test.apk`와 설치 안내를 제공하고 작업 기록/로컬 커밋을 남긴다.
