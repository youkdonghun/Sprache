# Sprache 1.19.2 검증 보고서

검증일: 2026-07-28

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| API 정적 검사·빌드 | TypeScript strict 검사와 빌드 통과 |
| Flutter 전체 테스트 | 246개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 시각 회귀 | Android·Windows 골든 21개 통과 |
| 두 기기 사용자 흐름 | 가져오기부터 두 번째 기기 복원까지 통과 |
| Android 빌드 | release APK 생성·업그레이드 설치·실행 성공 |
| Android 버전 | `1.19.2` (`versionCode` 24) |
| Android 서명 | APK Signature Scheme v2, Android Debug 서명자 1명 |
| Windows 빌드 | release ZIP·설치 EXE 생성, 설치된 앱 실행 12초 후 `Responding=True` |
| Windows 설치 수명주기 | 사용자 임시 경로 설치·실행·제거와 제거 레지스트리 정리 성공 |
| Railway 운영 API | 배포 성공, `/health` HTTP 200 |
| Desktop OAuth 중계 | 코드 배포 완료, sealed secret 미등록으로 `not_configured` |
| 운영 API 보안 경계 | malformed JSON 400, 미설정 중계 503, 인증 없는 Drive API 401 |
| 배포 API 주소 | Android 3개 ABI와 Windows 모두 Railway HTTPS, 로컬 개발 API 없음 |

## 1.19.2 Google·Railway 보완

- Windows Google 연결 진행을 Railway 준비 확인, 계정 동의, Drive 폴더 선택,
  저장 폴더 확인, 계정 연결, pull·merge·push 단계로 나눠 표시한다.
- Windows의 Google 공식 PKCE·동적 loopback callback은 유지한다. 공용 API만
  Railway HTTPS를 사용하며 Cloudflare Tunnel은 필요하지 않다.
- Google Desktop Client Secret은 EXE나 APK에 넣지 않고 Railway sealed
  variable에서만 읽는 무저장 토큰 중계를 추가했다.
- Railway는 authorization code, PKCE verifier, access token, refresh token,
  ID token을 PostgreSQL·파일·캐시에 저장하지 않으며 민감 필드를 로그에서
  가린다.
- 앱은 브라우저를 열기 전에 `/health`를 확인하고 중계 미설정·구버전·
  네트워크 장애를 구분해 해결 안내를 표시한다.
- `npm run check:google`은 비밀값을 읽지 않고 운영 API와 중계 준비 상태만
  점검하며, 실계정 E2E는 준비되지 않은 상태에서 브라우저를 열지 않는다.
- malformed OAuth JSON도 400과 `Cache-Control: no-store`,
  `Pragma: no-cache`로 제한하는 회귀 테스트를 추가했다.

## Android 산출물

- 파일: `artifacts/Sprache-Android-1.19.2-google-debug-signed.apk`
- 크기: 74,983,112 bytes
- SHA-256:
  `4ed98a31c1f545e9fc2dede50528e6ec1c374cccdd770644677e987a9a588b3a`
- 패키지: `com.youkdonghun.sprache`
- 최소 SDK: 24
- 대상 SDK: 36
- 서명 인증서 SHA-1:
  `ab6424d5fcba3f762c27c2be613d1aa9c84f1fae`
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

에뮬레이터에 `adb install -r`로 1.19.1 위에 설치했다. 최초 설치 시각은
유지됐고 시작 화면 뒤 홈까지 정상 진입했다. 기존 사용자 `야구 용어`
주제, 영어 1/10 진행 중 세션과 10 XP도 그대로 남았다. 실제 캡처는
`artifacts/Sprache-Android-1.19.2-home-ready.png`에 있다.

현재 APK는 직접 설치·기능 검증용 Android Debug 인증서 서명본이다.
Play 배포에는 release keystore, Play App Signing과 해당 SHA 지문으로 만든
Android OAuth 클라이언트가 필요하다.

## Windows 산출물

- 포터블 파일: `artifacts/Sprache-Windows-1.19.2-google-x64.zip`
- 크기: 20,798,668 bytes
- SHA-256:
  `0a1857f17b95a386690eee081e44d0980b17f32d07aa7b1a22e4e378a1d85ce2`
- ZIP 항목 수: 28
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.2-google-x64.exe`
- 설치 파일 크기: 17,264,877 bytes
- 설치 파일 SHA-256:
  `097253a5696be584bdd9ff92673756e4dd5041a53f5f97463d09ae7cf6ce6557`
- 설치 파일 제품 버전: `1.19.2`
- 설치된 `sprache.exe` 실행 12초 뒤 `HasExited=False`, `Responding=True`
- 생성된 창 제목: `작업 보드`

설치 EXE를 작업공간 아래 전용 사용자 경로에 조용히 설치한 뒤 앱 실행을
확인하고, 함께 설치된 `unins000.exe`로 제거했다. 설치와 제거 모두 exit code
0이었고 설치 폴더와 HKCU 제거 레지스트리 항목도 남지 않았다.

현재 설치 EXE는 Authenticode `NotSigned` 상태다. 내부 기능 검증에는 사용할
수 있지만 공개 배포 전에 Windows 코드 서명 인증서로 서명해야 SmartScreen
경고를 줄일 수 있다.

현재 검증 PC에서는 Microsoft Defender 서비스와 실시간 보호가 비활성화되어
있어 로컬 Defender 사용자 지정 검사는 실행할 수 없었다. 이는 악성 코드
탐지 결과가 아니라 검사 엔진 비활성 상태이며, 공개 배포 전 서명된 설치본을
활성화된 보안 제품과 배포 채널에서 다시 검사해야 한다.

세 산출물의 해시는
`artifacts/SHA256SUMS-1.19.2-google.txt`와 일치한다.

## 네트워크와 비밀값

Android의 `arm64-v8a`, `armeabi-v7a`, `x86_64` `libapp.so`와 Windows
`data/app.so`에서
`https://sprache-api-production.up.railway.app`과 앱 버전 `1.19.2`를
확인했다. 어느 배포 바이너리에도 개발 API
`http://127.0.0.1:3000`이나 Railway 비밀 변수 이름
`GOOGLE_DESKTOP_CLIENT_SECRET`은 없다.

`client_secret`이라는 일반 진단 문자열은 Google의 기존 400 응답을
분류하기 위해 포함되지만 실제 secret 값은 클라이언트 빌드 입력이나
바이너리에 전달하지 않는다.

Windows 로그인 중 사용하는 `http://127.0.0.1:<임의 포트>`는 Google
데스크톱 OAuth 응답을 같은 PC의 Sprache 프로세스로 돌려주는 일회성
loopback callback이다. 외부 서비스가 아니며 Cloudflare Tunnel로
공개하지 않는다.

## Railway 운영 배포

- 프로젝트: `Sprache`
- 서비스: `sprache-api`
- 환경: `production`
- 배포 ID: `279c468c-9f23-4153-857a-6c441a668dfb`
- 배포 상태: `SUCCESS`
- 이미지 digest:
  `sha256:d9c78c9f356142f838929e6051a4c58f090ef316835cdb0cbe9d2fb893852fa7`
- 공개 주소: `https://sprache-api-production.up.railway.app`
- 현재 health:
  `{"status":"ok","service":"sprache-api","desktopOAuthBroker":"not_configured"}`

운영 엔드포인트에서 다음을 재확인했다.

- malformed token JSON: HTTP 400, `no-store`, `no-cache`
- 올바른 형식의 token 요청: 중계 secret 미등록을 나타내는 HTTP 503
- 인증 없는 `/v1/me/drive-root`: HTTP 401

## 실계정 확인 상태

Windows 실계정 동의와 loopback authorization code 수신은 성공했다.
직접 Google token endpoint로 보내던 이전 방식은
`client_secret is missing` 400을 반환했다. 이는 callback이나 OAuth
클라이언트 유형 문제가 아니라 현재 Google Desktop credential의 토큰
교환 조건이며, secret을 앱에 넣지 않는 Railway 중계 방식으로 해결했다.

아직 Railway에 아래 두 값이 함께 등록되지 않아 실제 token exchange와
Drive Picker 왕복은 완료 검증하지 않았다.

- `GOOGLE_DESKTOP_CLIENT_ID`
- `GOOGLE_DESKTOP_CLIENT_SECRET`

## 남은 외부 검증

- Railway sealed variable 두 개 등록 후 `/health`가 `ready`인지 확인
- 실제 Google 계정으로 Windows 로그인·Drive 폴더 동의 완료
- 같은 계정으로 Android 실기기 로그인
- Windows에서 올린 snapshot을 실제 Drive를 거쳐 Android에서 복원
- 물리 Android 기기의 마이크·TTS·파일 선택기·오프라인 복귀
- Windows 설치 EXE Authenticode 코드 서명
- Play Store release signing과 App Signing OAuth 지문 등록
