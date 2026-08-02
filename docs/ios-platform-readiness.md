# iOS 플랫폼 준비 상태

Sprache의 iOS Runner는 Android·Windows와 같은 Flutter 소스 및
`pubspec.yaml` 버전을 사용한다. 현재 Runner의 Bundle ID는
`com.youkdonghun.sprache`이며 최소 iOS 버전은 13.0이다.

## 현재 지원 범위

- iPhone·iPad에서 모바일 학습 테마를 사용한다.
- 발음 녹음과 음성 인식을 위한 개인정보 사용 설명이 `Info.plist`에 있다.
- CI는 실제 기기 서명 없이 iOS Simulator 앱이 컴파일되는지 확인한다.
- Google Drive 연결과 학습 알림은 iOS에서 아직 명시적으로 지원하지 않는다.
  앱은 비밀값을 임의로 포함하거나 Android 자격 증명을 재사용하지 않는다.

Google 연결을 활성화하려면 별도의 iOS OAuth client ID와 URL scheme을
Google Cloud Console에서 발급하고, iOS용 연결 구현과 Drive 폴더 ID 선택 흐름을
추가해야 한다. 알림을 활성화하려면 Darwin 초기화·권한 요청·알림 상세 설정도
추가해야 한다.

## macOS 빌드

Xcode와 CocoaPods가 설치된 macOS에서 실행한다.

```bash
cd apps/client
flutter pub get
flutter build ios --simulator --debug \
  --dart-define=APP_ENV=ci \
  --dart-define=ENABLE_MOCK_MODE=true
```

Simulator 결과는 `build/ios/iphonesimulator/Runner.app`에 생성된다. 이 파일은
iPhone에 설치하는 IPA가 아니다.

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

새 릴리스의 체크섬이 모두 일치한 뒤에만 구버전 로컬 산출물을 정리한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tool\clean-release-artifacts.ps1 `
  -KeepVersion 1.30.0 `
  -WhatIf
```

검토 후 `-WhatIf`를 제거한다. 스크립트는 저장소의 `artifacts` 폴더 안에서
허용된 APK·Windows ZIP·설치 EXE·체크섬 이름만 처리한다. SQLite 학습 DB,
백업, 로그, 이름을 인식할 수 없는 파일은 삭제하지 않는다.
