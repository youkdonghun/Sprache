# Sprache 1.20.2 검증 보고서

검증일: 2026-07-29

## 변경 범위

- Android·Windows 공통 개인 콘텐츠 `.xlsx` 내보내기
- Excel/CSV 공통 26열 데이터 계약과 `subject_id` 보존
- 첫 행 고정·자동 필터·열 너비·줄바꿈을 포함한 편집용 Excel 서식
- Google Drive 통신 중단 시 API URL과 원시 예외를 숨기는 안전한 한국어 진단
- 버전 `1.20.2+34`

## Excel 내보내기 검증

앱이 생성한 `Sprache-personal-content-export.xlsx`를 독립 스프레드시트 런타임으로
다시 열어 다음을 확인했다.

- 시트 `개인 콘텐츠`, 사용 범위 `A1:Z4`, 26열
- 일본어 단어, 영어 문장, 독일어 단어의 다국어 문자열 보존
- 여러 뜻·그룹, 품사, 허용 정답, 가나·로마자, 예문·번역, 문장 토큰 보존
- 출처 ID·URL·저자·표시 문구·라이선스·콘텐츠 버전·고정 ID 보존
- 일반 공부 주제와 언어 코스를 구분하는 `subject_id` 보존
- 우선순위·콘텐츠 버전 숫자 셀, 나머지 사용자 데이터 안전 문자열 셀
- 첫 행 고정, 자동 필터, 숨김 눈금선, 헤더 색상과 열 너비 적용
- 수식 오류 셀 0개, 사용자 값을 수식으로 기록한 셀 0개
- 내보낸 바이트를 기존 Excel 파서로 다시 가져와 모든 필드가 일치

Android 시스템 저장 선택기에서도 실제 개인 콘텐츠 파일을
`/sdcard/Download/sprache-content-2026-07-29.xlsx`로 저장하고 PC로 회수했다.

- 크기: 4,602 bytes
- SHA-256: `1237246fa3226c51384f97304aa48ccd6d2cfcb1dc88b1c8e8c33f336fe9ee8b`

## 오류 안전성 검증

HTTP client가 민감한 Google API URL을 포함한 `ClientException`을 던지도록 한
결정적 테스트에서 다음을 확인했다.

- 안정 코드 `NETWORK-CONNECTION-INTERRUPTED`
- 한국어 네트워크 확인·재시도 안내
- 정상 로컬 데이터와 업로드 대기 작업 유지 안내
- 재시도 가능, 강제 재연결 불필요
- 화면 표시와 진단 복사본에 URL·`ClientException`·원시 메시지 없음

최종 APK를 설치한 에뮬레이터에서도 네트워크를 잠시 차단한 뒤 설정 UI dump에
`googleapis.com`, `https://`, `ClientException` 문자열이 없음을 확인하고
Wi-Fi와 모바일 데이터를 즉시 복구했다.

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 333개 통과 |
| 골든 이미지 | 44개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API Vitest | 12개 통과 |
| 집중 Excel·Drive·설정 테스트 | 28개 통과 |
| 릴리스 통합 검증 | 체크섬 3개, Android ABI 3개, Windows ZIP 34개 통과 |

## 실제 설치와 연속성

최종 APK를 기존 1.20.1/초기 1.20.2 설치 위에 `adb install -r`로 덮어썼다.

- `versionCode=34`, `versionName=1.20.2`
- `firstInstallTime=2026-07-29 00:46:20` 유지
- 사용자 주제와 자료 1개, 계정 XP 50, 2/10 중단 세션 유지
- `WordStudyData` Google Drive 연결 자동 복구
- 시작 화면과 설정 화면에서 오버플로·원시 네트워크 오류 없음

Windows 설치 EXE는 임시 사용자 경로에 설치해 다음을 확인했다.

- 설치 종료 코드 0
- `sprache.exe` 창 제목 `작업 보드`, 응답 상태 정상
- 제거 종료 코드 0
- 설치 폴더 제거, 제거 레지스트리 항목 0개

## 최종 산출물

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.20.2-google-debug-signed.apk` | 77,451,337 | `fbf8a86d53ed29021e2612f098719949438be78e6d8a59a9f24ad27c2d6a1c83` |
| `Sprache-Windows-1.20.2-google-x64.zip` | 21,165,774 | `a3fedb9035955137085429867250b7aa825bc655989ba7fd85856f4419906126` |
| `Sprache-Windows-Setup-1.20.2-google-x64.exe` | 17,497,496 | `1817aed58254596b1e1fb9d8e654895a941d1b53758540e6a50eaf1acc7b4c7f` |

`npm run verify:release`와 설치 스모크 포함
`tool/verify-release.ps1 -RunInstallerSmoke`가 모두 통과했다.

## 공개 배포 전 남은 게이트

- Android Play release keystore와 Play App Signing OAuth 지문
- Windows Authenticode 코드 서명 인증서
- 소유 도메인의 공개 개인정보처리방침 URL과 Google OAuth 게시 검토
- Android 물리 기기의 여섯 언어 마이크·TTS·권한·오프라인 복귀 반복 시험

현재 산출물은 실계정 Google·Railway 연결 검증용이다. Android는 debug 인증서,
Windows 설치 EXE는 무서명이므로 위 게이트 전에는 스토어·공개 배포본으로
취급하지 않는다.
