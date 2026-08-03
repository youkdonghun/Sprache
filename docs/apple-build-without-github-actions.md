# GitHub Actions 없이 Apple 미리보기 빌드

GitHub Actions는 Sprache의 iOS·macOS 빌드에 필수가 아니다. 필요한 것은 Xcode와
iOS Simulator가 설치된 macOS 실행 환경이다. 이 저장소는 Codemagic의 macOS M2
실행기와 보유·임대 Mac 양쪽에서 같은 스크립트를 사용한다.

## 산출물 범위

- `Sprache-iOS-Simulator-1.32.0-mock.zip`: iOS Simulator 전용 앱이며 IPA가 아니다.
- `Sprache-macOS-1.32.0-mock.zip`: ad-hoc 서명된 미리보기 앱이며 공증 배포본이 아니다.
- 두 앱 모두 실제 Local-First 학습 UI와 로컬 저장소를 사용한다. `MOCK` 표시는 현재
  Apple 플랫폼에서 Google 로그인·Drive 연결을 제공하지 않는다는 뜻이다.
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

현재 미리보기 범위에는 Apple 비밀값이 없으므로 Codemagic 환경변수에 인증서나
토큰을 추가하지 않는다. 저장소 연결 권한 외에는 별도 비밀값이 필요하지 않다.

## 격리된 전용 Mac

이 스크립트는 프로덕션과 같은 macOS bundle ID로 앱을 실제 실행하므로 평소 사용하는
macOS 계정에서는 실행하지 않는다. Flutter 3.44.8, Xcode, CocoaPods가 준비된 임시 CI
계정 또는 학습 데이터가 전혀 없는 전용 macOS 사용자에서만 저장소 루트 기준으로
명시적으로 실행한다.

```bash
SPRACHE_ALLOW_ISOLATED_APPLE_RUNTIME=1 bash tool/build-apple-preview.sh
```

기본 출력은 `artifacts/apple-preview`에 생성된다. 버전과 출력 위치를 바꿀 때는
`SPRACHE_VERSION`, `SPRACHE_BUILD_NUMBER`, `SPRACHE_APPLE_ARTIFACT_DIR`을 사용한다.
스크립트는 macOS가 아니거나 필수 Apple 도구가 없거나 실행 환경이 격리됐다는 명시적
확인이 없으면 산출물을 가장하지 않고 즉시 중단한다. iOS에는 기존 Simulator를
재사용하지 않고 전용 임시 Simulator를 생성하며 작업 후 삭제한다.
