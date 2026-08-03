# Sprache 1.18.1 검증 보고서

검증일: 2026-07-28

## 결과 요약

| 검증 항목 | 결과 |
| --- | --- |
| API TypeScript lint | 통과 |
| API Vitest | 4개 통과 |
| API production build | 통과 |
| 저장소 표준 `npm test` | API 4개와 Flutter 218개 연속 통과 |
| Flutter analyze | 이슈 0개 |
| Flutter 전체 테스트 | 218개 통과 |
| Android APK 빌드·서명 | 통과, APK Signature Scheme v2, 서명자 1명 |
| Android 설치·업그레이드 | 에뮬레이터에서 1.18.0 → 1.18.1 업그레이드 성공 |
| Android 로컬 연속성 | 앱 재시작과 업그레이드 뒤에도 1/10 세션·정답 1개·10 XP 보존 |
| Android Google 인증 진입 | `Google 연결`에서 Google Play Services 공식 계정 설정 화면 호출 확인 |
| Windows OAuth 종단 검증 | 동적 loopback·PKCE·state·콜백·토큰 교환·메모리 vault 저장 통과 |
| 웹 예문 가져오기 | 12개 신규 검토·가져오기, 6개 언어 그룹 생성 성공 |
| 웹 예문 출처 표시 | 원문·번역 ID, 작성자, 라이선스, attribution, 원문 링크 표시 확인 |
| Windows release | ZIP 빌드 후 `sprache.exe` 8초 이상 정상 응답 |
| Windows 번들 자산 | Excel 템플릿과 Tatoeba JSON 포함 확인 |
| Railway 운영 API | `https://sprache-api-production.up.railway.app/health` 정상 |

## Android 산출물

- 파일: `artifacts/Sprache-Android-1.18.1-google-debug-signed.apk`
- 크기: 74,764,497 bytes
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.18.1` (`versionCode` 21)
- 최소 SDK: 24
- 대상 SDK: 36
- SHA-256: `1f8565085fa860630d05ea42846e20c013d091ef902547af77b534fa91a46f40`
- 서명 인증서 SHA-1: `ab6424d5fcba3f762c27c2be613d1aa9c84f1fae`
- 서명 인증서 SHA-256: `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

현재 파일은 직접 설치와 기능 검증을 위한 Android Debug 인증서 서명본이다.
Play 배포에는 release keystore와 Play App Signing 지문에 맞춘 Android OAuth
클라이언트가 필요하다.

## Windows 산출물

- 파일: `artifacts/Sprache-Windows-1.18.1-google-x64.zip`
- 크기: 20,754,572 bytes
- SHA-256: `6d38c1f47b38cafb4a8c9d2c613ac1b90893f37eee47aaf874a45f5c4a1bcc89`
- release 디렉터리의 `sprache.exe`를 실행해 프로세스 응답 상태를 확인하고 종료했다.
- ZIP의 `data/flutter_assets`에 Excel 템플릿과 웹 예문 팩이 포함되어 있다.

두 산출물의 체크섬은 `artifacts/SHA256SUMS-1.18.1-google.txt`와 일치한다.

## 검증된 웹 예문 팩

- 자산: `apps/client/assets/content/tatoeba-korean-sentence-pack-2026-07-28.json`
- 범위: 영어·일본어·독일어·프랑스어·스페인어·중국어 간체, 언어별 2문장
- 이용 조건: Tatoeba 문장별 CC BY 2.0 FR
- 보존 정보: 원문·한국어 번역 문장 ID, 두 작성자, 원문 URL, 라이선스 URL,
  attribution, 출처일, 콘텐츠 버전
- 앱 동작: 저장 전 12개 항목을 개별 검토하고 사용자가 가져오기를 확정한다.
- 중복 방지: 동일 팩 재가져오기 시 신규 항목을 만들지 않고 12개를 건너뛴다.

## Excel 템플릿

`Sprache-word-import-template.xlsx`는 기존 단어·문장·예문·그룹 필드에 다음
출처 필드를 추가했다.

- `source_version`
- `source_id`
- `source_url`
- `author`
- `attribution`
- `content_version`
- `id`

앱 자산과 `outputs` 배포본을 각각 생성했으며 두 워크시트를 렌더링해 헤더,
예시 행, 작성 안내의 가독성을 확인했다.

## 실제 화면 검증 증거

- `artifacts/Sprache-Android-1.18.0-upgrade.png`
- `artifacts/Sprache-Android-1.18.0-web-pack-review.png`
- `artifacts/Sprache-Android-1.18.0-web-pack-commit.png`
- `artifacts/Sprache-Android-1.18.0-web-pack-imported.png`
- `artifacts/Sprache-Android-1.18.0-web-source-detail.png`
- `artifacts/Sprache-Android-1.18.0-google-account-chooser-after.png`
- `artifacts/Sprache-Android-1.18.1-upgrade.png`

## 아직 완료로 판정하지 않은 항목

- 실제 Google 계정의 Windows 로그인과 Drive 폴더 선택
- 실제 Google 계정의 Android 로그인과 동의 완료
- Windows에서 저장한 변경을 Drive로 올린 뒤 Android에서 복원하는 양방향 연속성
- 물리 Android 기기의 마이크·TTS·파일 선택기·오프라인 복귀
- Play Store용 release signing과 App Signing OAuth 지문 등록

따라서 앱의 로컬 학습, 가져오기, 출처 보존, Android 설치·업그레이드,
Windows 실행, Railway 연결은 검증됐지만 Google/Drive 실계정 기기 간
동기화는 사용자 로그인과 동의를 받아 별도로 확인해야 한다.
