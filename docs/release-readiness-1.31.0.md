# Sprache 1.31.0 릴리스 준비 감사

이 문서는 빌드 전 정적 준비 상태와 안전한 실행 순서를 기록한다. 실제 빌드·기동
결과와 SHA-256은 최종 검증 보고서와 `release-manifest-1.31.0.json`이 우선한다.

## 정적 준비 확인

- 앱 기준 버전은 `pubspec.yaml`의 `1.31.0+55`이며 Android, iOS, macOS,
  Windows 메타데이터가 이 값을 사용한다.
- Android application ID와 Apple Bundle ID는 `com.youkdonghun.sprache`, Windows
  실행 파일은 `sprache.exe`, 제품명은 네 플랫폼 모두 `Sprache`다.
- CSV·TSV·XLSX·JSON·JSONL과 `sprache://` 진입점은 Android intent filter,
  Apple document/URL metadata, Windows 사용자 범위 Open With·protocol로 등록한다.
  Windows는 기존 기본 앱을 강제로 바꾸지 않는다.
- Android 런처 아이콘은 mdpi 48px부터 xxxhdpi 192px, iOS는 20px부터
  marketing 1024px, macOS는 16px부터 1024px 자산을 갖춘다. iOS 1024px 아이콘은
  alpha 없는 RGB 이미지이며 Windows ICO는 16·24·32·48·64·128·256px 32-bit
  프레임을 포함한다.
- 최종 spec의 정책은 Windows·Android `REAL`, iOS Simulator·macOS
  unsigned/ad-hoc `MOCK`이다. Apple Actions의 ZIP 이름과 spec 이름이 일치한다.
- `release-bundle.mjs`의 생성·변조·경로 탈출·거짓 첫 프레임 차단 테스트가
  통과했다.
- CI 전용 release probe는 일반 빌드에서 기본 비활성화되며, Apple Actions에서만
  첫 Flutter 프레임 뒤 evidence를 기록한다.
- 구버전 산출물 정리는 네 플랫폼 manifest 재검증 경로가 없으면 중단한다.

## 실제 릴리스 실행 순서

1. `flutter analyze`, 전체 Flutter 테스트, 시각·semantics·성능 테스트와
   `npm test`를 모두 통과시킨다.
2. `npm run build:real`로 Windows 설치 EXE·포터블 ZIP과 Android APK를 만든다.
3. `npm run verify:release`로 버전·ABI·운영 설정·서명 상태·SHA-256을 검증한다.
4. Android 에뮬레이터 한 대를 켜고 `npm run capture:runtime:android -- ...`로
   최종 APK의 설치·foreground·렌더 프레임·스크린샷 evidence를 만든다.
5. 기존 1.30 실행본이 있으면 새 포터블과 해시를 먼저 확인한 뒤 프로세스를
   종료한다. 학습 DB·복구 백업은 유지하고 구 프로그램 파일만 정리한다.
6. `npm run capture:runtime:windows -- ...`로 최종 설치 EXE를 격리 설치하고
   픽셀 첫 프레임 evidence를 만든 뒤 자동 제거한다.
7. 변경을 푸시해 GitHub Actions의 iOS Simulator·macOS 작업을 통과시키고,
   두 ZIP과 `runtime-ios.json`, `runtime-macos.json`을 내려받는다.
8. 네 플랫폼 파일을 최종 폴더에 모아 `create:release-bundle`과
   `verify:release-bundle`을 차례로 실행한다.
9. 최종 manifest가 통과한 뒤에만 `verify:release:promote`로 저장소의 구버전
   릴리스 산출물을 정리한다.

## 외부 조건과 표시 의무

- Android release keystore가 없으면 APK는 실제 서비스 연결 빌드이지만
  `google-debug-signed`로 표시한다. Play 배포본이라고 부르지 않는다.
- Windows 코드서명 인증서가 없으면 설치 EXE는 기능 검증용 무서명 파일이다.
- Apple Developer 인증서·provisioning·공증이 없으므로 iOS ZIP은 IPA가 아니며,
  macOS ZIP도 공증된 배포 앱이 아니다.
- 실제 Apple 첫 프레임 evidence는 커밋이 푸시된 뒤 macOS GitHub runner에서만
  생성할 수 있다.
