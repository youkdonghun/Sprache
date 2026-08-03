# Sprache 1.20.1 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 330개 통과 |
| 시각 회귀 | Android·Windows 골든 이미지 44개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 모바일 반응형 | 가져오기 화면 375·390·412·430px 통과 |
| Excel 자체 검증 | 간편 템플릿 2개 시트 렌더링, 15열·10개 예시 행, 수식 오류 0개 |
| Excel 파서 | 7개 언어 코드, 단어·독립 문장 15개, 중복 뜻·그룹·예문 토큰 검증 |
| 학습·동기화 E2E | 실제 `.xlsx`부터 두 번째 기기 결과 복원까지 통과 |
| Google·Railway 준비도 | `ApiHealthy=True`, `desktopOAuthBroker=ready`, `WindowsGoogleLoginReady=True` |
| Android 업그레이드 실측 | 에뮬레이터에서 1.20.0→1.20.1 덮어쓰기, 설치 시각·학습 자료·XP·중단 세션·Drive 연결 유지 |
| Android 실제 Excel 동작 | Downloads 파일 선택 시 15개 신규·오류 0개, 앱에서 저장한 간편 템플릿 SHA-256 원본 일치 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거 통과 |
| 릴리스 통합 검증 | 체크섬 3개, APK v2 서명, ABI 3개, Windows AOT·ZIP 34개 항목 통과 |

## 간편 Excel 템플릿

기존 전체 템플릿은 읽기 보조, 여러 예문, 출처, 라이선스와 안정적 ID까지
다루는 33열 구조라 첫 사용자에게 부담이 컸다. 전체 템플릿은 유지하고,
일상 등록에 필요한 15열만 남긴 다음 파일을 추가했다.

- 앱 자산: `apps/client/assets/templates/Sprache-easy-import-template.xlsx`
- 사용자 전달본:
  `outputs/sprache-workflow-e2e-1.20.1/Sprache-easy-import-template.xlsx`
- 크기: 8,152 bytes
- SHA-256:
  `cb62bf0a852d3f3063b0850da167c3c9a46a03eb9f28640f8a7148365ac123f3`
- 시트: `간편 업로드`, `작성 안내`
- 필수 열: `language`, `type`, `term`, `meaning`
- 선택 열: 그룹, 품사, 추가 정답, 예문·번역·토큰, 문장 토큰, 태그,
  레벨, 우선순위, 주제 ID

영어·일본어·독일어·프랑스어·스페인어·중국어 간체와 일반 학습용 한국어
예시를 넣었다. `reservation`과 `OPS`를 여러 행에 배치해 같은 표현·품사의
뜻·그룹이 합쳐지는 규칙을 파일 안에서 바로 확인할 수 있다.

Android·Windows의 가져오기 카드에는 다음 동작을 분리했다.

- `간편 템플릿`: 처음 등록하거나 일반적인 단어·문장을 올릴 때 사용
- `전체 템플릿`: 여러 예문, kana·romaji·pinyin, 출처·라이선스·ID 관리

모바일에서는 세 버튼을 `Wrap`으로 내려 배치하고, Windows 넓은 화면에서는
파일 요약과 동작을 가로로 유지한다.

## 실제 파일 기반 전체 흐름

테스트는 CSV 문자열이나 임의 객체가 아니라 앱에 포함되는 실제 간편
`.xlsx` 바이트에서 시작한다.

1. Excel의 15개 단어·문장 항목을 파싱한다.
2. `OPS`의 두 뜻과 `타격 지표`·`이번 주 암기` 그룹을 한 단어에 병합한다.
3. `OPS가 0.900을 넘었다.`를 독립 문장과 배열·빈칸 가능 항목으로 만든다.
4. 단어와 문장을 `Android에서 복습` 그룹에 복사한다.
5. 두 항목만 고른 혼합 학습 일정 `퇴근 후 야구 복습`을 저장한다.
6. 단어 정답, 문장 오답, 진행도, XP와 완료 세션을 기록한다.
7. Windows 역할의 첫 컨트롤러가 snapshot을 업로드한다.
8. Android 역할의 두 번째 컨트롤러가 내려받아 병합한다.
9. 뜻·그룹·정오답·XP·최근 세션·오답 ID·저장 일정과 정확한 선택 항목을
   모두 복원했는지 확인한다.

이 검증의 기기 간 전송 계층은 결정적인 메모리 Drive 대역을 사용한다.
Google 실계정 Windows↔Android 에뮬레이터 경로는 1.19.9~1.20.0에서 별도로
통과했으며, 이번 배치에서는 운영 Railway 준비 상태를 다시 확인했다.

## Android 에뮬레이터 실제 업그레이드·파일 동작

Android API 36 에뮬레이터의 기존 1.20.0(`versionCode` 32) 위에
1.20.1(`versionCode` 33) APK를 `adb install -r`로 설치했다.

- `firstInstallTime`: `2026-07-29 00:46:20`으로 설치 전후 동일
- 사용자 주제 `기기 간 동기화`, 사용자 항목 1개와 계정 XP 50 유지
- 일시정지한 학습 세션 2/10과 정답 2·오답 0 상태 유지
- 저장된 Google 계정과 Drive `WordStudyData` 연결이 입력 없이 복원됨
- 마지막 동기화 결과 `↑ 0 · ↓ 0 · 검토 1` 확인

실제 간편 Excel을 Android `Downloads`에 넣고 시스템 파일 선택기에서
선택했다. 앱의 검토 화면은 `15 신규`, `0 변경`, `0 동일`, `0 차단`,
`0 행 오류`를 표시했고 단어·독립 문장·일본어 항목 카드까지 렌더링했다.
연결된 개발용 Drive 데이터에 템플릿 예시 15개를 섞지 않기 위해 실제
저장 버튼은 누르지 않았다. 저장·동기화 이후 상태 변화는 위의 실제
`.xlsx` 기반 자동 E2E에서 별도로 검증한다.

반대 방향도 확인했다. 앱의 `간편 템플릿` 버튼으로 Android 시스템
`CREATE_DOCUMENT` 저장창을 열고 `Downloads/Sprache-easy-import-template.xlsx`
를 저장한 뒤 다시 가져왔다.

- Android 저장 파일 크기: 8,152 bytes
- Android 저장 파일 SHA-256:
  `cb62bf0a852d3f3063b0850da167c3c9a46a03eb9f28640f8a7148365ac123f3`
- 앱 자산 SHA-256과 일치
- 실행 중 앱 PID 로그 46줄에서 치명 예외·미처리 예외·RenderFlex
  overflow 일치 항목 0개
- Android crash buffer에서 앱 관련 항목 0개

실측 화면은 다음 경로에 보존했다.

- 업데이트 후 홈:
  `artifacts/verification/android-1.20.1-resumed.png`
- 복원된 Drive 설정:
  `artifacts/verification/android-1.20.1-settings-restored.png`
- 실제 파일 가져오기 결과:
  `artifacts/verification/android-1.20.1-import-review-counts.png`
- Android 템플릿 저장창:
  `artifacts/verification/android-1.20.1-template-save-picker.png`
- 템플릿 저장 완료:
  `artifacts/verification/android-1.20.1-template-save-result.png`

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.20.1-google-debug-signed.apk`
- 크기: 77,434,873 bytes
- SHA-256:
  `544e02ee6fedabb1a98ecb2a7e7c47bee720c358a5d035f054d750dab01ec5ee`
- 버전: `1.20.1` (`versionCode` 33)
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서

### Windows

- 포터블: `artifacts/Sprache-Windows-1.20.1-google-x64.zip`
- 크기: 21,154,689 bytes
- SHA-256:
  `15c780a8f77b6eb641ad5e8eee5f859b065446838998b159ec6cc27959153750`
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.20.1-google-x64.exe`
- 설치 파일 크기: 17,491,459 bytes
- 설치 파일 SHA-256:
  `2e18a87de175d91c7dfaad5dcacbfa4b7ca454961b71d0d8ed6c26c423f161c5`
- 앱 버전: `1.20.1+33`
- 설치 실행: exit code 0, `작업 보드`, `Responding=True`
- 제거: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개
- Authenticode: `NotSigned`

Android APK와 Windows ZIP에 간편·전체 Excel 템플릿 두 파일이 모두 들어
있음을 archive entry로 재확인했다. 세 산출물의 해시는
`artifacts/SHA256SUMS-1.20.1-google.txt`와 일치한다.

## 공개 배포 전에 남은 작업

- Android 물리 기기에서 에뮬레이터로 통과한 1.20.1 업그레이드 설치와
  간편 템플릿 저장·재가져오기 반복
- 물리 기기 마이크·TTS·알림·장시간 오프라인 충돌 실측
- Play release signing과 Play App Signing SHA용 Android OAuth client
- Windows Authenticode 코드 서명
- 공개 HTTPS 앱 홈페이지·개인정보처리방침·승인 도메인 등록
- Google OAuth 테스트 상태에서 게시·검증 전환
