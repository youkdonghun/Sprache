# Sprache 1.19.0 검증 보고서

검증일: 2026-07-28

## 결과 요약

| 검증 항목 | 결과 |
| --- | --- |
| API TypeScript lint·production build | 통과 |
| API Vitest | 4개 통과 |
| 저장소 표준 `npm test` | API 4개와 Flutter 234개 통과 |
| Flutter analyze | 이슈 0개 |
| Flutter 시각 회귀 | Android 라이트·다크와 Windows 화면 21개 통과 |
| 범용 주제 도메인·Drive snapshot | 주제 격리, 이동, 검증, 병합 테스트 통과 |
| Windows 범용 주제 UI | Windows 플랫폼에서 주제 생성·선택 위젯 테스트 통과 |
| Android 범용 주제 UI | 실제 APK에서 자료함→가져오기→야구 팩 13개 검토 진입 확인 |
| Android APK 빌드·서명 | 통과, APK Signature Scheme v2, 서명자 1명 |
| Android 설치·업그레이드 | 에뮬레이터에 `-r` 설치, 버전 22 실행 성공 |
| Android 로컬 연속성 | 기존 1/10 세션·정답 1개·10 XP 보존 확인 |
| Windows release | ZIP 빌드 후 `sprache.exe`가 8초 이상 응답 상태 유지 |
| Windows·Android 번들 자산 | Excel 템플릿, Tatoeba·야구·아이돌 팩 포함 확인 |
| Railway 운영 API | `/health`가 `{"status":"ok","service":"sprache-api"}`로 응답 |

## 구현 범위

- 영어·일본어·독일어·프랑스어·스페인어·중국어 코스와 별개로 사용자 학습
  주제를 생성하고 수정한다.
- 일반 주제의 개념·사실·문장·예문을 주제별로 격리하고 여러 항목을 다른
  주제로 한 번에 이동한다.
- 주제 안에서 학습 그룹, 카드 암기, 퀴즈, 직접 선택 세션, 다음 학습 일정을
  Android와 Windows 공통으로 사용한다.
- Excel·CSV·JSON·JSONL의 `subject_id`를 읽고, 값이 없으면 현재 선택한
  일반 주제를 기본값으로 사용한다.
- 동일 주제의 같은 표현은 새 항목을 무조건 만들지 않고 기존 뜻·허용
  정답·예문·그룹을 보존하면서 병합 검토한다.
- `customSubjects`와 `activeSubjectId`를 로컬 snapshot과 Google Drive 병합
  범위에 포함한다. 손상되거나 중복된 원격 주제는 정상 로컬 데이터를
  바꾸기 전에 거부한다.

## Android 산출물

- 파일: `artifacts/Sprache-Android-1.19.0-google-debug-signed.apk`
- 크기: 74,966,728 bytes
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.19.0` (`versionCode` 22)
- 최소 SDK: 24
- 대상 SDK: 36
- SHA-256: `f60cbf50e22aa00c764106502ac92376995d28a10b5d4c71401e7c75c3e4a4f2`
- 서명: APK Signature Scheme v2, Android Debug 인증서
- 서명 인증서 SHA-1: `ab6424d5fcba3f762c27c2be613d1aa9c84f1fae`
- 서명 인증서 SHA-256: `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

첫 업그레이드 실행은 에뮬레이터의 프로필 설치와 기존 데이터 초기화까지
16.645초가 걸렸다. 이후 강제 종료 뒤 측정한 cold start는 5.073초였다.
두 번째 화면에서 기존 학습 상태와 전체 홈 UI가 정상 표시됐다.

현재 APK는 직접 설치와 기능 검증을 위한 Android Debug 인증서 서명본이다.
Play 배포에는 release keystore, Play App Signing, 해당 SHA 지문으로 만든
Android OAuth 클라이언트가 필요하다.

## Windows 산출물

- 파일: `artifacts/Sprache-Windows-1.19.0-google-x64.zip`
- 크기: 20,788,380 bytes
- SHA-256: `60c43be856d1b7387b91f032bcd46c576729340e32e059fca211f636fbb324f8`
- ZIP 항목 수: 28
- `sprache.exe`를 release 디렉터리에서 실행해 8초 뒤 `Responding=True`를
  확인하고 테스트 프로세스를 종료했다.

두 산출물의 체크섬은
`artifacts/SHA256SUMS-1.19.0-google.txt`와 일치한다.

## 범용 가져오기 자산

- 앱 내 Excel: `apps/client/assets/templates/Sprache-word-import-template.xlsx`
- 배포용 Excel:
  `outputs/019fa272-bb6b-7973-a7e3-3ab21c2e02a3/Sprache-study-import-template.xlsx`
- 새 필드: `subject_id`
- 야구 팩: 8개 원본 행, 예문을 포함해 검토 화면에서 13개 신규 항목
- 아이돌·팬덤 팩: 8개 원본 행, 예문을 포함해 15개 학습 항목
- 출처·이용 조건: `ATTRIBUTIONS.md` 및 각 JSON 항목의 `source_url`,
  `license`, `attribution`에 기록

Excel 파일은 수식 오류 0개를 확인했고 두 워크시트를 이미지로 렌더링해
제목, 헤더, 예시 행, 작성 안내의 가독성을 검수했다.

## 운영 주소와 loopback 주소

실제 Android·Windows 산출물의 `API_BASE_URL`은 로컬 주소가 아니라
`https://sprache-api-production.up.railway.app`이다. 따라서 두 앱은 같은
Railway API에 접근하며 이 용도로 Cloudflare가 필수는 아니다.

Windows 로그인 중 잠깐 열리는 `http://127.0.0.1:<임의 포트>`는 서버 API
주소가 아니다. Google이 인증 코드를 현재 Windows 앱으로 돌려주는 OAuth
loopback 콜백이며, 앱이 로그인 동안에만 로컬 소켓을 열고 완료 후 닫는다.
외부 기기가 이 주소에 접속할 필요가 없으므로 Cloudflare Tunnel로 공개하면
안 된다.

학습 자료와 상세 진도는 Railway PostgreSQL에 저장하지 않는다. Railway는
검증된 Google 계정의 HMAC `account_key`와 Drive 폴더 ID 연결만 저장하고,
실제 사용자 콘텐츠는 로컬 SQLite와 사용자가 선택한 Google Drive 파일에
보관한다.

## 실제 화면 검증 증거

- `artifacts/Sprache-Android-1.19.0-home-after.png`
- `artifacts/Sprache-Android-1.19.0-library.png`
- `artifacts/Sprache-Android-1.19.0-import.png`
- `artifacts/Sprache-Android-1.19.0-baseball-review-details.png`
- `artifacts/Sprache-Android-1.19.0-general-topic-readable.png`

## 남은 외부 검증

- 실제 Google 계정으로 Windows 로그인·Drive 폴더 동의 완료
- 같은 실제 계정으로 Android 로그인 완료
- Windows에서 저장한 일반 주제를 Drive에 올린 뒤 Android에서 복원하는
  양방향 실계정 동기화
- 물리 Android 기기의 마이크·TTS·파일 선택기·오프라인 복귀
- Play Store용 release signing과 App Signing OAuth 지문 등록

Google/Drive 실계정 검증은 사용자가 Google 로그인과 동의 화면을 완료해야
하므로 자동 테스트만으로 완료 판정하지 않았다. 앱 내부 OAuth는 동적
loopback, PKCE, `state` 검증, 토큰 교환, 안전 저장까지 로컬 종단 테스트로
검증됐다.

2026-07-28 22:03 KST에 Windows 실계정 E2E를 실제 실행했다. Chrome 인증
화면의 callback이 5분 안에 돌아오지 않아 `NETWORK-TIMEOUT`으로 종료됐고,
진단에는 `로컬 데이터: 유지됨`이 기록됐다. 이전의 token exchange 400은
이번 실행에서 재현되지 않았지만, 동의 완료와 Drive 업로드 성공도 확인되지
않았으므로 실계정 연결 완료로 판정하지 않는다.

## 향후 호환성 주의

현재 Flutter 빌드는 성공했지만 Flutter는 앱과 일부 플러그인이 적용하는
기존 Kotlin Gradle Plugin 방식이 미래 버전에서 제거될 예정이라고 경고했다.
다음 Flutter 메이저 업그레이드 전에 Built-in Kotlin을 지원하는 플러그인
버전을 확인하고 Android Gradle 구성을 마이그레이션해야 한다.
