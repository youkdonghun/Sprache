# Sprache 1.22.3 검증 보고서

검증일: 2026-07-30

## 변경 범위

- 내장 단어 480개와 문장 240개 모두에 `hangul` 읽기 보조를 제공한다.
- 직접 작성한 읽기와 가져온 읽기를 우선 보존한다.
- 내장 콘텐츠의 누락 표기는 영어·일본어·독일어·프랑스어·스페인어·
  중국어별 오프라인 변환기로 생성한다.
- 일본어 가나·로마자와 중국어 병음은 기존대로 함께 보존한다.
- 설정과 편집 화면에서 한국어 표기는 보조이고 실제 소리는 듣기로
  확인해야 한다는 점을 안내한다.

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| `npm run analyze:client` | 이슈 0개 |
| `npm run test:client` | 358개 통과 |
| `npm run test:api` | 14개 통과 |
| `flutter test test/visual/ui_snapshot_test.dart` | 19개 통과 |
| `npm run verify:release` 재검증 | 통과 |

콘텐츠 테스트는 720개 모든 항목의 한국어 발음 존재, 라틴 문자와 잘못된
기호 잔존 방지, 명시 표기 우선 보존과 다음 여섯 대표 문장을 고정한다.

| 언어 | 원문 | 한국어 발음 |
| --- | --- | --- |
| 영어 | `Where is the station?` | `웨어 이즈 더 스테이션?` |
| 일본어 | `駅はどこですか。` | `에키 와 도코 데스 카` |
| 독일어 | `Wo ist der Bahnhof?` | `보 이스트 데어 반호프?` |
| 프랑스어 | `Où est la gare ?` | `우 에 라 가르?` |
| 스페인어 | `¿Dónde está la estación?` | `돈데 에스타 라 에스타시온?` |
| 중국어 간체 | `车站在哪里？` | `처 잔 자이 나 리` |

## Android 업그레이드·실화면

- 대상: Android Emulator API 36, `emulator-5554`
- 1.22.2 `versionCode=40` 위에 1.22.3 `versionCode=41`을 `adb install -r`로
  설치했다.
- `firstInstallTime`이 유지돼 신규 설치가 아니라 업그레이드임을 확인했다.
- 기존 영어 코스, 연속 학습 1일, 50 XP, 0/10 진행 중 세션과 연결 상태가
  유지됐다.
- 발음 화면에서 `Please give me water.`, `한국어 발음 플리즈 기브 미 워터.`,
  `물 좀 주세요.`가 함께 표시됐다.
- 앱 로그의 치명 예외·미처리 예외·RenderFlex overflow는 0개였다.
- 실화면 증빙:
  `artifacts/verification/android-1.22.3-pronunciation/pronunciation.png`

모바일 설정은 라이트·다크, 컴팩트 폭 골든을 갱신하고 발음 화면 골든을
함께 검증했다. 전체 시각 회귀 묶음은 19개를 통과했다. 반응형 위젯 검사는
320×640, 360×800, 375×812, 390×844, 412×915, 430×932에서 홈·학습·
코스·자료함·기록·설정·세션 구성을 순회하며 오버플로가 없음을 확인했다.

## Windows 실행

- `apps/client/build/windows/x64/runner/Release/sprache.exe`를 실행했다.
- 프로세스 ID 29736, 창 제목 `작업 보드`, `Responding=True`를 확인했다.
- 사용자가 테스트 중인 실행 창을 유지하기 위해 이번 검증에서는 설치본의
  설치→실행→제거 스모크를 다시 돌리지 않았다.

## 산출물

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.22.3-google-debug-signed.apk` | 77,812,817 | `2755F03021DF889D83F76C07063718173194A971D490FB028398D5A2AF68718F` |
| `Sprache-Windows-1.22.3-google-x64.zip` | 21,224,839 | `EAD24E63C4E83A596A459041176C82F985D3ABC3AEDD5EF1DFAD3381BB3FFFAA` |
| `Sprache-Windows-Setup-1.22.3-google-x64.exe` | 17,540,951 | `E6A65398ACB1F6AFC90E872A7A4573CDCDF38D9EF3FC1ED265E1DC9756328162` |

통합 검증에서 Android `arm64-v8a`, `armeabi-v7a`, `x86_64`, Windows ZIP
34개 항목, 체크섬 3개, 운영 API와 개인정보처리방침 포함을 확인했다.

바탕 화면에는 직접 설치 테스트용
`C:\Users\youk\Desktop\Sprache-Android-1.22.3.apk` 한 개만 유지했다.

## 공개 배포 전 남은 조건

- Android는 Debug 서명이다. Play release keystore와 Play App Signing
  인증서 지문이 필요하다.
- Windows 설치본은 Authenticode 무서명이다.
- Google 운영 브랜드 인증에는 소유권이 확인된 custom domain이 필요하다.
- 실제 Android 기기의 마이크·TTS·파일 선택기·알림·접근성 검증이 남아 있다.
- 자동 한국어 발음 보조표기는 여섯 언어 원어민과 한국어 화자의 최종 감수가
  필요하며 실제 음성의 기준은 앱의 TTS다.
