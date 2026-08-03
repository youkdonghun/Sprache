# Sprache 1.19.7 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 319개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API 타입 검사·빌드 | 통과 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| 알림 계획 로직 | 미래 일정만 선택, 중복 제거, 안정적인 ID, 시간순 최대 20개 제한 테스트 통과 |
| 일정 상태 연동 | 일정 저장·수정·삭제·시작·Drive 병합 뒤 알림 재조정, 사용자 동작에서만 Android 권한 요청 테스트 통과 |
| 설정 알림 관리 | 미래 일정 수 표시, 권한 요청, 예약 재조정, 결과 안내를 412px Android 설정 화면에서 검증 |
| Windows 네이티브 알림 | 실제 Windows runner에서 예약 ID 등록·조회·취소 통합 테스트 통과 |
| Android 네이티브 알림 | 실제 Android 에뮬레이터에서 예약 ID 등록·조회·취소 통합 테스트 통과 |
| Android 배포물 | APK 생성, `adb install -r`, foreground 기동, 런타임 crash 0건 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거와 레지스트리 정리 통과 |
| 릴리스 통합 검증 | 버전·해시·APK v2 서명·3개 ABI·Windows AOT·ZIP 33개 항목 통과 |

## 1.19.7 알림 관리 흐름

- 설정 화면의 학습 환경 구역에서 현재 미래 일정 중 알림 대상 수를 바로 확인한다.
- 일정이 없을 때는 `알림 연결`, 일정이 있을 때는 `알림 다시 맞추기` 버튼을 표시한다.
- Android에서는 사용자가 이 버튼을 누를 때 알림 권한을 요청한다.
- Windows에서는 현재 저장된 미래 일정을 Windows Toast 예약과 다시 맞춘다.
- 권한 거부, 플랫폼 미지원, 권한은 있으나 예약 실패, 정상 연결을 서로 다른 문구로 안내한다.
- 정상 연결 시 실제로 다시 예약된 미래 일정 개수를 표시한다.
- 알림을 허용하지 않아도 학습 일정과 로컬 데이터는 변경하거나 삭제하지 않는다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.7-google-debug-signed.apk`
- 크기: 77,312,475 bytes
- SHA-256:
  `a4fb939416546a660f4146270364f96620be0144bf9e57b41f3f19c59a596037`
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.19.7` (`versionCode` 29)
- 최소 SDK: 24
- 대상 SDK: 36
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

연결된 Android 에뮬레이터에 `adb install -r`로 설치했다. 설치된 패키지는
`versionName=1.19.7`, `versionCode=29`였고 프로세스가 유지됐다.
`com.youkdonghun.sprache/.MainActivity`는 `topResumedActivity`였고
crash buffer에는 오류가 없었다.

현재 APK는 직접 설치 검증용 Debug 인증서 서명본이며 Play 배포용 서명본은 아니다.

### Windows

- 포터블 파일: `artifacts/Sprache-Windows-1.19.7-google-x64.zip`
- 크기: 21,132,795 bytes
- SHA-256:
  `909f47c2f7cc177f404430b45ce8eb67050c79c2190f1f4e661e08cef9f954fe`
- ZIP 항목 수: 33
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.7-google-x64.exe`
- 설치 파일 크기: 17,478,502 bytes
- 설치 파일 SHA-256:
  `bc6386aba3bd773be647cd85a6bcf36c394e00922b2c1293fc661d9d2aa9e78b`
- 설치 파일 제품 버전: `1.19.7`
- 앱 파일 버전: `1.19.7+29`
- 실행 창 제목: `작업 보드`
- 설치 실행 상태: `Responding=True`
- 제거 결과: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개

Windows 설치 스모크 테스트는 임시 경로에 설치하고 실행 중인 앱의 응답과 창 핸들을
확인한 뒤 제거했다. 테스트 종료 후 설치 폴더와 제거 레지스트리 항목은 남지 않았다.

현재 Windows 설치 파일은 Authenticode `NotSigned` 상태다. 로컬 기능 검증에는
사용할 수 있지만 공개 배포 전에는 코드 서명 인증서 적용이 필요하다.

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.7-google.txt`와 일치한다.

## 외부 연결 상태

- 이번 묶음에서는 사용자 요청에 따라 Google Console과 Railway 설정을 변경하지 않았다.
- Railway Desktop OAuth broker는 sealed client secret이 없어 `not_configured` 상태다.
- 로컬 학습, 콘텐츠 가져오기, 학습 일정·OS 알림과 설정 관리, APK·Windows 실행은 Google 연결 없이 동작한다.
- 실제 계정의 Google 로그인과 Drive 기기 간 동기화는 외부 설정이 준비된 뒤 별도 실기기 검증이 필요하다.

## 배포 전에 남은 외부 작업

- Railway Desktop Client Secret sealed variable 등록
- 실제 Google 계정으로 Windows 로그인·Drive 폴더 선택 검증
- Android 로그인과 Windows↔Android Drive 연속성 검증
- Play release signing과 Windows Authenticode 서명
- 공개 도메인의 앱 홈페이지·개인정보처리방침 URL 등록
