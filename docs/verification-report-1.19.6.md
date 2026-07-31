# Sprache 1.19.6 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 318개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API 타입 검사·빌드 | 통과 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| 알림 계획 로직 | 미래 일정만 선택, 중복 제거, 안정적인 ID, 시간순 최대 20개 제한 테스트 통과 |
| 일정 상태 연동 | 일정 저장·수정·삭제·시작·Drive 병합 뒤 알림 재조정, 사용자 동작에서만 Android 권한 요청 테스트 통과 |
| Windows 네이티브 알림 | 실제 Windows runner에서 예약 ID 등록·조회·취소 통합 테스트 통과 |
| Android 네이티브 알림 | 실제 Android 에뮬레이터에서 예약 ID 등록·조회·취소 통합 테스트 통과 |
| Android 배포물 | APK 생성, `adb install -r`, foreground 기동, 런타임 crash 0건 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거와 레지스트리 정리 통과 |
| 릴리스 통합 검증 | 버전·해시·APK v2 서명·3개 ABI·Windows AOT·ZIP 33개 항목 통과 |

## 1.19.6 학습 일정 알림

- 이름과 미래 시간을 저장한 학습 일정은 Android 알림과 Windows Toast로 예약한다.
- Android 알림 권한은 앱 시작 시 자동으로 띄우지 않고 사용자가 일정을 저장할 때만 요청한다.
- 권한이 거부되거나 플랫폼 알림이 준비되지 않아도 일정과 로컬 학습 데이터는 그대로 저장한다.
- 앱 시작, 일정 수정·삭제·시작, Drive 병합 뒤 현재 미래 일정과 OS 예약을 다시 맞춘다.
- 다른 기기에서 삭제했거나 이미 시작한 일정의 오래된 알림은 제거한다.
- 같은 일정의 중복 데이터는 최신 항목 하나만 사용하고 미래 일정은 시간순 최대 20개까지만 예약한다.
- Android는 정확 알람 권한이 필요 없는 `inexactAllowWhileIdle` 방식과 재부팅 복원 receiver를 사용한다.
- Windows에서는 플러그인의 Windows 지원 범위에 맞춰 기존 예약을 취소한 뒤 현재 계획을 다시 등록한다.

Android 제조사 절전 정책과 시스템 부하에 따라 알림 시각이 일부 지연될 수 있다. 이 정책은
정확 알람 권한을 추가로 요구하지 않으면서 학습 알림을 제공하기 위한 현재 제품 선택이다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.6-google-debug-signed.apk`
- 크기: 77,312,367 bytes
- SHA-256:
  `c5ba56aa61fca5bd6e21af7b8cfc752c70f2d00626770cc4d2202c49422576d5`
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.19.6` (`versionCode` 28)
- 최소 SDK: 24
- 대상 SDK: 36
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

연결된 Android 에뮬레이터에 `adb install -r`로 설치했다. 설치된 패키지는
`versionName=1.19.6`, `versionCode=28`이었고 프로세스가 유지됐다.
`com.youkdonghun.sprache/.MainActivity`는 `visible=true`이면서
`topResumedActivity`였고 crash buffer에는 오류가 없었다.

현재 APK는 직접 설치 검증용 Debug 인증서 서명본이며 Play 배포용 서명본은 아니다.

### Windows

- 포터블 파일: `artifacts/Sprache-Windows-1.19.6-google-x64.zip`
- 크기: 21,132,192 bytes
- SHA-256:
  `8fb6bcb7bf6a88530b1607c975d23d86367a2cf14757ab89d63fb35a278822ac`
- ZIP 항목 수: 33
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.6-google-x64.exe`
- 설치 파일 크기: 17,476,783 bytes
- 설치 파일 SHA-256:
  `cc183cb4125913fe049b10d6aae76980ce709cd6b0e37452fec9333519907ea4`
- 설치 파일 제품 버전: `1.19.6`
- 앱 파일 버전: `1.19.6+28`
- 실행 창 제목: `작업 보드`
- 설치 실행 상태: `Responding=True`
- 제거 결과: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개

Windows 설치 스모크 테스트는 임시 경로에 설치하고 실행 중인 앱의 응답과 창 핸들을
확인한 뒤 제거했다. 테스트 종료 후 설치 폴더와 제거 레지스트리 항목은 남지 않았다.

현재 Windows 설치 파일은 Authenticode `NotSigned` 상태다. 로컬 기능 검증에는
사용할 수 있지만 공개 배포 전에는 코드 서명 인증서 적용이 필요하다.

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.6-google.txt`와 일치한다.

## 외부 연결 상태

- 이번 묶음에서는 사용자 요청에 따라 Google Console과 Railway 설정을 변경하지 않았다.
- Railway Desktop OAuth broker는 sealed client secret이 없어 `not_configured` 상태다.
- 로컬 학습, 콘텐츠 가져오기, 학습 일정·OS 알림, APK·Windows 실행은 Google 연결 없이 동작한다.
- 실제 계정의 Google 로그인과 Drive 기기 간 동기화는 외부 설정이 준비된 뒤 별도 실기기 검증이 필요하다.

## 배포 전에 남은 외부 작업

- Railway Desktop Client Secret sealed variable 등록
- 실제 Google 계정으로 Windows 로그인·Drive 폴더 선택 검증
- Android 로그인과 Windows↔Android Drive 연속성 검증
- Play release signing과 Windows Authenticode 서명
- 공개 도메인의 앱 홈페이지·개인정보처리방침 URL 등록
