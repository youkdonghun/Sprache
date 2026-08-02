# iOS 플랫폼 준비 상태

Sprache의 iOS Runner는 Android·Windows와 같은 Flutter 소스 및
`pubspec.yaml` 버전을 사용한다. 현재 Runner의 Bundle ID는
`com.youkdonghun.sprache`이며 최소 iOS 버전은 13.0이다.

## 현재 지원 범위

- iPhone·iPad에서 모바일 학습 테마를 사용한다.
- 발음 녹음과 음성 인식을 위한 개인정보 사용 설명이 `Info.plist`에 있다.
- CI는 실제 기기 서명 없이 iOS Simulator 앱이 컴파일되는지 확인한다.
- CI는 Simulator와 macOS 앱을 실제로 실행하고, Flutter 첫 프레임 완료 뒤 앱
  sandbox에 기록된 CI 전용 evidence를 회수한다.
- Google Drive 연결은 Apple 미리보기 빌드에서 제공하지 않는다. 앱은 비밀값을
  임의로 포함하거나 Android 자격 증명을 재사용하지 않는다.
- iOS·macOS 로컬 학습 알림은 Darwin 권한 요청·예약·시작 및 다시 알림 액션까지
  연결되어 있다. CI `MOCK` 산출물에서는 컴파일 범위를 확인하며 실제 기기의
  권한 배너·예약 전달은 별도 실기기 게이트로 남긴다.

Google 연결을 활성화하려면 별도의 iOS OAuth client ID와 URL scheme을
Google Cloud Console에서 발급하고, iOS용 연결 구현과 Drive 폴더 ID 선택 흐름을
추가해야 한다.

## iOS Simulator 빌드

Xcode와 CocoaPods가 설치된 macOS에서 실행한다.

```bash
cd apps/client
flutter pub get
flutter build ios --simulator --debug \
  --build-name=1.31.0 \
  --build-number=55 \
  --dart-define=APP_ENV=ci \
  --dart-define=ENABLE_MOCK_MODE=true \
  --dart-define=APP_VERSION=1.31.0
```

Simulator 결과는 `build/ios/iphonesimulator/Runner.app`에 생성된다. 이 파일은
iPhone에 설치하는 IPA가 아니다.

## macOS 미리보기 빌드

```bash
cd apps/client
flutter pub get
flutter build macos --release \
  --build-name=1.31.0 \
  --build-number=55 \
  --dart-define=APP_ENV=ci \
  --dart-define=ENABLE_MOCK_MODE=true \
  --dart-define=APP_VERSION=1.31.0
```

결과는 `build/macos/Build/Products/Release/Sprache.app`이다. 현재 CI 전달본은
unsigned/ad-hoc `MOCK`이며 Developer ID 서명·공증된 배포 앱이 아니다.

실제 기기용 컴파일 확인은 다음처럼 코드 서명을 생략할 수 있지만 결과 앱은
기기에 설치할 수 없다.

```bash
flutter build ios --release --no-codesign
```

설치 가능한 IPA에는 Apple Developer 팀, 배포 인증서, provisioning profile과
export options가 필요하다.

```bash
flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist
```

Windows에는 Xcode와 Apple 코드 서명 도구가 없으므로 IPA를 생성하거나 서명할
수 없다. 인증서, provisioning profile, OAuth 비밀값은 저장소에 커밋하지 않는다.

## 구버전 산출물 정리

새 릴리스의 네 플랫폼 manifest와 체크섬이 모두 일치한 뒤에만 구버전 로컬
산출물을 정리한다. 다음 직접 명령은 사전 검토용이며 최종 승격에는
`npm run verify:release:promote -- -ReleaseBundleManifest <manifest>`를 사용한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tool\clean-release-artifacts.ps1 `
  -KeepVersion 1.31.0 `
  -WhatIf
```

검토 후 `-WhatIf`를 제거한다. 스크립트는 저장소의 `artifacts` 폴더 안에서
허용된 APK·Windows ZIP·설치 EXE·체크섬 이름만 처리한다. SQLite 학습 DB,
백업, 로그, 이름을 인식할 수 없는 파일은 삭제하지 않는다.
