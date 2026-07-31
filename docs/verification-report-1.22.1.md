# Sprache 1.22.1 검증 보고서

검증일: 2026-07-30

## 구현 범위

- 버전 `1.22.1+39`
- 진행 중 학습이 있을 때 다른 암기·퀴즈 세션이 기존 세션을 무음으로 덮어쓰는 경로 차단
- `돌아가기`, `기존 학습 이어가기`, `기존 종료 후 새로 시작`의 명시적 선택 제공
- 학습 라우트의 모드·범위가 바뀔 때 화면 상태를 올바르게 새로 구성

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 354개 통과 |
| API Vitest | 12개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 세션 보호 회귀 테스트 | 취소 시 원본 유지, 명시적 교체 시에만 새 세션 생성 |
| 릴리스 무결성 | 체크섬 3개, APK ABI 3개, Windows ZIP 34개 통과 |
| Windows 네이티브 창 | 380×520, 420×640, 1040×760 응답 통과 |
| Windows 설치 수명주기 | 설치 0, 실행 응답, 제거 0, 설치 폴더 제거 |
| Windows 실제 엔진 UI E2E | 최소·집중·표준 크기 이동과 스크린샷 통과 |

## Android 업그레이드·실화면 검증

- 에뮬레이터 `emulator-5554`에 `adb install -r`로 1.22.0에서 1.22.1로 업데이트
- `versionCode 38 → 39`, `versionName 1.22.0 → 1.22.1`
- `firstInstallTime 2026-07-29 00:46:20` 유지
- 계정 50 XP와 기존 `영어 · 뜻 고르기 · 0/10문제` 활성 세션 유지
- 기존 세션 중 `직접 쓰기`를 새로 시작하면 세션 보호 대화상자 표시
- `돌아가기`를 선택한 뒤 기존 세션 ID·진도와 계정 XP 유지
- 치명 예외, 미처리 예외, AndroidRuntime 오류, RenderFlex overflow 0건

증거:

- `artifacts/verification/android-1.22.1-session-guard/session-guard.png`
- `artifacts/verification/android-1.22.1-session-guard/session-guard.xml`
- `artifacts/verification/android-1.22.1-session-guard/after-cancel.png`
- `artifacts/verification/android-1.22.1-session-guard/after-cancel.xml`

## Google·Railway 준비 상태

`npm run check:google` 결과:

- API: `https://sprache-api-production.up.railway.app`
- API health: `True`
- Desktop OAuth broker: `ready`
- Windows Google login ready: `True`

## 산출물

| 파일 | 바이트 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.22.1-google-debug-signed.apk` | 77,763,665 | `EE49C521DFF246EA4751BF50B3C6F0E1DEB508A8A735B5E3E977CCFB326440DD` |
| `Sprache-Windows-1.22.1-google-x64.zip` | 21,188,488 | `3D2DA4FA9413B75EF5FF074859FF7B2ED32E0BC90957FA48E504605B0BF33DB2` |
| `Sprache-Windows-Setup-1.22.1-google-x64.exe` | 17,519,986 | `7D03C37C1A3BAB5FE24B97D6470B8712CC66BFA4DA755A1C04F587B1C413630B` |

## 남은 배포 조건

- Android APK는 실제 Google 연결이 켜진 개발용 Debug 서명본이다. Play 배포에는 release upload key와 Play App Signing OAuth 지문이 필요하다.
- Windows 설치 EXE는 Authenticode 서명이 없다.
- Android 물리 기기에서 마이크·TTS·시스템 파일 선택기와 접근성 배율을 반복 확인해야 한다.
- 홈페이지와 개인정보처리방침을 소유권 확인 도메인에 공개하고 Google OAuth 동의 화면의 운영 URL로 등록해야 한다.
