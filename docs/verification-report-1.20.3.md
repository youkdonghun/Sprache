# Sprache 1.20.3 검증 보고서

검증일: 2026-07-29

## 변경 범위

- 실제 Windows release EXE의 최소·집중·일반 창 크기와 응답 검증
- 실제 Windows Flutter 엔진에서 핵심 화면 이동과 PNG 저장 통합 시험
- 380×520 홈 제목 말줄임 제거
- 버전 `1.20.3+35`

## 실제 Windows 네이티브 창 검증

`tool/verify-windows-runtime.ps1`이 최종 release EXE를 실행하고 Win32 API로
세 크기를 적용했다.

| 구간 | 요청 외곽 | 실제 외곽 | 클라이언트 | 결과 |
| --- | ---: | ---: | ---: | --- |
| 최소창 | 380×520 | 380×520 | 364×481 | `작업 보드`, 응답 정상 |
| 집중창 | 420×640 | 420×640 | 404×601 | `작업 보드`, 응답 정상 |
| 일반창 | 1040×760 | 1040×760 | 1024×721 | `작업 보드`, 응답 정상 |

검증 결과는
`artifacts/verification/windows-native-runtime/runtime-window-sizes.json`에
저장된다.

## 실제 Windows 엔진 UI 검증

`integration_test/windows_runtime_ui_e2e_test.dart`를 Windows 장치 대상으로
실행했다. 메모리 학습 저장소를 사용해 계정 데이터에는 손대지 않으면서 실제
Windows Flutter 엔진과 `window_manager` 플러그인으로 다음 흐름을 검증했다.

1. 380×520 최소창 홈에서 `오늘 학습`, 다음 학습, 집중창 버튼 확인
2. 하단 내비게이션으로 연습 화면 이동
3. 실제 집중창 버튼으로 420×640 전환, 컨트롤러 `compact=true` 확인
4. 집중창 해제 뒤 1040×760 전환, 아이콘형 데스크톱 사이드바 확인
5. 설정으로 이동해 로컬 우선 저장 카드 확인

각 단계에서 Flutter 렌더링 예외가 없고 PNG가 정상 생성되는지 검사했다.

- `minimum-home-380x520.png`
- `minimum-practice-380x520.png`
- `focus-home-420x640.png`
- `standard-home-1040x760.png`
- `standard-settings-1040x760.png`

다섯 이미지를 직접 점검한 결과 버튼 겹침, 잘못된 줄바꿈, 하단 내비게이션
잘림은 없었다. 최소창 상단의 `오늘 체크...` 말줄임은 `오늘 학습`으로
축약한 뒤 다시 생성해 온전한 표시를 확인했다.

## Android 업그레이드 연속성

1.20.3 APK를 기존 1.20.2 위에 `adb install -r`로 설치했다.

- `versionCode=35`, `versionName=1.20.3`
- `firstInstallTime=2026-07-29 00:46:20` 유지
- 사용자 주제와 자료 1개, 계정 XP 50, 2/10 중단 세션 유지
- Google One Tap 확인 뒤 `WordStudyData` 연결 유지
- 마지막 동기화 2026-07-29 12:56, 충돌 검토 1건 유지
- 치명적 예외와 원시 Google API URL 로그 없음

`google_sign_in` 7.x의 `attemptLightweightAuthentication`은 이름과 달리 Android
One Tap 계정 시트를 표시할 수 있다. 재설치 직후 실제로 이 최소 확인 UI가 한 번
나타났고, 계정을 확인한 뒤 기존 Drive 폴더를 새로 고르지 않고 재사용했다.
학습 화면과 로컬 데이터는 시트 뒤에서 먼저 복구되어 있었다.

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 333개 통과 |
| 골든 이미지 | 44개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API Vitest | 12개 통과 |
| Windows 최소창 위젯 묶음 | 37개 통과 |
| Windows 엔진 UI E2E | 1개 통과 |
| 릴리스 통합 검증 | 체크섬 3개, Android ABI 3개, Windows ZIP 34개 통과 |

## Windows 설치 수명주기

- 설치 종료 코드 0
- 설치된 `sprache.exe` 창 제목 `작업 보드`, 응답 상태 정상
- 작업 집합 161.7MB
- 제거 종료 코드 0
- 설치 폴더 제거
- 제거 레지스트리 항목 0개

## 최종 산출물

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.20.3-google-debug-signed.apk` | 77,451,337 | `291026d4a2f2b59989f17c8bb41c1450964cdf33d7260b8bdc35efc92469a5b0` |
| `Sprache-Windows-1.20.3-google-x64.zip` | 21,166,354 | `d19422d3b2bf620c72b36feb8077454aa6663b1da3620617492c1f0602343cca` |
| `Sprache-Windows-Setup-1.20.3-google-x64.exe` | 17,497,177 | `71d9b316d747c63b5141675391b51fb1accb0a699ea3de7c529d4703f5159a66` |

`npm run verify:release`, 설치 스모크 포함
`tool/verify-release.ps1 -RunInstallerSmoke`, `npm run test:windows:runtime`,
`npm run test:windows:ui-e2e`를 검증 명령으로 제공한다.

## 공개 배포 전 남은 게이트

- Android Play release keystore와 Play App Signing OAuth 지문
- Windows Authenticode 코드 서명 인증서
- 소유 도메인의 공개 개인정보처리방침 URL과 Google OAuth 게시 검토
- Android 물리 기기의 여섯 언어 마이크·TTS·권한·오프라인 복귀 반복 시험

현재 산출물은 실계정 Google·Railway 연결 검증용이다. Android는 debug 인증서,
Windows 설치 EXE는 무서명이므로 위 게이트 전에는 스토어·공개 배포본으로
취급하지 않는다.
