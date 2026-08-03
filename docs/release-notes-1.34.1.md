# Sprache 1.34.1 릴리스 안내

버전은 `1.34.1+59`다. 이 버전은 1.34.0 산출물의 Google OAuth 구성을 네
플랫폼에서 다시 감사한 결과를 반영한다. 산출물 해시와 실제 실행 결과는 새
빌드가 끝난 뒤 `release-manifest-1.34.1.json`으로 봉인하기 전까지 완료로
표시하지 않는다.

## Google 연결 수정

- Windows Desktop Client ID를
  `1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com`으로
  교체했다.
- Windows REAL 빌드와 실계정 E2E는
  `SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET` 환경값이 없으면 컴파일 전에 중단한다.
  스크립트는 값 자체를 파일, manifest나 로그에 출력하지 않는다.
- Android APK의 실제 Debug 인증서 SHA-1
  `EF:1E:2A:C5:22:FC:BF:65:53:DC:35:35:0E:36:04:4F:F3:BC:F3:E2`를
  기존 Android OAuth client에 등록하고 패키지
  `com.youkdonghun.sprache`와 함께 재조회했다.
- iOS·macOS는 공용 iOS-type Client ID
  `1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com`과
  플랫폼 callback scheme을 사용한다.

## 산출물 표시

| 플랫폼 | 예정 파일 | 검증 의미 |
| --- | --- | --- |
| Windows | `Sprache-Windows-Setup-1.34.1-google-x64.exe` | REAL 빌드·설치·첫 프레임. 실계정 OAuth는 별도 E2E 결과로 판정 |
| Android | `Sprache-Android-1.34.1-google-debug-signed.apk` | REAL 설정·패키지·서명·ABI의 BUILD_ONLY. 실제 기기 로그인은 별도 판정 |
| iOS | `Sprache-iOS-Simulator-1.34.1-google-configured.zip` | REAL 설정·Simulator 첫 프레임. IPA가 아니며 실계정 OAuth 미검증 |
| macOS | `Sprache-macOS-1.34.1-google-configured.zip` | REAL 설정·ad-hoc 앱 첫 프레임. 비공증이며 실계정 OAuth 미검증 |

Apple configured preview의 `REAL`은 실제 Client ID, callback metadata와 비 Mock
서비스 구성이 들어갔다는 뜻이다. 사용자 계정 선택, OAuth token 발급이나 Drive
동기화가 자동 검증됐다는 뜻은 아니다. evidence에는
`googleOAuthConfigured=true`, `googleOAuthRuntimeVerified=false`와 서명 제한을
함께 기록한다.

## 배포 전 남은 실제 검증

- Windows에서 새 Client ID·credential로 계정 선택, 권한 동의, token refresh와
  `WordStudyData` 선택·재연결을 완료한다.
- Android 실기기에서 등록된 package·SHA 조합으로 계정 선택과 Drive 권한을
  완료한다.
- iOS 실기기와 배포용 macOS 앱은 Apple Developer 서명 자산을 준비한 뒤 별도
  실계정 OAuth·Drive 왕복을 검증한다.
- 네 플랫폼 새 산출물과 evidence를 모아
  `packaging/release-bundle-spec-1.34.1.json`으로 manifest를 만든다.
