# Sprache 1.36.0 iPhone 설치 가이드

## 현재 준비 상태

- 앱과 Apple 빌드 설정은 `1.36.0+61`로 맞춰져 있습니다.
- Codemagic에는 무료 계정용 `ios-sideload-package`, 등록 기기용 `ios-direct-install`, macOS·iOS 시뮬레이터 확인용 `apple-preview`가 준비돼 있습니다.
- 새 iOS·macOS 파일은 GitHub에 최신 소스를 올린 뒤 Codemagic의 macOS 빌드 머신에서 생성해야 합니다. Windows에서는 Xcode와 Apple 서명을 사용할 수 없어 같은 결과물을 직접 만들 수 없습니다.

## 가장 간단한 무료 방법: PWA

유료 Apple 개발자 계정도, 7일마다 재설치하는 작업도 필요 없는 방법입니다.

1. iPhone의 Safari에서 `https://sprache6.github.io/app/`를 엽니다.
2. 공유 버튼을 누릅니다.
3. `홈 화면에 추가`를 누릅니다.
4. `웹 앱으로 열기`가 보이면 켠 뒤 `추가`를 누릅니다.

홈 화면 아이콘으로 일반 앱처럼 실행할 수 있습니다. 이 배포 경로에는 Railway와 Cloudflare가 필요하지 않습니다. 앱은 GitHub Pages에서 내려받고, 사용자의 영구 학습 자료는 연결한 Google Drive에 저장합니다.

Apple 공식 안내: https://support.apple.com/guide/iphone/iphea86e5236/ios

## 무료 Apple 계정으로 IPA 설치

1. 최신 소스를 GitHub에 올립니다.
2. Codemagic에서 `ios-sideload-package` 워크플로를 실행합니다.
3. 결과물 `Sprache-iPhone-Sideload-1.36.0-unsigned.ipa`를 내려받습니다.
4. Windows에서 Sideloadly 또는 AltStore로 자신의 Apple 계정 서명을 입혀 iPhone에 설치합니다.
5. 무료 Personal Team 프로비저닝은 발급 후 7일에 만료되므로, 계속 사용하려면 7일마다 다시 서명하고 설치해야 합니다.

Apple은 무료 계정의 Personal Team에 대해 App ID 최대 10개, 플랫폼별 시험 기기 최대 3개, 프로비저닝 프로필 7일 만료 제한을 안내합니다.

Apple 멤버십 비교: https://developer.apple.com/support/compare-memberships/

## 7일 갱신 없이 IPA를 직접 설치하려면: Ad Hoc

1. Apple Developer Program에 가입합니다. 현재 안내 가격은 연 99달러 또는 지역 통화입니다.
2. 설치할 iPhone의 UDID를 Apple Developer 계정에 등록합니다.
3. `com.youkdonghun.sprache` App ID, Apple Distribution 인증서, 등록 기기가 포함된 Ad Hoc 프로비저닝 프로필을 준비합니다.
4. Codemagic의 App Store Connect 연동과 서명 파일을 설정합니다.
5. `ios-direct-install` 워크플로를 실행합니다.
6. 결과물 `Sprache-iPhone-Direct-Install-1.36.0.ipa`를 등록된 iPhone에 설치합니다.

이 방식은 TestFlight를 사용하지 않지만, 등록되지 않은 iPhone에는 설치할 수 없습니다. 회원 자격과 인증서·프로비저닝 프로필이 유효해야 하며, 기기를 추가하면 프로필을 다시 생성해야 할 수 있습니다.

Apple Ad Hoc 안내: https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/

Codemagic YAML 서명 안내: https://docs.codemagic.io/yaml-code-signing/signing-ios/

## 이번 버전을 Codemagic에 보내기 위한 마지막 작업

현재 PC에서는 GitHub CLI 로그인이 풀려 있습니다. 저장소 폴더에서 다음 명령으로 한 번 로그인해야 합니다.

```powershell
gh auth login
```

로그인이 끝나면 변경분을 현재 브랜치에 커밋·푸시하고 Codemagic Apple 워크플로를 실행한 뒤, 새 iOS·macOS 결과물로 바탕화면의 이전 Apple 파일을 교체할 수 있습니다.

## 결론

- 돈을 내지 않고 오래 쓰려면 PWA가 가장 편합니다.
- 네이티브 IPA를 무료로 설치하면 7일마다 갱신해야 합니다.
- TestFlight 없이 갱신 부담을 줄인 네이티브 설치는 유료 Apple Developer Program과 등록 기기용 Ad Hoc 서명이 필요합니다.
