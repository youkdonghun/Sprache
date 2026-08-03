# GitHub Actions 없이 Apple 미리보기 빌드

GitHub Actions는 Sprache의 iOS·macOS 빌드에 필수가 아니다. 필요한 것은 Xcode와
iOS Simulator가 설치된 macOS 실행 환경이다. 이 저장소는 Codemagic의 macOS M2
실행기와 보유·임대 Mac 양쪽에서 같은 스크립트를 사용한다.

## 산출물 범위

- `Sprache-iOS-Simulator-1.34.1-google-configured.zip`: iOS Simulator 전용
  REAL-configured 앱이며 IPA가 아니다.
- `Sprache-macOS-1.34.1-google-configured.zip`: ad-hoc 서명된 REAL-configured
  미리보기 앱이며 공증 배포본이 아니다.
- 두 앱 모두 Local-First 학습 UI, 로컬 저장소와 iOS-type Google OAuth metadata를
  포함한다. 첫 프레임 검증은 계정 선택이나 Drive 왕복을 수행하지 않으므로
  `googleOAuthRuntimeVerified=false`를 evidence에 기록한다.
- iPhone 설치용 IPA에는 Apple Developer 인증서와 provisioning profile이 필요하다.
- 일반 배포용 macOS 앱에는 Developer ID 서명과 Apple 공증이 필요하다.

## Codemagic

저장소 루트의 `codemagic.yaml`을 사용하는 `apple-preview` 워크플로를 수동으로
실행한다. 워크플로는 Flutter 3.44.8과 최신 Xcode를 사용하고 다음 절차를 한 Mac에서
연속 수행한다.

1. iOS Simulator 앱을 빌드한다.
2. Simulator에 설치하고 실제 첫 프레임 증거와 스크린샷을 수집한다.
3. macOS release 앱을 빌드하고 ad-hoc 재서명한다.
4. macOS 앱을 실제 실행하고 첫 프레임 증거를 수집한다.
5. 두 `.app` 번들을 `ditto` ZIP과 SHA-256 파일로 패키징한다.

Apple Client ID는 공개 식별자로 스크립트의 `GOOGLE_APPLE_CLIENT_ID` define에
전달한다. Codemagic 환경변수에 Apple 인증서, provisioning profile, OAuth 토큰
또는 사용자 계정을 추가하지 않는다.

## 격리된 전용 Mac

이 스크립트는 프로덕션과 같은 macOS bundle ID로 앱을 실제 실행하므로 평소 사용하는
macOS 계정에서는 실행하지 않는다. Flutter 3.44.8, Xcode, CocoaPods가 준비된 임시 CI
계정 또는 학습 데이터가 전혀 없는 전용 macOS 사용자에서만 저장소 루트 기준으로
명시적으로 실행한다.

```bash
SPRACHE_ALLOW_ISOLATED_APPLE_RUNTIME=1 bash tool/build-apple-preview.sh
```

스크립트의 기본 Apple client는
`1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com`이다.
다른 Google Cloud 프로젝트를 검증할 때만 `SPRACHE_GOOGLE_APPLE_CLIENT_ID`로
공개 Client ID를 바꾼다.

기본 출력은 `artifacts/apple-preview`에 생성된다. 버전과 출력 위치를 바꿀 때는
`SPRACHE_VERSION`, `SPRACHE_BUILD_NUMBER`, `SPRACHE_APPLE_ARTIFACT_DIR`을 사용한다.
스크립트는 macOS가 아니거나 필수 Apple 도구가 없거나 실행 환경이 격리됐다는 명시적
확인이 없으면 산출물을 가장하지 않고 즉시 중단한다. iOS에는 기존 Simulator를
재사용하지 않고 전용 임시 Simulator를 생성하며 작업 후 삭제한다.

## 아이폰 직접 설치용 IPA

`codemagic.yaml`의 `ios-direct-install` 워크플로는 시뮬레이터 ZIP이나
TestFlight용 파일이 아니라 Apple Distribution 인증서와 Ad Hoc 프로비저닝
프로파일로 서명된 IPA를 만든다. 번들 ID는 `com.youkdonghun.sprache`이며
Codemagic의 Developer Portal 연동 이름은 `Sprache Apple Developer`로 고정한다.

이 워크플로를 실행하기 전에 Codemagic 개인 계정의 Developer Portal에 같은
이름의 App Store Connect API 키를 연결하고, 번들 ID와 일치하는 Apple
Distribution 인증서 및 Ad Hoc 프로파일을 Code signing identities에 등록해야
한다. Ad Hoc 프로파일에는 설치할 아이폰의 UDID가 포함되어야 한다. 빌드는
`tool/build-ios-device.sh`에서 다음 항목을 실패 조건으로 검증한다.

- Apple Distribution 코드 서명과 10자리 Team Identifier
- 유효기간이 남고 등록 기기가 포함된 Ad Hoc 프로비저닝 프로파일
- `com.youkdonghun.sprache` 번들 ID와 `1.34.1+59` 버전
- Google iOS OAuth 클라이언트 ID와 callback URL scheme
- 실기기용 `iPhoneOS` 플랫폼 및 IPA 내부 구조

출력 파일은 `artifacts/ios-device/Sprache-iPhone-Direct-Install-1.34.1.ipa`다.
프로파일에 등록된 아이폰에서만 설치·실행되며 TestFlight나 App Store 등록은
필요하지 않다.

## 유료 개발자 계정이 없는 Windows 사이드로드

Apple Developer Program이나 TestFlight를 사용하지 않을 때는 Codemagic의
`ios-sideload-package` 워크플로로 iPhoneOS용 unsigned IPA를 만든 뒤 Windows에서
사용자의 무료 Apple 계정으로 로컬 재서명한다. 출력은
`artifacts/ios-sideload/Sprache-iPhone-Sideload-1.34.1-unsigned.ipa`다.

이 파일은 시뮬레이터 바이너리가 아니며 iPhoneOS 기기용으로 컴파일되지만, 서명
전에는 설치할 수 없다. Sideloadly 또는 AltStore 같은 로컬 설치 도구가 사용자의
Apple 계정으로 프로비저닝한 다음 해당 아이폰에 설치한다. 무료 계정 프로파일은
7일 후 만료되므로 같은 PC에서 자동 갱신 기능을 유지해야 한다. 앱 파일에는 Apple
계정 비밀번호나 세션을 포함하지 않으며, 계정 입력은 로컬 설치 도구에서만 한다.
