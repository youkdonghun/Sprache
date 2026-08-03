# Sprache 1.20.4 검증 보고서

검증일: 2026-07-29

## 변경 범위

- Android 좁은 화면의 홈·단어장·학습 허브·통계·설정·세션 만들기 UI 정리
- 320×640, 360×800 및 1.3배 글자 크기 회귀 검증 추가
- 좁은 화면 내비게이션을 선택 항목 중심으로 축약
- 버전 `1.20.4+36`

## 원인과 수정

단어장은 검색·필터·스마트 모음·그룹 도구를 고정 높이 열에 쌓고 있었다.
320×640에서 기본 글자 크기는 110px, 1.3배 글자 크기는 142px의 세로
오버플로가 발생했다. 모바일 단어장을 `NestedScrollView`로 바꿔 도구 영역은
스크롤되고 결과 목록이 남은 공간을 사용하도록 수정했다. 검색 문구, 그룹 도구,
추가·가져오기 버튼도 화면 폭에 따라 축약했다.

통계 카드에서는 320px 폭에서 기본 3.5px, 1.3배 글자 크기에서 16px의
오버플로가 있었다. 좁은 화면의 카드 비율과 바깥 여백을 조정했다. 홈의 긴 주제명,
중단 세션 제목, 설정의 Drive 상태, 학습 허브 추천 제목, 세션 만들기 헤더도
폭에 맞는 짧은 문구와 아이콘 동작을 사용하도록 정리했다.

## 자동 UI 검증

- 공통 모바일 탐색 크기: 320×640, 360×800, 375×812, 390×844,
  412×915, 430×932
- 글자 확대 검증: 320×640, 1.3배
- 추가 경로: 카드 암기, 뜻 퀴즈, 발음, 미션, 단원, 노트, 가져오기,
  직접 항목 추가
- 컴팩트 골든 화면 6개: 홈, 설정, 단어장, 학습 허브, 통계, 세션 만들기
- 단어장 밝은·어두운 테마 골든 갱신 및 직접 육안 점검

최종 `npm run test:client`에서 Flutter 테스트 347개가 모두 통과했다.

## 실제 Android 320dp 검증

Android 에뮬레이터의 물리 상태는 1080×2400, density 420이다. 검증 중
800×1600, density 400으로 일시 변경해 논리 폭 320dp 조건을 만들었다.
검증 뒤에는 물리 크기와 density 420으로 복구했다.

1.20.4 APK를 기존 설치 위에 `adb install -r`로 설치했다.

- `versionCode=36`, `versionName=1.20.4`
- `firstInstallTime=2026-07-29 00:46:20` 유지
- `lastUpdateTime=2026-07-29 13:57:21`
- 사용자 주제 `기기 간 동기화`, 계정 XP 50, 2/10 중단 세션 유지
- Google Drive `WordStudyData` 연결 기록 유지
- 업그레이드 첫 실행의 One Tap 시트는 계정을 바꾸지 않고 닫았으며,
  로컬 데이터와 기존 Drive 연결 상태가 그대로 유지됨

최종 실화면:

- `artifacts/verification/android-1.20.4-320-home-final.png`
- `artifacts/verification/android-1.20.4-320-library.png`
- `artifacts/verification/android-1.20.4-320-settings-final.png`

홈의 긴 주제명과 중단 세션 제목은 한 줄로 표시되고, 단어장은 검색·도구 뒤에
학습 항목이 같은 화면에 노출된다. 설정의 Drive 상태도 잘림 없이 표시된다.

## 전체 검증

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 347개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API Vitest | 12개 통과 |
| Android 실제 덮어 설치 | 성공, 기존 설치 시각·사용자 상태 유지 |
| Android 실제 320dp 실화면 | 홈·단어장·설정 통과 |
| Android·Windows release 빌드 | 성공 |
| 릴리스 통합 검증 | 체크섬 3개, Android ABI 3개, Windows ZIP 34개 통과 |

릴리스 검증 결과는 `1.20.4+36`, Android Debug 서명,
Windows Authenticode `NotSigned`, 공개 개인정보처리방침 URL 미포함으로
확인됐다.

## 최종 산출물

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.20.4-google-debug-signed.apk` | 77,779,013 | `16babc535828ec0949968777fb96d64bfec8fd0765d8c72400de13a1fd6d84a4` |
| `Sprache-Windows-1.20.4-google-x64.zip` | 21,191,470 | `5c2f6ac0edc80e6315851d5e836877df31fd361fd675fe3d71f0e9301c344130` |
| `Sprache-Windows-Setup-1.20.4-google-x64.exe` | 17,517,867 | `65ebaa46b0908206f220a880c9bfeac62c3870641c42c2aef287563f7a96b180` |

`SHA256SUMS-1.20.4-google.txt`의 세 값과 실제 파일 해시가 일치한다.

## 공개 배포 전 남은 게이트

- Android Play release keystore와 Play App Signing OAuth 지문
- Windows Authenticode 코드 서명 인증서
- 소유 도메인의 공개 개인정보처리방침 URL과 Google OAuth 게시 검토
- Android 물리 기기의 여섯 언어 마이크·TTS·권한·오프라인 복귀 반복 시험

현재 APK는 실기능 검증용 Debug 서명본이고 Windows 설치 EXE는 무서명이다.
스토어 또는 불특정 사용자 대상 공개 배포본으로 취급하지 않는다.
