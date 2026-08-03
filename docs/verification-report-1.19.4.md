# Sprache 1.19.4 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 313개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| 일정 이전 | 구버전 빈 `subjectId`를 활성 주제에 귀속하는 도메인·상태 테스트 통과 |
| 일정 격리 | 영어·일본어·사용자 주제별 저장·불러오기·Drive 왕복 테스트 통과 |
| 홈 일정 흐름 | 홈 불러오기 → 세션 시작 → 예약 시간 제거 → 템플릿 유지 통과 |
| 반응형 일정 UI | Android 390px, Windows 520·1280px 위젯 테스트 통과 |
| Android | release APK 생성, `adb install -r`, foreground 기동, 앱 crash 0건 |
| Windows | release ZIP·설치 EXE 생성, 설치·실행·제거와 레지스트리 정리 통과 |
| 릴리스 통합 검사 | 버전·해시·APK v2 서명·3개 ABI·Windows AOT·ZIP 29개 항목 통과 |

## 1.19.4 일정 연속성

- `StudySessionPlan.subjectId`를 로컬 설정과 Drive snapshot에 포함한다.
- 저장과 현재 세션 계획은 항상 현재 학습 주제로 귀속된다.
- 세션 빌더에는 현재 주제의 일정만 표시한다.
- 구버전 일정에 주제가 없으면 저장 당시 활성 주제를 사용하며, 메모리 저장소의
  이전 객체도 hydration 과정에서 같은 방식으로 갱신한다.
- 원격 일정이 존재하지 않는 사용자 주제를 가리키면 정상 로컬 데이터에
  병합하기 전에 snapshot 검증에서 차단한다.
- 홈은 현재 주제의 예약 일정만 시간순으로 표시한다.
- 예약 일정을 시작하면 `scheduledAt`만 비우고 이름·문제 방식·항목·개수는
  저장 계획에 남겨 다시 사용할 수 있다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.4-google-debug-signed.apk`
- 크기: 76,165,646 bytes
- SHA-256:
  `47455498acad0099e8f59735722a7d8e67677801c570f099f2832ba19017e909`
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.19.4` (`versionCode` 26)
- 최소 SDK: 24
- 대상 SDK: 36
- 서명: APK Signature Scheme v2, Android Debug 인증서
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

에뮬레이터 `emulator-5554`에 `adb install -r`로 설치했다. 프로세스가
foreground activity로 유지됐고 `AndroidRuntime`·Flutter crash 로그는 없었다.
현재 파일은 직접 설치 검증용 Debug 인증서 서명본이며 Play 배포용 서명본은 아니다.

### Windows

- 포터블 파일: `artifacts/Sprache-Windows-1.19.4-google-x64.zip`
- 크기: 20,947,775 bytes
- SHA-256:
  `1ece33351011e956872ebb064a95c36edcb0d7d5a5d205194429e2d2b829d993`
- ZIP 항목 수: 29
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.4-google-x64.exe`
- 설치 파일 크기: 17,371,319 bytes
- 설치 파일 SHA-256:
  `e8954c7fdccbbe5ffbacbd894570c2239cc0313d81fd099388a02eb893f8989e`
- 설치 파일 제품 버전: `1.19.4`
- 앱 파일 버전: `1.19.4+26`
- 실행 창 제목: `작업 보드`
- 설치 실행 상태: `Responding=True`
- 제거 결과: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개

현재 Windows 설치 파일은 Authenticode `NotSigned` 상태다. 로컬 기능 검증에는
사용할 수 있지만 공개 배포에는 코드 서명 인증서가 필요하다.

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.4-google.txt`와 일치한다.

## 외부 연결 상태

- Railway 운영 API는 기존 주소를 사용한다.
- Desktop OAuth broker는 sealed secret 미등록으로 `not_configured`다.
- 이번 묶음에서는 Google Console이나 Railway 변수에 쓰기 작업을 하지 않았다.
- 로컬 학습, 일정 저장·이전, APK·Windows 실행은 Google 연결 없이 동작한다.

## 남은 외부 게이트

- Railway Desktop Client Secret sealed variable 등록
- 실제 Google 계정 Windows 로그인·Drive 폴더 선택
- Android 실기기 로그인과 Windows↔Android Drive 연속성
- 물리 Android 마이크·TTS·파일 선택기 점검
- Windows Authenticode와 Play release signing
