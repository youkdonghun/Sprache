# Sprache 1.19.3 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| API 정적 검사·빌드 | TypeScript strict 검사와 빌드 통과 |
| OpenAPI | 유효, 권장 규칙 경고 2개(license·health 4XX) |
| Flutter 전체 테스트 | 306개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| 두 기기 사용자 흐름 | 가져오기부터 복원, 45일 오프라인 분기·재연결 순서 역전·업로드 중단 재시도까지 통과 |
| 개인정보 안내 | 설정 화면 상세 안내·반응형 HTML 2개·공식 Limited Use 링크 확인 |
| Android 빌드 | release APK 생성·업그레이드 설치·실행 성공 |
| Android 버전 | `1.19.3` (`versionCode` 25) |
| Android 서명 | APK Signature Scheme v2, Android Debug 서명자 1명 |
| Windows 빌드 | release ZIP·설치 EXE 생성, 직접·설치본 모두 `Responding=True` |
| Windows 설치 수명주기 | 사용자 임시 경로 설치·실행·제거와 제거 레지스트리 정리 성공 |
| Railway 운영 API | `/health` HTTP 200 |
| Desktop OAuth 중계 | 코드 배포 완료, sealed secret 미등록으로 `not_configured` |
| 배포 API 주소 | Android 3개 ABI와 Windows 모두 Railway HTTPS, 로컬 개발 API 없음 |
| 릴리스 도구 자체 검사 | PowerShell 문법·JSON·Git whitespace·Markdown 상대 링크 통과 |
| 비밀값 패턴 검사 | 빌드·산출물 제외 소스에서 실제 키 형식 0건 |

## 1.19.3 개인정보·배포 보완

- 설정 화면에서 Drive 접근 범위, Railway 저장 범위, 로그인 토큰 보관,
  음성 인식, 공유·판매 여부와 사용자의 삭제 선택을 한 번에 확인한다.
- 앱 홈페이지와 개인정보처리방침을 로그인 없이 읽을 수 있는 별도 반응형
  HTML로 만들고, 한국어 전문과 영어 요약을 제공한다.
- Google 기본 계정 정보, `drive.file`, 기기 로컬 데이터, Railway HMAC 계정
  키·폴더 연결, 플랫폼 음성 인식의 실제 처리 위치를 코드와 DB 스키마에
  맞춰 구분했다.
- 실제 공개 URL은 소유권 확인 도메인이 정해진 뒤 `PRIVACY_POLICY_URL`로
  Android와 Windows에 동일하게 반영한다. 현재 산출물에는 앱 내 전체 안내가
  포함되며 가짜 공개 URL은 넣지 않았다.
- Inno Setup 설치 EXE를 포터블 ZIP과 함께 생성하고 설치·실행·제거를
  자동화했다.
- Windows와 Android가 오프라인에서 동시에 얻은 XP를 설치별 증가 전용
  카운터로 합치고, 구버전 총 XP도 보존하는 migration을 추가했다.
- 같은 날짜·코스의 오늘 XP도 설치별로 합산하고, 뒤늦게 들어온 과거 학습
  기록이 오늘 XP·연속 학습일·마지막 학습일을 과거로 되돌리지 않게 했다.
- 즐겨찾기 해제·학습 제외 취소의 변경 시각과 저장 일정 삭제 tombstone을
  동기화해 오래된 기기의 설정이 다시 살아나지 않게 했다.
- 활성 주제와 주제별 일일 목표의 변경 시각을 보존해 재연결 순서와 무관하게
  같은 결과로 수렴하도록 했다.

## 1.19.3 웹 예문·가져오기 UI 보완

- Tatoeba 공식 API에서 원문과 직접 연결된 승인 상태 한국어 번역을 다시
  확인해 출퇴근·학습 예문 12개를 추가했다.
- 기초 12개와 새 실용 12개를 Android·Windows 공통 가져오기 화면에서
  따로 열고 항목별 검토 후 저장한다.
- 두 팩 24개의 ID·언어별 표현 중복, 출처·작성자·라이선스, 일본어
  가나/로마자, 중국어 간체/병음, 문장 토큰과 재가져오기 동작을 테스트한다.
- `npm run check:tatoeba`로 두 팩 24개 모두의 현재 승인·비고아·직접
  한국어 번역 연결과 작성자·라이선스를 공식 API에서 재검증했다.
- NFKC가 일본어 전각 물음표를 ASCII 물음표로 바꾼 뒤 가나 읽기를 잘못
  거부하던 검증기 결함을 수정했다.
- 가져오기 소스 선택 화면을 375·390·412·430px에서 검사하고 390×844
  라이트·다크와 1280×900 Windows 골든을 직접 확인했다.

## Android 산출물

- 파일: `artifacts/Sprache-Android-1.19.3-google-debug-signed.apk`
- 크기: 76,149,218 bytes
- SHA-256:
  `3971af42f64ad8e065e1fe6e64a73cf993e91ab7c36289e835dbadaee04c3cec`
- 패키지: `com.youkdonghun.sprache`
- 최소 SDK: 24
- 대상 SDK: 36
- 서명 인증서 SHA-1:
  `ab6424d5fcba3f762c27c2be613d1aa9c84f1fae`
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

에뮬레이터에 `adb install -r`로 1.19.2 위에 설치했다. 최초 설치 시각은
유지됐고 시작 화면 뒤 홈까지 정상 진입했다. 기존 사용자 `야구 용어`
주제, 영어 1/10 진행 중 세션과 10 XP도 그대로 남았다. 실제 캡처는
`artifacts/Sprache-Android-1.19.3-home-ready.png`에 있다.

현재 APK는 직접 설치·기능 검증용 Android Debug 인증서 서명본이다.
Play 배포에는 release keystore, Play App Signing과 해당 SHA 지문으로 만든
Android OAuth 클라이언트가 필요하다.

## Windows 산출물

- 포터블 파일: `artifacts/Sprache-Windows-1.19.3-google-x64.zip`
- 크기: 20,943,242 bytes
- SHA-256:
  `6d9bd932b9c2723924a8ffa3164b8678d54a6e06bcb5061fd3390c497f046aff`
- ZIP 항목 수: 29
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.3-google-x64.exe`
- 설치 파일 크기: 17,366,063 bytes
- 설치 파일 SHA-256:
  `d8a9a3813a8f1e813d61585f6759fafb7b8970d4aabfa783b39c907c1285578e`
- 설치 파일 제품 버전: `1.19.3`
- 앱 파일 버전: `1.19.3+25`
- 생성된 창 제목: `작업 보드`

설치 EXE를 작업공간 아래 전용 사용자 경로에 조용히 설치한 뒤 앱 실행을
확인하고, 함께 설치된 `unins000.exe`로 제거했다. 설치와 제거 모두 exit code
0이었고 앱은 `Responding=True`였으며 설치 폴더와 HKCU 제거 레지스트리
항목도 남지 않았다.

현재 설치 EXE는 Authenticode `NotSigned` 상태다. 내부 기능 검증에는 사용할
수 있지만 공개 배포 전에 Windows 코드 서명 인증서로 서명해야 SmartScreen
경고를 줄일 수 있다.

현재 검증 PC에서는 Microsoft Defender 서비스와 실시간 보호가 비활성화되어
있어 로컬 Defender 사용자 지정 검사는 실행할 수 없었다. 이는 악성 코드
탐지 결과가 아니라 검사 엔진 비활성 상태다.

세 산출물의 해시는
`artifacts/SHA256SUMS-1.19.3-google.txt`와 모두 일치한다.
새 실용 예문 JSON은 APK와 Windows ZIP 안의 사본이 저장소 원본과 정확히
일치하는 것도 확인했다.

## 후속 배포 게이트 검증

1.19.3 산출물을 유지한 채 정식 배포용 서명 파이프라인을 추가 검증했다.

- Android keystore 경로·keystore 비밀번호·alias·key 비밀번호 네 값이 모두
  있을 때만 정식 서명을 사용한다.
- 일부 Android 서명 값만 입력한 경우 누락 변수 이름을 표시하고 빌드 전에
  차단한다.
- Windows는 `CurrentUser\My` 코드서명 인증서와 Windows SDK SignTool을
  사용하고 SHA-256·HTTPS RFC 3161 타임스탬프를 강제한다.
- 인증서가 없는 상태에서 정식 Android 서명 또는 Windows Authenticode를
  요구하면 각각 기존 Debug APK와 무서명 EXE를 정확히 거부한다.
- `npm run verify:release`로 체크섬 3개, Android 3개 ABI, Windows AOT
  바이너리, ZIP 29개 항목과 설치 파일 버전을 통합 확인했다.
- 변경된 Gradle 구성으로 Production APK 전체 빌드에 성공했고 결과 해시는
  기존 검증 APK와 동일했다.
- 별도 임시 경로에서 설치 EXE를 다시 생성하고 설치·실행·제거한 뒤 임시
  산출물과 HKCU 등록 흔적을 정리했다.

## 네트워크와 비밀값

Android의 `arm64-v8a`, `armeabi-v7a`, `x86_64` `libapp.so`와 Windows
`data/app.so`에서 운영 Railway URL과 앱 버전 `1.19.3`을 확인했다.
어느 배포 바이너리에도 개발 API `http://127.0.0.1:3000`이나 Railway
비밀 변수 이름 `GOOGLE_DESKTOP_CLIENT_SECRET`은 없다.

`client_secret`이라는 일반 진단 문자열은 Google의 기존 400 응답을
분류하기 위해 포함되지만 실제 secret 값은 클라이언트 빌드 입력이나
바이너리에 전달하지 않는다.

Windows 로그인 중 사용하는 `http://127.0.0.1:<임의 포트>`는 Google
데스크톱 OAuth 응답을 같은 PC의 Sprache 프로세스로 돌려주는 일회성
loopback callback이다. 외부 서비스가 아니며 Cloudflare Tunnel로
공개하지 않는다.

## Railway 운영 상태

- 프로젝트: `Sprache`
- 서비스: `sprache-api`
- 환경: `production`
- 공개 주소: `https://sprache-api-production.up.railway.app`
- 현재 health:
  `{"status":"ok","service":"sprache-api","desktopOAuthBroker":"not_configured"}`

운영 API는 정상이나 아직 Railway에 아래 두 값이 함께 등록되지 않아 실제
Windows token exchange와 Drive Picker 왕복은 완료 검증하지 않았다.

- `GOOGLE_DESKTOP_CLIENT_ID`
- `GOOGLE_DESKTOP_CLIENT_SECRET`

## Google Auth Platform 상태

Google Cloud Console에서 다음을 읽기 전용으로 재확인했다.

- Desktop, Web audience, Android Debug OAuth 클라이언트 3개가 존재한다.
- Android Debug의 패키지와 SHA-1은 현재 APK와 일치한다.
- 외부 사용자 유형·테스트 게시 상태이며 테스트 사용자는 1명이다.
- `openid`, `userinfo.email`, `userinfo.profile`, `drive.file`만 등록되어
  있고 민감 범위와 제한된 범위는 없다.
- 앱 이름·지원 이메일·개발자 연락처는 설정되어 있다.
- 홈페이지·개인정보처리방침·승인 도메인은 아직 비어 있다.
- Google 프로젝트 진단은 Android Debug 앱 소유권 미확인을 표시한다.
  Play 배포 시 Play App Signing SHA-1 클라이언트를 별도로 만들고 소유권을
  확인해야 한다.

## 남은 외부 검증

- Railway sealed variable 두 개 등록 후 `/health`가 `ready`인지 확인
- 소유권 확인 도메인에 앱 홈페이지·개인정보처리방침을 공개하고 OAuth URL 등록
- 실제 Google 계정으로 Windows 로그인·Drive 폴더 동의 완료
- 같은 계정으로 Android 실기기 로그인
- Windows에서 올린 snapshot을 실제 Drive를 거쳐 Android에서 복원
- 물리 Android 기기의 마이크·TTS·파일 선택기·오프라인 복귀
- Windows 설치 EXE Authenticode 코드 서명
- Play Store release signing과 App Signing OAuth 지문 등록
